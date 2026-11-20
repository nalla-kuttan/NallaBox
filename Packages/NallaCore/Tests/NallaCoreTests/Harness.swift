import Foundation
@testable import NallaCore

/// Drives `Engine.reduce` by hand: a fake clock, one connection per player, the last effects.
struct Harness {
    var s: RoomState
    var now: Double = 1_000_000
    var effects: [Effect] = []
    var content = Fixtures.library()
    var conns: [PlayerID: ConnectionID] = [:]
    var tokens: [PlayerID: String] = [:]
    private var tokenCounter = 0
    private var msgCounter = 0

    init(code: String = "BCDF", seed: UInt64 = 1) {
        s = RoomState.new(code: code, seed: seed, now: 1_000_000)
    }

    mutating func send(_ e: Event) {
        (s, effects) = Engine.reduce(s, e, now: now, content: content)
    }

    @discardableResult
    mutating func join(_ name: String, _ colour: PlayerColour, room: String? = nil, token: String? = nil) -> PlayerID? {
        let conn = ConnectionID()
        tokenCounter += 1
        let fresh = String(format: "%032x", tokenCounter)
        send(.join(conn, id: "j\(tokenCounter)", JoinRequest(room: room ?? s.code, name: name, colour: colour, seatToken: token), newToken: fresh))
        for case .bind(let c, let pid) in effects where c == conn {
            conns[pid] = conn
            tokens[pid] = s.players.first { $0.id == pid }?.seatToken
            return pid
        }
        return nil
    }

    var lastError: ErrorCode? {
        for e in effects {
            if case .reply(_, .error(_, let code, _, _)) = e { return code }
            if case .send(_, .error(_, let code, _, _)) = e { return code }
        }
        return nil
    }

    mutating func msg(_ pid: PlayerID, _ m: ClientMessage) {
        msgCounter += 1
        send(.message(pid, id: "m\(msgCounter)", m))
    }

    mutating func leader(_ pid: PlayerID, _ a: LeaderAction) { msg(pid, .leader(a)) }

    mutating func advance(_ dt: Double) {
        now += dt
        send(.tick)
    }

    func phone(_ pid: PlayerID) -> ScreenView { Engine.playerView(s, pid, now: now) }
    func tv() -> TVView { Engine.tvView(s, now: now) }
    func player(_ pid: PlayerID) -> Player? { s.players.first { $0.id == pid } }

    /// Three players in the lobby: Priya (leader), Sam, Lena.
    static func three() -> Harness {
        var h = Harness()
        h.join("Priya", .saffron); h.join("Sam", .sky); h.join("Lena", .lilac)
        return h
    }

    /// Three players, TestGame started and past the how-to.
    static func playing() -> Harness {
        var h = three()
        h.leader(1, .pickGame(.test)); h.leader(1, .start)
        h.advance(15)
        return h
    }
}
