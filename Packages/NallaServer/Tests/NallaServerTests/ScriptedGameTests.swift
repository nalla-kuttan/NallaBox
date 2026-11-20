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

    /// Advances the clock in small steps until `cond` holds (or 400 steps pass).
    func advanceUntil(step: Double = 1, _ cond: @Sendable (Table) -> Bool) async -> Bool {
        for _ in 0..<400 {
            if cond(self) { return true }
            await clock.advance(by: step)
            try? await Task.sleep(for: .milliseconds(3))
        }
        return false
    }

    func screen(_ i: Int) -> String { phones[i].lastView?.screen ?? "" }

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

@Test func sketchFullGame() async throws {
    let t = try await Table.open(ports: 19480...19489, names: [("Priya", .saffron), ("Sam", .sky), ("Lena", .lilac)])
    defer { Task { [t] in await t.close() } }
    try await t.lead("pick_game", ["game": .string("sketch")])
    try await t.lead("start")
    #expect(await t.waitAll { $0.lastView?.screen == "P7" })
    try await t.lead("skip")
    let stroke: JSONValue = .array([.object(["c": .number(1), "s": .number(1), "p": .array([0.1, 0.2, 0.6, 0.7].map(JSONValue.number))])])

    for round in 1...3 {
        let witness = round - 1   // phones[0] is Witness in round 1, then 1, then 2
        #expect(await t.waitAll { $0.lastView?.screen.hasPrefix("C1") == true }, "round \(round) never briefed")
        #expect(t.phones[witness].lastView?.screen == "C1-witness")
        #expect(await t.advanceUntil { $0.screen(witness) == "C2-witness" })
        for (i, p) in t.phones.enumerated() where i != witness {
            try await p.send("stroke_data", ["round": .number(Double(round)), "strokes": stroke, "final": .bool(true)])
        }
        #expect(await t.phones[witness].wait { $0.lastView?.screen == "C3-witness" })
        // The Witness picks the lower-numbered artist's drawing.
        let artists = (0..<3).filter { $0 != witness }
        let favourite = t.phones[artists[0]]
        #expect(await favourite.wait { $0.lastView?.screen == "C3-artist" })
        let pick = favourite.lastView!.data["number"]!.int!
        try await t.phones[witness].send("cast_vote", ["round": .number(Double(round)), "choice": .number(Double(pick))])
        #expect(await t.advanceUntil { t in (0..<3).allSatisfy { t.screen($0) == "C5" } })
        // Worst likeness: Lena's (phone 2) when she drew, else the other artist.
        for (i, p) in t.phones.enumerated() {
            let mine = p.lastView!.data["drawings"]!.array!.first { $0["mine"]?.bool == true }?["number"]?.int
            let all = p.lastView!.data["drawings"]!.array!.compactMap { $0["number"]?.int }
            let lena = t.phones[2].lastView!.data["drawings"]!.array!.first { $0["mine"]?.bool == true }?["number"]?.int
            let choice = (i != 2 && lena != nil) ? lena! : all.first { $0 != mine }!
            try await p.send("cast_vote", ["round": .number(Double(round)), "choice": .number(Double(choice))])
        }
        #expect(await t.advanceUntil { t in (0..<3).allSatisfy { round < 3 ? t.screen($0).hasPrefix("C1") : t.screen($0) == "P12" } })
    }

    let final = t.phones.map { try? $0.lastView!.data.decode(PhoneResultsData.self) }
    #expect(final.map { $0?.points } == [2500, 1500, 500])
    #expect(final[2]?.award?.title == "Most Wanted")

    // Privacy: the scene caption only ever reached that round's Witness before the reveal.
    var captions: Set<String> = []
    for p in t.phones { for v in p.views where v.screen.hasSuffix("-witness") { if let c = v.data["scene"]?["caption"]?.string { captions.insert(c) } } }
    #expect(captions.count == 3)
    for p in t.phones {
        for v in p.views where v.screen.hasSuffix("-artist") || v.screen == "P7" {
            #expect(!captions.contains { v.data.jsonText.contains($0) }, "an artist saw the scene on \(v.screen)")
        }
    }
}

@Test func insiderFullGame() async throws {
    let t = try await Table.open(ports: 19580...19589, names: [("Priya", .saffron), ("Sam", .sky), ("Lena", .lilac), ("Dev", .teal)])
    defer { Task { [t] in await t.close() } }
    try await t.lead("pick_game", ["game": .string("insider")])
    try await t.lead("start")
    #expect(await t.waitAll { $0.lastView?.screen == "P7" })
    try await t.lead("skip")
    var expected = [5000, 5000, 5000, 5000]

    for round in 1...6 {
        #expect(await t.waitAll { $0.lastView?.screen.hasPrefix("I1") == true && $0.lastView?.data["top"]?.string?.contains("Round \(round) ") == true },
                "round \(round) never started")
        let insider = (0..<4).first { t.screen($0) == "I1-insider" }!
        let answer = ["A", "B", "C", "D"].firstIndex(of: t.phones[insider].lastView!.data["answerKey"]!.string!)!
        #expect(await t.advanceUntil { t in (0..<4).allSatisfy { t.screen($0) == "I3" } })
        for (i, p) in t.phones.enumerated() {
            let choice = i == insider ? answer : 0
            try await p.send("place_bet", ["round": .number(Double(round)), "choice": .number(Double(choice)), "chips": .number(100)])
            expected[i] += choice == answer ? 100 : -100
        }
        #expect(await t.advanceUntil { t in (0..<4).allSatisfy { t.screen($0) == "I5" } })
        let ids = t.phones.map { $0.playerId! }
        for (i, p) in t.phones.enumerated() {
            let target = i == insider ? ids[(insider + 1) % 4] : ids[insider]
            try await p.send("cast_vote", ["round": .number(Double(round)), "choice": .number(Double(target))])
            if i != insider { expected[i] += 300 }
        }
        expected[insider] -= 900
        #expect(await t.waitAll { $0.lastView?.screen == "I6" })
        #expect(t.phones[insider].lastView?.data["caught"]?.bool == true)
        #expect(await t.advanceUntil(step: 2) { t in (0..<4).allSatisfy { round < 6 ? t.screen($0).hasPrefix("I1") : t.screen($0) == "P12" } })
    }

    let final = t.phones.map { try? $0.lastView!.data.decode(PhoneResultsData.self) }
    #expect(final.map { $0?.points } == expected)
    #expect(final.contains { $0?.award?.title == "Best Detective" })

    // Only the round's Insider ever received the answer before the reveal.
    for p in t.phones {
        for v in p.views where v.data.jsonText.contains("answerKey") {
            #expect(v.screen.hasSuffix("-insider"), "answerKey reached a \(v.screen) view")
        }
    }
}
