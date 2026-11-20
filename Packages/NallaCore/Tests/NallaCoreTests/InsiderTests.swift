import Foundation
import Testing
@testable import NallaCore

private let roster: [(String, PlayerColour)] = [("Marcus", .mint), ("Priya", .saffron), ("Sam", .sky), ("Aiko", .lime),
                                                ("Lena", .lilac), ("Rosa", .sand), ("Dev", .teal), ("Wolfgangster", .pink)]

private func insider(players: Int = 4, rounds: Int? = nil) -> Harness {
    var h = Harness()
    for (n, c) in roster.prefix(players) { h.join(n, c) }
    h.leader(1, .pickGame(.insider))
    if let rounds { h.leader(1, .setSettings(SettingsPatch(rounds: rounds))) }
    h.leader(1, .start)
    h.advance(15)
    return h
}

private func st(_ h: Harness) -> Insider.State {
    guard case .playing(.insider(let s)) = h.s.phase else { fatalError("not playing Insider: \(h.s.phase)") }
    return s
}

private func to(_ phase: Insider.Phase, _ h: inout Harness) {
    for _ in 0..<20 where st(h).phase != phase { h.advance(30) }
}

@Test func insiderNeedsFour() throws {
    var h = Harness()
    for (n, c) in roster.prefix(3) { h.join(n, c) }
    h.leader(1, .pickGame(.insider))
    let d = try h.phone(1).data.decode(SettingsData.self)
    #expect(d.canStart == false)
    #expect(d.startBlockedReason == "Insider Trading needs 4 players")
    #expect(d.roundsLabel == "6 rounds")
}

@Test func secretOnlyToInsider() throws {
    var h = insider()
    let ins = st(h).insider
    let key = ["A", "B", "C", "D"][st(h).question.answer]
    for phase in [Insider.Phase.question, .discuss, .bet, .answer, .accuse] {
        to(phase, &h)
        for p in 1...4 {
            let text = h.phone(p).data.jsonText
            if p == ins {
                if phase == .question || phase == .discuss { #expect(text.contains("\"answerKey\":\"\(key)\"")) }
            } else {
                #expect(!text.contains("answerKey"), "player \(p) saw the answer in \(phase)")
                #expect(!text.contains("\"role\":\"insider\""))
            }
        }
        if phase != .answer { #expect(!h.tv().screen.data.jsonText.contains("\"insider\""), "TV named the Insider in \(phase)") }
    }
}

@Test func roleCardsShareKeys() throws {
    let h = insider()
    let ins = st(h).insider, other = ins == 1 ? 2 : 1
    #expect(h.phone(ins).screen == "I1-insider")
    #expect(h.phone(other).screen == "I1-trader")
    let a = Set(h.phone(ins).data.object!.keys).subtracting(["answerKey", "answerText"])
    let b = Set(h.phone(other).data.object!.keys)
    #expect(a == b)
}

@Test func insiderRotationNoRepeats() {
    var h = insider(players: 4, rounds: 8)
    var order: [PlayerID] = []
    while case .playing = h.s.phase {
        if order.count < st(h).round { order.append(st(h).insider) }
        h.advance(30)
    }
    #expect(order.count == 8)
    for p in 1...4 { #expect(order.filter { $0 == p }.count == 2) }
    for i in 1..<order.count { #expect(order[i] != order[i - 1]) }
}

@Test func betLimits() {
    var h = insider()
    to(.bet, &h)
    h.msg(2, .placeBet(round: 1, choice: 0, chips: 50)); #expect(h.lastError == .invalid)
    h.msg(2, .placeBet(round: 1, choice: 0, chips: 1100)); #expect(h.lastError == .invalid)
    h.msg(2, .placeBet(round: 1, choice: 0, chips: 250)); #expect(h.lastError == .invalid)
    h.msg(2, .placeBet(round: 1, choice: 4, chips: 200)); #expect(h.lastError == .invalid)
    h.msg(2, .placeBet(round: 1, choice: 1, chips: 400)); #expect(h.lastError == nil)
    #expect(st(h).bets[2] == Insider.Bet(choice: 1, chips: 400))
    var poor = insider()
    if case .playing(.insider(var s)) = poor.s.phase { s.chips[2] = 300; poor.s.phase = .playing(.insider(s)) }
    to(.bet, &poor)
    poor.msg(2, .placeBet(round: 1, choice: 1, chips: 400))
    #expect(poor.lastError == .invalid)
}

@Test func bailout() {
    var h = insider()
    if case .playing(.insider(var s)) = h.s.phase { s.chips[3] = 0; s.chips[4] = 150; h.s.phase = .playing(.insider(s)) }
    while st(h).round == 1 { h.advance(30) }
    #expect(st(h).chips[3] == 500)
    #expect(st(h).chips[4] == 150)
}

@Test func mockupChipMaths() {
    let players = roster.enumerated().map { i, p in Player(id: i + 1, name: p.0, colour: p.1, seatToken: "", joinedAt: Double(i)) }
    let id = Dictionary(uniqueKeysWithValues: roster.enumerated().map { ($0.element.0, $0.offset + 1) })
    let start = ["Marcus": 5700, "Priya": 5500, "Sam": 5500, "Aiko": 5300, "Lena": 5300, "Rosa": 4800, "Dev": 4300, "Wolfgangster": 4200]
    let bets: [String: (Int, Int)] = ["Lena": (0, 800), "Aiko": (0, 300), "Marcus": (1, 1000), "Priya": (1, 600), "Sam": (1, 400),
                                      "Dev": (2, 500), "Wolfgangster": (3, 1000), "Rosa": (3, 200)]
    func play(accusers: [String]) -> [String: Int] {
        var ctx = GameContext(players: players, leaderId: 1, settings: RoomSettings(rounds: 6), now: 0, rng: SplitMix64(seed: 1),
                              content: Fixtures.library(), used: [])
        var s = Insider.start(&ctx)
        s.insider = id["Marcus"]!
        s.question.answer = 1
        s.chips = Dictionary(uniqueKeysWithValues: start.map { (id[$0.key]!, $0.value) })
        s.phase = .bet
        s.bets = Dictionary(uniqueKeysWithValues: bets.map { (id[$0.key]!, Insider.Bet(choice: $0.value.0, chips: $0.value.1)) })
        Insider.advance(&s, &ctx)   // bet → answer
        Insider.advance(&s, &ctx)   // answer → accuse
        for a in accusers { s.accusations[id[a]!] = id["Marcus"]! }
        Insider.advance(&s, &ctx)   // accuse → reveal
        return Dictionary(uniqueKeysWithValues: s.chips.map { (roster[$0.key - 1].0, $0.value) })
    }
    #expect(play(accusers: ["Priya", "Sam", "Aiko", "Lena", "Rosa"]) == ["Marcus": 5200, "Priya": 6400, "Sam": 6200, "Aiko": 5300,
                                                                       "Lena": 4800, "Rosa": 4900, "Dev": 3800, "Wolfgangster": 3200])
    #expect(play(accusers: ["Priya", "Sam"]) == ["Marcus": 6800, "Priya": 6100, "Sam": 5900, "Aiko": 5000,
                                                 "Lena": 4500, "Rosa": 4600, "Dev": 3800, "Wolfgangster": 3200])
}

@Test func insiderDisconnectsMidRound() {
    var h = insider()
    let ins = st(h).insider
    to(.bet, &h)
    h.send(.disconnected(ins))
    for p in 1...4 where p != ins { h.msg(p, .placeBet(round: 1, choice: 0, chips: 100)) }
    #expect(st(h).phase == .answer)
    to(.accuse, &h)
    for p in 1...4 where p != ins { h.msg(p, .castVote(round: 1, choice: ins)) }
    #expect(st(h).phase == .reveal)
    #expect(st(h).caught == true)
}

@Test func accuseNotSelf() {
    var h = insider()
    to(.accuse, &h)
    h.msg(2, .castVote(round: 1, choice: 2))
    #expect(h.lastError == .notAllowed)
    h.msg(2, .castVote(round: 1, choice: 99))
    #expect(h.lastError == .invalid)
}

@Test func insiderAwards() {
    var h = insider(players: 4)
    while case .playing = h.s.phase {
        let r = st(h).round, ins = st(h).insider
        to(.accuse, &h)
        // Sam (3) always names the Insider; the rest name somebody else.
        for p in 1...4 {
            let target = p == 3 ? (ins == 3 ? 1 : ins) : (p == 1 ? 2 : 1)
            h.msg(p, .castVote(round: r, choice: target))
        }
        while case .playing = h.s.phase, st(h).round == r { h.advance(30) }
    }
    guard case .results(let res) = h.s.phase else { Issue.record("no results"); return }
    #expect(res.rounds == 6)
    #expect(res.awards.first { $0.title == "Best Detective" }?.player.name == "Sam")
    #expect(res.awards.contains { $0.title == "Smoothest Insider" })
}

@Test func sixToEightRounds() {
    var h = Harness()
    for (n, c) in roster.prefix(4) { h.join(n, c) }
    h.leader(1, .pickGame(.insider))
    #expect(h.s.settings.rounds == 6)
    h.leader(1, .setSettings(SettingsPatch(rounds: 12)))
    #expect(h.s.settings.rounds == 8)
}

@Test func revealPhoneShowsRevealChips() throws {
    var h = insider()
    let ins = st(h).insider
    to(.accuse, &h)
    for p in 1...4 where p != ins { h.msg(p, .castVote(round: 1, choice: ins)) }
    h.msg(ins, .castVote(round: 1, choice: ins == 1 ? 2 : 1))
    let accuser = try h.phone(ins == 1 ? 2 : 1).data.decode(I6Phone.self)
    #expect(accuser.caught)
    #expect(accuser.delta == 300)
    #expect(try h.phone(ins).data.decode(I6Phone.self).delta == -900)
}
