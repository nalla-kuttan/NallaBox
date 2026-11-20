import Foundation
import Testing
@testable import NallaCore

/// Five players in Redacted, past the how-to, in round 1's write phase.
private func redacted(players: Int = 5, timer: TimerSpeed = .x1, family: Bool = true) -> Harness {
    var h = Harness()
    let names: [(String, PlayerColour)] = [("Priya", .saffron), ("Sam", .sky), ("Lena", .lilac), ("Dev", .teal), ("Aiko", .lime), ("Rosa", .sand)]
    for (n, c) in names.prefix(players) { h.join(n, c) }
    h.s.settings.familyFriendly = family
    h.leader(1, .pickGame(.redacted))
    h.leader(1, .setSettings(SettingsPatch(timer: timer)))
    h.leader(1, .start)
    h.advance(15)
    return h
}

private func st(_ h: Harness) -> Redacted.State {
    guard case .playing(.redacted(let s)) = h.s.phase else { fatalError("not playing Redacted: \(h.s.phase)") }
    return s
}

private func submit(_ h: inout Harness, _ pid: PlayerID, _ fields: [String]) {
    h.msg(pid, .submitText(round: st(h).round, fields: fields))
}

/// Writes fakes for everyone (distinct unless given), then skips the read-out to the vote.
private func toVote(_ h: inout Harness, _ fakes: [PlayerID: [String]] = [:]) {
    for p in h.s.players.map(\.id) {
        submit(&h, p, fakes[p] ?? distinctFakes[p - 1])
    }
    while st(h).phase != .vote { h.advance(30) }
}

private let distinctFakes = [["pickle shop", "a parrot"], ["llama spa", "a cow"], ["wig shop", "a fox"],
                             ["pie museum", "a yak"], ["candle store", "an owl"], ["volcano", "a newt"]]

private func number(_ h: Harness, author: PlayerID? = nil, real: Bool = false) -> Int {
    st(h).versions.first { real ? $0.real : $0.authors.contains(author!) }!.number
}

@Test func tooCloseRejectedWithField() {
    var h = redacted()
    submit(&h, 2, ["Laundromats", "a duck"])
    #expect(h.effects.contains { if case .send(2, .error(_, .tooClose, "Too close to the real word, try another", 1)) = $0 { return true }; return false })
    submit(&h, 2, ["laundrette", "a goose"])
    guard case .send(2, .error(_, .tooClose, _, let f))? = h.effects.first(where: { if case .send(2, .error) = $0 { return true }; return false }) else {
        Issue.record("no error"); return
    }
    #expect(f == 2)
    submit(&h, 2, ["", "a duck"])
    #expect(h.lastError == .empty)
    submit(&h, 2, [String(repeating: "x", count: 25), "a duck"])
    #expect(h.lastError == .tooLong)
    submit(&h, 2, ["one"])
    #expect(h.lastError == .invalid)
    #expect(st(h).submissions[2] == nil)
}

@Test func profanityOnlyWhenFamily() {
    var h = redacted()
    submit(&h, 2, ["shit shop", "a duck"])
    #expect(h.lastError == .notAllowed)
    var off = redacted(family: false)
    submit(&off, 2, ["shit shop", "a duck"])
    #expect(off.lastError == nil)
    #expect(st(off).submissions[2] == ["shit shop", "a duck"])
}

@Test func mergeNearDuplicates() {
    var h = redacted()
    toVote(&h, [1: ["pickled eggs", "a duck"], 2: ["Pickled egg", "a duck"]])
    let merged = st(h).versions.first { $0.authors.contains(1) }!
    #expect(merged.authors.sorted() == [1, 2])
    #expect(st(h).versions.count == 1 + 4)
    for p in [3, 4, 5] { h.msg(p, .castVote(round: 1, choice: merged.number)) }
    h.msg(1, .castVote(round: 1, choice: number(h, real: true)))
    h.msg(2, .castVote(round: 1, choice: number(h, author: 3)))
    #expect(st(h).phase == .reveal)
    #expect(st(h).deltas[1] == 750 + 1000)
    #expect(st(h).deltas[2] == 750)
    #expect(st(h).deltas[3] == 500)
}

@Test func cannotVoteOwn() {
    var h = redacted()
    toVote(&h)
    h.msg(2, .castVote(round: 1, choice: number(h, author: 2)))
    #expect(h.lastError == .notAllowed)
    h.msg(2, .castVote(round: 1, choice: 99))
    #expect(h.lastError == .invalid)
    #expect(st(h).votes[2] == nil)
}

@Test func scoring() {
    var h = redacted(players: 3)
    toVote(&h)
    h.msg(1, .castVote(round: 1, choice: number(h, author: 2)))
    h.msg(2, .castVote(round: 1, choice: number(h, real: true)))
    h.msg(3, .castVote(round: 1, choice: number(h, real: true)))
    #expect(st(h).deltas == [2: 1500, 3: 1000])
    // Rounds 2 and 3, then the final round (×3).
    while st(h).round < 4 { h.advance(30) }
    toVote(&h)
    h.msg(1, .castVote(round: 4, choice: number(h, author: 2)))
    h.msg(2, .castVote(round: 4, choice: number(h, real: true)))
    h.msg(3, .castVote(round: 4, choice: number(h, author: 1)))
    #expect(st(h).deltas == [1: 1500, 2: 1500 + 3000])
}

@Test func changeAnswerBeforeDeadline() {
    var h = redacted()
    submit(&h, 2, ["first try", "a duck"])
    submit(&h, 2, ["second try", "a duck"])
    #expect(st(h).submissions[2] == ["second try", "a duck"])
}

@Test func earlyEndWhenAllIn() {
    var h = redacted(players: 3)
    h.send(.disconnected(3))
    submit(&h, 1, ["a fake", "a duck"])
    #expect(st(h).phase == .write)
    submit(&h, 2, ["b fake", "a cow"])
    #expect(st(h).phase == .readout(0))
}

@Test func readoutDurations() {
    let thirteen = "one two three four five six seven eight nine ten eleven twelve thirteen"
    #expect(Redacted.readoutSeconds(thirteen, voiceOn: true) == 6.0)
    #expect(Redacted.readoutSeconds(thirteen, voiceOn: false) == 4)
    #expect(Redacted.readoutSeconds("short", voiceOn: true) == 3)
}

@Test func readoutSpeaksEachVersion() {
    var h = redacted(players: 3)
    for p in [1, 2, 3] { submit(&h, p, ["fake \(p)", "a duck"]) }
    #expect(h.effects.contains { if case .speak(let s) = $0 { return s.hasPrefix("The mayor of Leeds") }; return false })
    #expect(st(h).deadline != nil)
}

@Test func timerOff() {
    var h = redacted(timer: .off)
    #expect(st(h).deadline == nil)
    h.advance(10_000)
    #expect(st(h).phase == .write)
    h.leader(1, .skip)
    #expect(st(h).phase == .readout(0))
}

@Test func staleVoteIgnored() {
    var h = redacted(players: 3)
    toVote(&h)
    let before = h.s
    h.msg(1, .castVote(round: 2, choice: 1))
    #expect(h.s == before)
    #expect(h.lastError == nil)
}

@Test func awardsAndFullGame() {
    var h = redacted(players: 3)
    for _ in 0..<4 {
        toVote(&h)
        let r = st(h).round
        h.msg(1, .castVote(round: r, choice: number(h, author: 2)))
        h.msg(3, .castVote(round: r, choice: number(h, author: 2)))
        h.msg(2, .castVote(round: r, choice: number(h, real: true)))
        h.advance(10); h.advance(6)
    }
    guard case .results(let res) = h.s.phase else { Issue.record("no results: \(h.s.phase)"); return }
    #expect(res.rounds == 4)
    #expect(res.awards.first { $0.title == "Best Liar" }?.player.name == "Sam")
    #expect(res.awards.first { $0.title == "Best Liar" }?.note == "fooled 8 players")
    #expect(res.awards.first { $0.title == "Sharpest Eye" }?.note == "found the real text 4 times")
    #expect(res.standings.first?.player.name == "Sam")
}

@Test func viewsAndPrivacy() throws {
    var h = redacted(players: 3)
    #expect(h.phone(1).screen == "R1")
    #expect(h.tv().screen.screen == "R1")
    submit(&h, 2, ["secret fake", "a duck"])
    #expect(h.phone(2).data["submitted"] == .bool(true))
    for p in [1, 3] where true {
        #expect(!h.phone(p).data.jsonText.contains("secret fake"))
    }
    #expect(!h.tv().screen.data.jsonText.contains("secret fake"))
    let tvTop = try h.tv().screen.data.decode(R1TV.self)
    #expect(tvTop.top == "Round 1 of 4 · Write")
    #expect((h.tv().face.caption ?? "").count <= 48)
    submit(&h, 1, ["a", "b"]); submit(&h, 3, ["c", "d"])
    #expect(h.phone(1).screen == "R2")
    while st(h).phase != .vote { h.advance(30) }
    let mine = try h.phone(2).data.decode(R3Phone.self)
    #expect(mine.versions.filter(\.mine).count == 1)
    #expect(h.tv().screen.screen == "R3")
}

@Test func lastRoundIsFinal() throws {
    var h = redacted(players: 3)
    while st(h).round < 4 { h.advance(30) }
    #expect(try h.tv().screen.data.decode(R1TV.self).top == "Final round · points ×3 · Write")
}
