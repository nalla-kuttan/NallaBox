import Foundation
import Testing
@testable import NallaCore
@testable import NallaServer

/// The repository's bundled content packs.
func bundledContent() throws -> ContentLibrary {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return try ContentLibrary.load(from: root.appendingPathComponent("app/Resources/Content"))
}

/// A room with real sockets and a manual clock, plus helpers to drive it.
struct Table {
    let server: RoomServer
    let clock: ManualClock
    let endpoint: RoomEndpoint
    var phones: [TestClient] = []

    static func open(ports: ClosedRange<UInt16>, names: [(String, PlayerColour)]) async throws -> Table {
        let clock = ManualClock()
        let server = RoomServer(controllerRoot: try controllerSite(), content: try bundledContent(), clock: clock, seed: 11, code: "BCDF")
        let e = try await server.start(ports: ports)
        var t = Table(server: server, clock: clock, endpoint: e)
        for (n, c) in names {
            let p = TestClient(url: URL(string: "ws://127.0.0.1:\(e.wsPort)/")!)
            try await p.sendText(joinJSON(n, c))
            _ = await p.wait { $0.lastView != nil }
            t.phones.append(p)
        }
        return t
    }

    var leader: TestClient { phones[0] }

    func lead(_ action: String, _ args: [String: JSONValue] = [:]) async throws {
        try await leader.send("leader", ["action": .string(action), "args": .object(args)])
    }

    /// Advances the clock in steps until every phone shows `screen` (or 400 steps pass).
    func until(_ screen: String, step: Double = 2) async -> Bool {
        for _ in 0..<400 {
            if phones.allSatisfy({ $0.lastView?.screen == screen }) { return true }
            await clock.advance(by: step)
            try? await Task.sleep(for: .milliseconds(3))
        }
        return false
    }

    func waitAll(_ cond: @escaping @Sendable (TestClient) -> Bool) async -> Bool {
        for p in phones where !(await p.wait(cond)) { return false }
        return true
    }

    func close() async {
        for p in phones { p.close() }
        await server.stop()
    }
}

@Test func redactedFullGame() async throws {
    var t = try await Table.open(ports: 19380...19389, names: [("Priya", .saffron), ("Sam", .sky), ("Lena", .lilac), ("Dev", .teal)])
    defer { Task { [t] in await t.close() } }
    try await t.lead("pick_game", ["game": .string("redacted")])
    try await t.lead("start")
    #expect(await t.waitAll { $0.lastView?.screen == "P7" })
    try await t.lead("skip")
    let names = ["priya", "sam", "lena", "dev"]
    var allFakes: [String: Set<String>] = [:]   // player -> every fake they wrote

    for round in 1...4 {
        #expect(await t.waitAll { $0.lastView?.screen == "R1" && $0.lastView?.data["round"]?.int == round })
        let blanks = t.phones[0].lastView?.data["blanks"]?.int ?? 1
        for (i, p) in t.phones.enumerated() {
            let fields = (1...blanks).map { "\(names[i]) zebra \($0) r\(round)" }
            allFakes[names[i], default: []].formUnion(fields)
            try await p.send("submit_text", ["round": .number(Double(round)), "fields": .array(fields.map(JSONValue.string))])
        }
        #expect(await t.until("R3"), "round \(round) never reached voting")
        // Find Sam's fake and the real text from Priya's tiles.
        let tiles = try t.phones[0].lastView!.data["versions"]!.decode([VersionTile].self)
        let sam = tiles.first { $0.fills.first?.hasPrefix("sam zebra") == true }!.number
        let real = tiles.first { $0.fills.first?.contains(" zebra ") == false }!.number
        let choices = [sam, real, real, sam]
        for (i, p) in t.phones.enumerated() {
            try await p.send("cast_vote", ["round": .number(Double(round)), "choice": .number(Double(choices[i]))])
        }
        #expect(await t.until("R4"))
        #expect(await t.until(round < 4 ? "R1" : "P12", step: 3))
    }

    let final = t.phones.map { try? $0.lastView!.data.decode(PhoneResultsData.self) }
    #expect(final.map { $0?.points } == [0, 12000, 6000, 0])
    #expect(final.map { $0?.rank } == [3, 1, 2, 3])
    #expect(final[1]?.award?.title == "Best Liar")

    // Privacy: before the read-out, nobody saw anyone else's fakes.
    for (i, p) in t.phones.enumerated() {
        let others = allFakes.filter { $0.key != names[i] }.values.flatMap { $0 }
        for v in p.views where v.screen == "R1" || v.screen == "P7" {
            let text = v.data.jsonText
            #expect(!others.contains { text.contains($0) }, "\(names[i]) saw another player's fake on \(v.screen)")
        }
    }
}
