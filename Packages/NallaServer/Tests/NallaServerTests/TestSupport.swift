import Foundation
@testable import NallaCore
@testable import NallaServer

/// Collects what the hub sends to one fake connection.
final class Outbox: @unchecked Sendable {
    private let lock = NSLock()
    private var _texts: [String] = []
    private var _closed = false
    func send(_ s: String) { lock.lock(); _texts.append(s); lock.unlock() }
    func close() { lock.lock(); _closed = true; lock.unlock() }
    var texts: [String] { lock.lock(); defer { lock.unlock() }; return _texts }
    var closed: Bool { lock.lock(); defer { lock.unlock() }; return _closed }
    var messages: [ServerMessage] { texts.compactMap(Wire.decodeServer) }
    var views: [PlayerView] { messages.compactMap { if case .view(let v) = $0 { return v }; return nil } }
    var lastView: PlayerView? { views.last }
    var errors: [ErrorCode] { messages.compactMap { if case .error(_, let c, _, _) = $0 { return c }; return nil } }
}

func joinJSON(_ name: String, _ colour: PlayerColour, room: String = "BCDF", token: String? = nil, id: String = "j") -> String {
    var o: [String: JSONValue] = ["v": .number(1), "type": .string("join"), "id": .string(id), "room": .string(room),
                                  "name": .string(name), "colour": .string(colour.rawValue)]
    if let token { o["seat_token"] = .string(token) }
    return JSONValue.object(o).jsonText
}

func leaderJSON(_ action: String, _ args: [String: JSONValue] = [:], id: String = "l") -> String {
    JSONValue.object(["v": .number(1), "type": .string("leader"), "id": .string(id), "action": .string(action),
                      "args": .object(args)]).jsonText
}

func voteJSON(round: Int, choice: Int, id: String = "v") -> String {
    JSONValue.object(["v": .number(1), "type": .string("cast_vote"), "id": .string(id), "round": .number(Double(round)),
                      "choice": .number(Double(choice))]).jsonText
}

func makeHub(_ clock: ManualClock = ManualClock()) -> Hub {
    let counter = Counter()
    return Hub(content: .empty, clock: clock, seed: 1, code: "BCDF", tokens: { String(format: "%032x", counter.next()) })
}

@discardableResult
func connect(_ hub: Hub, ip: String = "10.0.0.1") async -> (ConnectionID, Outbox) {
    let c = ConnectionID(), box = Outbox()
    await hub.opened(c, ip: ip, send: { box.send($0) }, close: { box.close() })
    return (c, box)
}

@discardableResult
func join(_ hub: Hub, _ name: String, _ colour: PlayerColour, token: String? = nil, ip: String = "10.0.0.1") async -> (ConnectionID, Outbox) {
    let (c, box) = await connect(hub, ip: ip)
    await hub.received(joinJSON(name, colour, token: token), from: c)
    return (c, box)
}

/// Polls `cond` until it holds or 2 s pass.
func eventually(_ cond: @Sendable () async -> Bool) async -> Bool {
    for _ in 0..<400 {
        if await cond() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return false
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    func next() -> Int { lock.withLock { n += 1; return n } }
}
