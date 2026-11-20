import Foundation
import NallaCore

public struct RoomEndpoint: Sendable, Equatable {
    public var code: String
    public var ip: String
    public var httpPort: UInt16
    public var wsPort: UInt16
    public var joinURL: String { "http://\(ip):\(httpPort)/?room=\(code)&ws=\(wsPort)" }
    /// The host's own controller (iPhone host app), joining with its reserved seat.
    public func localControllerURL(seatToken: String) -> String {
        "http://127.0.0.1:\(httpPort)/?room=\(code)&ws=\(wsPort)&seat=\(seatToken)"
    }
}

public enum HubEvent: Sendable {
    case snapshot(TVView)
    case speak(String)
    case roomClosed
}

/// Owns the room. Serialises every event through `Engine.reduce`, sends each phone its own view
/// when it changes, runs the timer and publishes TV snapshots.
public actor Hub {
    struct Conn {
        var ip: String
        var send: @Sendable (String) -> Void
        var close: @Sendable () -> Void
        var player: PlayerID?
    }

    private var state: RoomState
    private let content: ContentLibrary
    private let clock: any HubClock
    private let tokens: @Sendable () -> String
    private var conns: [ConnectionID: Conn] = [:]
    private var seats: [PlayerID: ConnectionID] = [:]
    private var lastSent: [PlayerID: PlayerView] = [:]
    private var versions: [PlayerID: Int] = [:]
    private var lastTV: TVView?
    private var limiter = JoinRateLimiter()
    private var listeners: [UUID: AsyncStream<HubEvent>.Continuation] = [:]
    private var timer: Task<Void, Never>?
    private var armed: Double?
    public nonisolated let code: String

    public init(content: ContentLibrary, clock: any HubClock, seed: UInt64, code: String? = nil,
                tokens: @escaping @Sendable () -> String = Hub.randomToken) {
        var rng = SplitMix64(seed: seed)
        let c = code ?? RoomCode.generate(using: &rng)
        self.code = c
        self.content = content
        self.clock = clock
        self.tokens = tokens
        self.state = RoomState.new(code: c, seed: rng.next(), now: clock.now())
    }

    /// 128 random bits as 32 lowercase hex characters.
    public static let randomToken: @Sendable () -> String = {
        var g = SystemRandomNumberGenerator()
        return String(format: "%016llx%016llx", g.next() as UInt64, g.next() as UInt64)
    }

    // MARK: Inputs

    public func opened(_ c: ConnectionID, ip: String, send: @escaping @Sendable (String) -> Void, close: @escaping @Sendable () -> Void) {
        conns[c] = Conn(ip: ip, send: send, close: close, player: nil)
    }

    public func received(_ text: String, from c: ConnectionID) {
        guard let conn = conns[c] else { return }
        switch Wire.decodeClient(text) {
        case .failure(let e):
            conn.send(Wire.encode(.error(id: e.id, code: e.code, message: e.message, field: nil)))
        case .success(let d):
            if case .ping(let t) = d.message {
                conn.send(Wire.encode(.pong(t: t, hostTime: clock.now())))
                return
            }
            if let pid = conn.player {
                apply(.message(pid, id: d.id, d.message))
            } else if case .join(let req) = d.message {
                guard limiter.allow(ip: conn.ip, now: clock.now()) else {
                    conn.send(Wire.encode(.error(id: d.id, code: .rateLimited, message: "Too many tries. Wait a minute and try again.", field: nil)))
                    return
                }
                apply(.join(c, id: d.id, req, newToken: tokens()))
            } else {
                conn.send(Wire.encode(.error(id: d.id, code: .notJoined, message: "Join the room first.", field: nil)))
            }
        }
    }

    public func closed(_ c: ConnectionID) {
        guard let conn = conns.removeValue(forKey: c) else { return }
        if let pid = conn.player, seats[pid] == c {
            seats[pid] = nil
            lastSent[pid] = nil
            apply(.disconnected(pid))
        }
    }

    public func host(_ a: HostAction) { apply(.host(a)) }

    /// Seat 1 for the iPhone host's own controller; returns its seat token.
    public func reserveHostSeat(name: String, colour: PlayerColour) -> String {
        let t = tokens()
        apply(.reserveHostSeat(name: name, colour: colour, token: t))
        return t
    }

    public func setJoinURL(_ url: String) {
        state.joinURL = url
        publish()
    }

    // MARK: Outputs

    public func events() -> AsyncStream<HubEvent> {
        let id = UUID()
        let (stream, cont) = AsyncStream<HubEvent>.makeStream(bufferingPolicy: .bufferingNewest(64))
        listeners[id] = cont
        cont.yield(.snapshot(currentTV()))
        cont.onTermination = { [weak self] _ in Task { await self?.removeListener(id) } }
        return stream
    }

    private func removeListener(_ id: UUID) { listeners[id] = nil }

    public func currentTV() -> TVView { Engine.tvView(state, now: clock.now()) }
    public func room() -> RoomInfo { Engine.roomInfo(state) }
    var debugState: RoomState { state }

    private func emit(_ e: HubEvent) { for l in listeners.values { l.yield(e) } }

    // MARK: Engine

    private func apply(_ e: Event) {
        let (s, effects) = Engine.reduce(state, e, now: clock.now(), content: content)
        state = s
        for effect in effects { perform(effect) }
        publish()
        rearm()
    }

    private func perform(_ effect: Effect) {
        switch effect {
        case .reply(let c, let m):
            conns[c]?.send(Wire.encode(m))
        case .bind(let c, let pid):
            if let old = seats[pid], old != c, let oc = conns.removeValue(forKey: old) {
                oc.send(Wire.encode(.removed(.replaced)))
                oc.close()
            }
            seats[pid] = c
            conns[c]?.player = pid
            lastSent[pid] = nil
        case .send(let pid, let m):
            if let c = seats[pid] { conns[c]?.send(Wire.encode(m)) }
        case .kick(let pid, let reason):
            if let c = seats.removeValue(forKey: pid), let conn = conns.removeValue(forKey: c) {
                conn.send(Wire.encode(.removed(reason)))
                conn.close()
            }
            lastSent[pid] = nil
        case .speak(let line):
            emit(.speak(line))
        case .closeRoom:
            timer?.cancel()
            emit(.roomClosed)
        }
    }

    private func publish() {
        let now = clock.now()
        let info = Engine.roomInfo(state)
        for (pid, c) in seats {
            guard let conn = conns[c], let you = Engine.youInfo(state, pid) else { continue }
            let sv = Engine.playerView(state, pid, now: now)
            var view = PlayerView(version: 0, screen: sv.screen, deadline: sv.deadline, you: you, room: info, data: sv.data)
            if let last = lastSent[pid] {
                var cmp = last; cmp.version = 0
                if cmp == view { continue }
            }
            let v = (versions[pid] ?? 0) + 1
            versions[pid] = v
            view.version = v
            lastSent[pid] = view
            conn.send(Wire.encode(.view(view)))
        }
        let tv = Engine.tvView(state, now: now)
        if tv != lastTV {
            lastTV = tv
            emit(.snapshot(tv))
        }
    }

    private func rearm() {
        let wake = Engine.nextWake(state)
        guard wake != armed else { return }
        timer?.cancel()
        armed = wake
        guard let wake else { return }
        let clock = self.clock
        timer = Task { [weak self] in
            do { try await clock.sleep(until: wake) } catch { return }
            await self?.fire(wake)
        }
    }

    private func fire(_ wake: Double) {
        guard armed == wake else { return }
        armed = nil
        apply(.tick)
    }
}
