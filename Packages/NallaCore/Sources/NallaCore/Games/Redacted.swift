import Foundation

/// Redacted: everyone fakes the missing words of a real passage, then votes for the real one.
/// 3 rounds (2–5) plus a final round worth ×3. +500 per player fooled, +1,000 for finding the real text.
public enum Redacted: GameRules {
    public enum Phase: Codable, Equatable, Sendable {
        case write, readout(Int), vote, reveal, scores
    }

    public struct Version: Codable, Equatable, Sendable {
        public var number: Int
        public var fills: [String]
        public var authors: [PlayerID]
        public var real: Bool
    }

    public struct State: Equatable, Sendable {
        public var rounds: Int
        public var round = 1
        public var phase: Phase = .write
        public var deadline: Double?
        public var passage: Passage
        public var players: [PlayerID]
        public var submissions: [PlayerID: [String]] = [:]
        public var versions: [Version] = []
        public var votes: [PlayerID: Int] = [:]
        public var scores: [PlayerID: Int]
        public var deltas: [PlayerID: Int] = [:]
        public var fooledTotal: [PlayerID: Int] = [:]
        public var foundTotal: [PlayerID: Int] = [:]
        public var over = false

        var totalRounds: Int { rounds + 1 }
        var isFinal: Bool { round == totalRounds }
        var multiplier: Int { isFinal ? 3 : 1 }
    }

    public static let game = GameID.redacted
    public static let minPlayers = 3
    public static let rounds: RoundsRule? = RoundsRule(min: 2, max: 5, default: 3)
    public static let card = GameCard(id: .redacted, name: "Redacted", players: "3–8 players", length: "15 min",
                                      tagline: "Fake the missing words.", pitch: "Fake the missing words. Spot the real ones.",
                                      colour: .saffron, icon: "▮▮", minPlayers: 3)
    public static let howTo = [
        HowToStep(icon: "✍", title: "1 · Fake it", text: "Each phone shows the text with blanks. Type a believable fake."),
        HowToStep(icon: "🔍", title: "2 · Spot it", text: "All the versions appear here. Vote for the real one."),
        HowToStep(icon: "🏆", title: "3 · Score", text: "+500 for each player you fool. +1,000 for finding the real one."),
    ]
    public static func roundsLabel(_ rounds: Int?) -> String { "\(rounds ?? 3) + final" }

    public static func job(for id: PlayerID, players: [Player]) -> JobData {
        JobData(label: "Redacted · Round 1", icon: "✍", job: "Write a fake word for each blank",
                detail: "Make it believable. Fooling people scores.")
    }

    static let maxLength = 24
    static let writeSeconds = 60.0, voteSeconds = 30.0, revealSeconds = 10.0, scoresSeconds = 6.0

    /// How long one version stays on screen during the read-out.
    public static func readoutSeconds(_ text: String, voiceOn: Bool) -> Double {
        guard voiceOn else { return 4 }
        let words = text.split(whereSeparator: \.isWhitespace).count
        return max(3, (Double(words) / 2.6 + 1).rounded(toPlaces: 2))
    }

    // MARK: Lifecycle

    public static func start(_ ctx: inout GameContext) -> State {
        let passage = pickPassage(&ctx)
        return State(rounds: ctx.settings.rounds ?? 3, deadline: ctx.deadline(writeSeconds, input: true), passage: passage,
                     players: ctx.players.map(\.id), scores: Dictionary(uniqueKeysWithValues: ctx.players.map { ($0.id, 0) }))
    }

    static func pickPassage(_ ctx: inout GameContext) -> Passage {
        let family = ctx.settings.familyFriendly
        if let p = ctx.content.pick(\.passages, familyOnly: family, used: &ctx.used, rng: &ctx.rng) { return p }
        // Out of fresh passages: allow repeats rather than stopping the game.
        var none = Set<String>()
        return ctx.content.pick(\.passages, familyOnly: family, used: &none, rng: &ctx.rng)
            ?? Passage(id: "fallback", text: "The first {1} was invented in 1902.", answers: ["teddy bear"], family: true)
    }

    public static func handle(_ st: inout State, _ m: ClientMessage, from: PlayerID, _ ctx: inout GameContext) -> GameReply {
        guard st.players.contains(from) else { return .ignored }
        switch m {
        case .submitText(let round, let fields):
            guard round == st.round, st.phase == .write else { return .ignored }
            guard fields.count == st.passage.answers.count else { return .error(.invalid, "Fill in every blank.", field: nil) }
            var clean: [String] = []
            for (i, raw) in fields.enumerated() {
                let f = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
                let n = i + 1
                if f.isEmpty { return .error(.empty, "Fill in blank \(n)", field: n) }
                if f.count > maxLength { return .error(.tooLong, "Keep it to \(maxLength) characters", field: n) }
                if TextMatch.isTooClose(f, to: st.passage.answers[i]) {
                    return .error(.tooClose, "Too close to the real word, try another", field: n)
                }
                if ctx.settings.familyFriendly, ctx.content.profanity.contains(f) {
                    return .error(.notAllowed, "Let's keep it friendly. Try another", field: n)
                }
                clean.append(f)
            }
            st.submissions[from] = clean
            return .ok
        case .castVote(let round, let choice):
            guard round == st.round, st.phase == .vote else { return .ignored }
            guard let v = st.versions.first(where: { $0.number == choice }) else { return .error(.invalid, "Pick one of the versions.", field: nil) }
            guard !v.authors.contains(from) else { return .error(.notAllowed, "You can't vote for your own", field: nil) }
            st.votes[from] = choice
            return .ok
        default:
            return .error(.invalid, "That doesn't work in Redacted.", field: nil)
        }
    }

    public static func advance(_ st: inout State, _ ctx: inout GameContext) {
        switch st.phase {
        case .write:
            buildVersions(&st, &ctx)
            startReadout(&st, 0, &ctx)
        case .readout(let i):
            if i + 1 < st.versions.count {
                startReadout(&st, i + 1, &ctx)
            } else {
                st.phase = .vote
                st.deadline = ctx.deadline(voteSeconds, input: true)
            }
        case .vote:
            score(&st)
            st.phase = .reveal
            st.deadline = ctx.deadline(revealSeconds, input: false)
        case .reveal:
            st.phase = .scores
            st.deadline = ctx.deadline(scoresSeconds, input: false)
        case .scores:
            guard st.round < st.totalRounds else { st.over = true; st.deadline = nil; return }
            st.round += 1
            st.passage = pickPassage(&ctx)
            st.submissions = [:]; st.versions = []; st.votes = [:]; st.deltas = [:]
            st.phase = .write
            st.deadline = ctx.deadline(writeSeconds, input: true)
            if st.isFinal { ctx.speak("Final round! Points are tripled.") }
        }
    }

    static func startReadout(_ st: inout State, _ i: Int, _ ctx: inout GameContext) {
        st.phase = .readout(i)
        let text = PassageText.fill(st.passage.text, with: st.versions[i].fills)
        ctx.speak(text)
        st.deadline = ctx.now + readoutSeconds(text, voiceOn: ctx.settings.voiceOn)
    }

    /// The real text plus every fake; near-duplicate fakes merge into one version with several authors. Shuffled.
    static func buildVersions(_ st: inout State, _ ctx: inout GameContext) {
        var groups: [(fills: [String], authors: [PlayerID])] = []
        for pid in st.players {
            guard let fills = st.submissions[pid] else { continue }
            if let i = groups.firstIndex(where: { TextMatch.isNearDuplicate($0.fills, fills) }) {
                groups[i].authors.append(pid)
            } else {
                groups.append((fills, [pid]))
            }
        }
        var all = groups.map { Version(number: 0, fills: $0.fills, authors: $0.authors, real: false) }
        all.append(Version(number: 0, fills: st.passage.answers, authors: [], real: true))
        all.shuffle(using: &ctx.rng)
        st.versions = all.enumerated().map { i, v in var v = v; v.number = i + 1; return v }
    }

    static func score(_ st: inout State) {
        var deltas: [PlayerID: Int] = [:]
        var fooledBy: [Int: Int] = [:]
        for (voter, choice) in st.votes {
            guard let v = st.versions.first(where: { $0.number == choice }) else { continue }
            if v.real {
                deltas[voter, default: 0] += 1000 * st.multiplier
                st.foundTotal[voter, default: 0] += 1
            } else {
                fooledBy[choice, default: 0] += 1
            }
        }
        for v in st.versions where !v.real {
            let fooled = fooledBy[v.number] ?? 0
            guard fooled > 0, !v.authors.isEmpty else { continue }
            let share = (500 * fooled * st.multiplier / v.authors.count) / 10 * 10
            for a in v.authors {
                deltas[a, default: 0] += share
                st.fooledTotal[a, default: 0] += fooled
            }
        }
        st.deltas = deltas.filter { $0.value != 0 }
        for (p, d) in st.deltas { st.scores[p, default: 0] += d }
    }

    public static func allInputsIn(_ st: State, connected: Set<PlayerID>) -> Bool {
        switch st.phase {
        case .write: inputsDone(expected: Set(st.players), acted: Set(st.submissions.keys), connected: connected)
        case .vote: inputsDone(expected: Set(st.players), acted: Set(st.votes.keys), connected: connected)
        default: false
        }
    }

    public static func deadline(_ st: State) -> Double? { st.deadline }
    public static func shift(_ st: inout State, by d: Double) { st.deadline = st.deadline.map { $0 + d } }
    public static func isOver(_ st: State) -> Bool { st.over }
    public static func scores(_ st: State) -> [PlayerID: Int] { st.scores }

    public static func results(_ st: State, _ ctx: GameContext) -> GameResults {
        let awards = [
            Results.award("Best Liar", counts: st.fooledTotal, ctx: ctx) { "fooled \($0) player\($0 == 1 ? "" : "s")" },
            Results.award("Sharpest Eye", counts: st.foundTotal, ctx: ctx) { "found the real text \($0) time\($0 == 1 ? "" : "s")" },
        ].compactMap { $0 }
        return Results.make(game: .redacted, scores: st.scores, deltas: st.deltas, ctx: ctx, awards: awards, rounds: st.round)
    }

    public static func wrap(_ st: State) -> GameSession { .redacted(st) }
    public static func unwrap(_ s: GameSession) -> State? {
        if case .redacted(let st) = s { return st }
        return nil
    }
}

extension Double {
    func rounded(toPlaces p: Int) -> Double {
        let m = pow(10.0, Double(p))
        return (self * m).rounded() / m
    }
}
