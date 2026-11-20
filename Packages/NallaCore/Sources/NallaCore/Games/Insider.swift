import Foundation

/// Insider Trading: one secret Insider knows the answer. Everyone talks, bets chips on an answer, then votes on who
/// the Insider was. 6–8 rounds; 5,000 starting chips; points are chips.
public enum Insider: GameRules {
    public enum Phase: Codable, Equatable, Sendable { case question, discuss, bet, answer, accuse, reveal }

    public struct Bet: Codable, Equatable, Sendable {
        public var choice: Int
        public var chips: Int
    }

    public struct State: Equatable, Sendable {
        public var players: [PlayerID]
        public var rounds: Int
        public var round = 1
        public var phase: Phase = .question
        public var deadline: Double?
        public var question: Question
        public var insider: PlayerID
        public var queue: [PlayerID] = []
        public var chips: [PlayerID: Int]
        public var bets: [PlayerID: Bet] = [:]
        public var accusations: [PlayerID: PlayerID] = [:]
        public var deltas: [PlayerID: Int] = [:]
        public var caught: Bool?
        public var commission = 0
        public var accusers: [PlayerID] = []
        /// Chips won or lost at the reveal (penalty, +300s, commission), shown on I6.
        public var revealDeltas: [PlayerID: Int] = [:]
        public var escapes: [PlayerID: Int] = [:]
        public var detective: [PlayerID: Int] = [:]
        public var over = false
    }

    public static let game = GameID.insider
    public static let minPlayers = 4
    public static let rounds: RoundsRule? = RoundsRule(min: 6, max: 8, default: 6)
    public static let card = GameCard(id: .insider, name: "Insider Trading", players: "4–8 players", length: "15 min",
                                      tagline: "One of you knows the answer.", pitch: "One of you knows the answer. Who?",
                                      colour: .mint, icon: "?!", minPlayers: 4)
    public static let howTo = [
        HowToStep(icon: "🤫", title: "1 · Roles", text: "Hold your phone card to see your role. One of you is the Insider."),
        HowToStep(icon: "🪙", title: "2 · Bet", text: "Talk it out, then bet 100 to 1,000 chips on an answer."),
        HowToStep(icon: "🕵️", title: "3 · Accuse", text: "Name the Insider. A majority catches them: +300 each."),
    ]
    public static func roundsLabel(_ rounds: Int?) -> String { "\(rounds ?? 6) rounds" }

    public static func job(for id: PlayerID, players: [Player]) -> JobData {
        JobData(label: "Insider Trading · Round 1", icon: "🤫", job: "Hold your card to see your role",
                detail: "One of you knows the answer. Bet well, then find them.")
    }

    public static let startChips = 5000, bailoutChips = 500, minBet = 100, maxBet = 1000, penalty = 300
    static let questionSeconds = 5.0, discussSeconds = 30.0, betSeconds = 15.0, answerSeconds = 8.0, accuseSeconds = 15.0, revealSeconds = 10.0

    public static func start(_ ctx: inout GameContext) -> State {
        let ids = ctx.players.map(\.id)
        var st = State(players: ids, rounds: ctx.settings.rounds ?? 6, question: pickQuestion(&ctx), insider: ids.first ?? 0,
                       chips: Dictionary(uniqueKeysWithValues: ids.map { ($0, startChips) }))
        st.insider = nextInsider(&st, &ctx, last: nil)
        st.deadline = ctx.deadline(questionSeconds, input: false)
        return st
    }

    static func pickQuestion(_ ctx: inout GameContext) -> Question {
        let family = ctx.settings.familyFriendly
        if let q = ctx.content.pick(\.questions, familyOnly: family, used: &ctx.used, rng: &ctx.rng) { return q }
        var none = Set<String>()
        return ctx.content.pick(\.questions, familyOnly: family, used: &none, rng: &ctx.rng)
            ?? Question(id: "fallback", text: "How many legs does a spider have?", choices: ["Six", "Eight", "Ten", "Twelve"], answer: 1, family: true)
    }

    /// Everyone is Insider once before anyone repeats, and never twice in a row.
    static func nextInsider(_ st: inout State, _ ctx: inout GameContext, last: PlayerID?) -> PlayerID {
        if st.queue.isEmpty {
            st.queue = st.players.shuffled(using: &ctx.rng)
            if st.queue.count > 1, st.queue.first == last { st.queue.swapAt(0, 1) }
        }
        return st.queue.removeFirst()
    }

    public static func handle(_ st: inout State, _ m: ClientMessage, from: PlayerID, _ ctx: inout GameContext) -> GameReply {
        guard st.players.contains(from) else { return .ignored }
        switch m {
        case .placeBet(let round, let choice, let chips):
            guard round == st.round, st.phase == .bet else { return .ignored }
            guard (0...3).contains(choice) else { return .error(.invalid, "Pick A, B, C or D.", field: nil) }
            let have = st.chips[from] ?? 0
            guard (minBet...maxBet).contains(chips), chips % 100 == 0 else { return .error(.invalid, "Bet 100 to 1,000 chips, in steps of 100.", field: nil) }
            guard chips <= have / 100 * 100 else { return .error(.invalid, "You only have \(grouped(have)) chips.", field: nil) }
            st.bets[from] = Bet(choice: choice, chips: chips)
            return .ok
        case .castVote(let round, let target):
            guard round == st.round, st.phase == .accuse else { return .ignored }
            guard st.players.contains(target) else { return .error(.invalid, "Pick one of the players.", field: nil) }
            guard target != from else { return .error(.notAllowed, "You can't name yourself.", field: nil) }
            st.accusations[from] = target
            return .ok
        default:
            return .error(.invalid, "That doesn't work in Insider Trading.", field: nil)
        }
    }

    public static func advance(_ st: inout State, _ ctx: inout GameContext) {
        switch st.phase {
        case .question:
            st.phase = .discuss
            st.deadline = ctx.deadline(discussSeconds, input: true)
        case .discuss:
            st.phase = .bet
            st.deadline = ctx.deadline(betSeconds, input: true)
        case .bet:
            for (p, b) in st.bets {
                let d = b.choice == st.question.answer ? b.chips : -b.chips
                st.chips[p, default: 0] += d
                st.deltas[p, default: 0] += d
            }
            st.phase = .answer
            st.deadline = ctx.deadline(answerSeconds, input: false)
            ctx.speak("The answer is \(st.question.choices[st.question.answer]).")
        case .answer:
            st.phase = .accuse
            st.deadline = ctx.deadline(accuseSeconds, input: true)
        case .accuse:
            st.accusers = st.accusations.filter { $0.value == st.insider && $0.key != st.insider }.keys.sorted()
            let others = st.players.count - 1
            let caught = st.accusers.count * 2 > others
            st.caught = caught
            if caught {
                for a in st.accusers {
                    st.chips[a, default: 0] += penalty
                    st.deltas[a, default: 0] += penalty
                    st.detective[a, default: 0] += 1
                    st.revealDeltas[a] = penalty
                }
                let before = st.chips[st.insider] ?? 0
                let after = max(0, before - penalty * st.accusers.count)
                st.chips[st.insider] = after
                st.deltas[st.insider, default: 0] += after - before
                st.revealDeltas[st.insider] = after - before
                st.commission = 0
            } else {
                st.commission = st.bets.filter { $0.key != st.insider && $0.value.choice == st.question.answer }.values.map(\.chips).reduce(0, +) / 10
                st.chips[st.insider, default: 0] += st.commission
                st.deltas[st.insider, default: 0] += st.commission
                st.escapes[st.insider, default: 0] += 1
                st.revealDeltas[st.insider] = st.commission
            }
            st.deltas = st.deltas.filter { $0.value != 0 }
            st.phase = .reveal
            st.deadline = ctx.deadline(revealSeconds, input: false)
            ctx.speak(caught ? "Caught! \(ctx.name(st.insider)) was the Insider." : "\(ctx.name(st.insider)) was the Insider, and got away with it.")
        case .reveal:
            guard st.round < st.rounds else { st.over = true; st.deadline = nil; return }
            st.round += 1
            for p in st.players where (st.chips[p] ?? 0) < minBet { st.chips[p] = bailoutChips }
            st.question = pickQuestion(&ctx)
            st.insider = nextInsider(&st, &ctx, last: st.insider)
            st.bets = [:]; st.accusations = [:]; st.deltas = [:]; st.caught = nil; st.commission = 0; st.accusers = []; st.revealDeltas = [:]
            st.phase = .question
            st.deadline = ctx.deadline(questionSeconds, input: false)
        }
    }

    public static func allInputsIn(_ st: State, connected: Set<PlayerID>) -> Bool {
        switch st.phase {
        case .bet: inputsDone(expected: Set(st.players), acted: Set(st.bets.keys), connected: connected)
        case .accuse: inputsDone(expected: Set(st.players), acted: Set(st.accusations.keys), connected: connected)
        default: false
        }
    }

    public static func deadline(_ st: State) -> Double? { st.deadline }
    public static func shift(_ st: inout State, by d: Double) { st.deadline = st.deadline.map { $0 + d } }
    public static func isOver(_ st: State) -> Bool { st.over }
    public static func scores(_ st: State) -> [PlayerID: Int] { st.chips }

    public static func results(_ st: State, _ ctx: GameContext) -> GameResults {
        let awards = [
            Results.award("Smoothest Insider", counts: st.escapes, ctx: ctx) { "escaped \($0) time\($0 == 1 ? "" : "s")" },
            Results.award("Best Detective", counts: st.detective, ctx: ctx) { "named the Insider \($0) time\($0 == 1 ? "" : "s")" },
        ].compactMap { $0 }
        return Results.make(game: .insider, scores: st.chips, deltas: st.deltas, ctx: ctx, awards: awards, rounds: st.round)
    }

    public static func wrap(_ st: State) -> GameSession { .insider(st) }
    public static func unwrap(_ s: GameSession) -> State? {
        if case .insider(let st) = s { return st }
        return nil
    }
}
