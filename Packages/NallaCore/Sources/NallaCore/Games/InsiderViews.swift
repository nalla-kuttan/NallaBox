import Foundation

// Screen payloads for Insider Trading (I1–I6). Insider and Trader phone payloads have the same keys
// apart from role/answerKey/answerText, so nothing about the layout gives a role away.

public struct BetLine: Codable, Equatable, Sendable { public var player: PlayerSummary; public var choice: Int; public var chips: Int; public var won: Bool }
public struct I1TV: Codable, Equatable, Sendable { public var top: String; public var question: String; public var choices: [String] }
public struct RolePhone: Codable, Equatable, Sendable {
    public var top: String; public var role: String; public var answerKey: String?; public var answerText: String?
    public var question: String; public var choices: [String]
}
public struct I3TV: Codable, Equatable, Sendable { public var top: String; public var question: String; public var players: [PlayerSummary]; public var done: [PlayerID] }
public struct I3Phone: Codable, Equatable, Sendable {
    public var top: String; public var round: Int; public var question: String; public var choices: [String]; public var chips: Int
    public var minBet: Int; public var maxBet: Int; public var step: Int; public var bet: Insider.Bet?
}
public struct I4TV: Codable, Equatable, Sendable { public var top: String; public var question: String; public var choices: [String]; public var answer: Int; public var bets: [BetLine] }
public struct I4Phone: Codable, Equatable, Sendable {
    public var top: String; public var correctKey: String; public var correctText: String; public var bet: Insider.Bet?; public var betText: String?
    public var delta: Int; public var chips: Int
}
public struct I5TV: Codable, Equatable, Sendable { public var top: String; public var players: [PlayerSummary]; public var voted: [PlayerID] }
public struct I5Phone: Codable, Equatable, Sendable { public var top: String; public var round: Int; public var candidates: [PlayerSummary]; public var vote: PlayerID? }
public struct I6TV: Codable, Equatable, Sendable {
    public var top: String; public var insider: PlayerSummary; public var caught: Bool; public var accusers: Int; public var voters: Int
    public var commission: Int; public var penalty: Int; public var standings: [Standing]
}
public struct I6Phone: Codable, Equatable, Sendable {
    public var top: String; public var caught: Bool; public var insider: PlayerSummary; public var youAreInsider: Bool
    public var named: String?; public var accusers: Int; public var commission: Int; public var delta: Int; public var chips: Int
}

extension Insider {
    static let keys = ["A", "B", "C", "D"]
    static func top(_ st: State) -> String { "Insider Trading · Round \(st.round) of \(st.rounds)" }

    static func standings(_ st: State, _ ctx: GameContext) -> [Standing] {
        Results.standings(scores: st.chips, deltas: st.deltas, players: ctx.players.filter { st.players.contains($0.id) }, leaderId: ctx.leaderId)
    }

    public static func playerView(_ st: State, for id: PlayerID, _ ctx: GameContext) -> ScreenView {
        let t = top(st), q = st.question
        let chips = st.chips[id] ?? 0
        switch st.phase {
        case .question, .discuss:
            let me = id == st.insider
            let screen = (st.phase == .question ? "I1" : "I2") + (me ? "-insider" : "-trader")
            return ScreenView(screen, deadline: st.deadline, payload: RolePhone(
                top: t, role: me ? "insider" : "trader", answerKey: me ? keys[q.answer] : nil, answerText: me ? q.choices[q.answer] : nil,
                question: q.text, choices: q.choices))
        case .bet:
            return ScreenView("I3", deadline: st.deadline, payload: I3Phone(
                top: t, round: st.round, question: q.text, choices: q.choices, chips: chips, minBet: minBet,
                maxBet: min(maxBet, chips / 100 * 100), step: 100, bet: st.bets[id]))
        case .answer:
            let b = st.bets[id]
            return ScreenView("I4", deadline: st.deadline, payload: I4Phone(
                top: t, correctKey: keys[q.answer], correctText: q.choices[q.answer], bet: b, betText: b.map { q.choices[$0.choice] },
                delta: st.deltas[id] ?? 0, chips: chips))
        case .accuse:
            let candidates = st.players.filter { $0 != id }.compactMap { ctx.summary($0, scores: st.chips) }
            return ScreenView("I5", deadline: st.deadline, payload: I5Phone(top: t, round: st.round, candidates: candidates, vote: st.accusations[id]))
        case .reveal:
            let ins = ctx.summary(st.insider, scores: st.chips) ?? PlayerSummary(id: st.insider, name: "The Insider", colour: .mint, connected: false, isLeader: false, score: 0)
            return ScreenView("I6", deadline: st.deadline, payload: I6Phone(
                top: t, caught: st.caught ?? false, insider: ins, youAreInsider: id == st.insider,
                named: st.accusations[id].map(ctx.name), accusers: st.accusers.count, commission: st.commission,
                delta: st.revealDeltas[id] ?? 0, chips: chips))
        }
    }

    public static func tvView(_ st: State, _ ctx: GameContext) -> (ScreenView, FaceCue) {
        let t = top(st), q = st.question
        let summaries = st.players.compactMap { ctx.summary($0, scores: st.chips) }
        switch st.phase {
        case .question:
            return (ScreenView("I1", deadline: st.deadline, payload: I1TV(top: t, question: q.text, choices: q.choices)), FaceCue(.suspicious, "One of you already knows."))
        case .discuss:
            return (ScreenView("I2", deadline: st.deadline, payload: I1TV(top: t, question: q.text, choices: q.choices)), FaceCue(.suspicious, "Who sounds a little too sure?"))
        case .bet:
            return (ScreenView("I3", deadline: st.deadline, payload: I3TV(top: t, question: q.text, players: summaries, done: st.bets.keys.sorted())),
                    FaceCue(.wink, "Bets close soon."))
        case .answer:
            let lines = st.players.compactMap { p -> BetLine? in
                guard let b = st.bets[p], let s = ctx.summary(p, scores: st.chips) else { return nil }
                return BetLine(player: s, choice: b.choice, chips: b.chips, won: b.choice == q.answer)
            }
            return (ScreenView("I4", deadline: st.deadline, payload: I4TV(top: t, question: q.text, choices: q.choices, answer: q.answer, bets: lines)),
                    FaceCue(.gasp, caption("\(q.choices[q.answer])! Who saw that coming?")))
        case .accuse:
            return (ScreenView("I5", deadline: st.deadline, payload: I5TV(top: t, players: summaries, voted: st.accusations.keys.sorted())),
                    FaceCue(.suspicious, "Someone here knew the answer."))
        case .reveal:
            let ins = ctx.summary(st.insider, scores: st.chips) ?? PlayerSummary(id: st.insider, name: "The Insider", colour: .mint, connected: false, isLeader: false, score: 0)
            let caught = st.caught ?? false
            return (ScreenView("I6", deadline: st.deadline, payload: I6TV(
                top: t, insider: ins, caught: caught, accusers: st.accusers.count, voters: st.players.count - 1,
                commission: st.commission, penalty: penalty, standings: standings(st, ctx))),
                    caught ? FaceCue(.gasp, "Caught red-handed!") : FaceCue(.wink, "Smooth. Very smooth."))
        }
    }
}
