import Foundation

/// Composite Sketch: one Witness sees a scene and describes it; everyone else draws it blind.
/// One round per player. The Witness picks the closest drawing (+1,000 artist, +500 Witness), then everyone
/// votes for the worst likeness (Most Wanted award).
public enum Sketch: GameRules {
    public enum Phase: Codable, Equatable, Sendable { case brief, draw, pick, reveal, mostWanted, scores }

    public struct Drawing: Codable, Equatable, Sendable {
        public var number: Int
        public var artist: PlayerID
        public var strokes: [Stroke]
    }

    public struct State: Equatable, Sendable {
        public var order: [PlayerID]
        public var players: [PlayerID]
        public var round = 1
        public var phase: Phase = .brief
        public var deadline: Double?
        public var scene: Scene
        public var strokes: [PlayerID: [Stroke]] = [:]
        public var finals: Set<PlayerID> = []
        public var drawings: [Drawing] = []
        public var pick: Int?
        public var worstVotes: [PlayerID: Int] = [:]
        public var scores: [PlayerID: Int]
        public var deltas: [PlayerID: Int] = [:]
        public var mostWantedTotal: [PlayerID: Int] = [:]
        public var pickedTotal: [PlayerID: Int] = [:]
        public var over = false

        public var witness: PlayerID { order[round - 1] }
        var artists: [PlayerID] { players.filter { $0 != witness } }
    }

    public static let game = GameID.sketch
    public static let minPlayers = 3
    public static let rounds: RoundsRule? = nil
    public static let card = GameCard(id: .sketch, name: "Composite Sketch", players: "3–8 players", length: "15 min",
                                      tagline: "Describe it. Draw it blind.", pitch: "One witness describes. Everyone draws blind.",
                                      colour: .sky, icon: "✎", minPlayers: 3)
    public static let howTo = [
        HowToStep(icon: "👁", title: "1 · Witness", text: "One player sees a scene and describes it out loud."),
        HowToStep(icon: "✎", title: "2 · Draw", text: "Everyone else draws what they hear. No peeking."),
        HowToStep(icon: "🏆", title: "3 · Pick", text: "Closest match: +1,000 to the artist, +500 to the Witness."),
    ]
    public static func roundsLabel(_ rounds: Int?) -> String { "1 per player" }

    public static func job(for id: PlayerID, players: [Player]) -> JobData {
        let first = players.first { !$0.waitingForNextGame }
        if first?.id == id {
            return JobData(label: "Composite Sketch · Round 1", icon: "👁", job: "You're the first Witness",
                           detail: "You'll see a scene. Describe it out loud.")
        }
        return JobData(label: "Composite Sketch · Round 1", icon: "✎", job: "Draw what you hear",
                       detail: "\(first?.name ?? "The Witness") describes a scene. Draw it on your phone.")
    }

    static let briefSeconds = 5.0, drawSeconds = 30.0, pickSeconds = 20.0, revealSeconds = 8.0, worstSeconds = 15.0, scoresSeconds = 6.0
    public static let maxPoints = 2000

    public static func start(_ ctx: inout GameContext) -> State {
        let ids = ctx.players.map(\.id)
        var st = State(order: ids, players: ids, scene: pickScene(&ctx), scores: Dictionary(uniqueKeysWithValues: ids.map { ($0, 0) }))
        st.deadline = ctx.deadline(briefSeconds, input: false)
        ctx.speak("\(ctx.name(st.witness)) is the Witness.")
        return st
    }

    static func pickScene(_ ctx: inout GameContext) -> Scene {
        let family = ctx.settings.familyFriendly
        if let s = ctx.content.pick(\.scenes, familyOnly: family, used: &ctx.used, rng: &ctx.rng) { return s }
        var none = Set<String>()
        return ctx.content.pick(\.scenes, familyOnly: family, used: &none, rng: &ctx.rng)
            ?? Scene(id: "fallback", caption: "A cat wearing a crown", art: "🐈👑", image: nil, banned: ["cat", "crown", "king"], family: true)
    }

    /// Drops strokes with unknown colours or sizes, clamps points to 0…1, and caps the drawing at 2,000 points.
    static func sanitize(_ strokes: [Stroke]) -> [Stroke] {
        var out: [Stroke] = [], budget = maxPoints
        for s in strokes where budget > 0 && (0...5).contains(s.c) && (0...2).contains(s.s) && s.p.count >= 2 {
            var p = s.p.count % 2 == 0 ? s.p : Array(s.p.dropLast())
            p = p.map { $0.isFinite ? min(1, max(0, $0)) : 0 }
            let n = min(p.count / 2, budget)
            out.append(Stroke(c: s.c, s: s.s, p: Array(p.prefix(n * 2))))
            budget -= n
        }
        return out
    }

    public static func handle(_ st: inout State, _ m: ClientMessage, from: PlayerID, _ ctx: inout GameContext) -> GameReply {
        guard st.players.contains(from) else { return .ignored }
        switch m {
        case .strokeData(let round, let strokes, let final):
            guard round == st.round, st.phase == .draw else { return .ignored }
            guard from != st.witness else { return .error(.notAllowed, "The Witness describes. No drawing!", field: nil) }
            st.strokes[from] = sanitize(strokes)
            if final { st.finals.insert(from) }
            return .ok
        case .castVote(let round, let choice):
            guard round == st.round, st.phase == .pick || st.phase == .mostWanted else { return .ignored }
            guard let d = st.drawings.first(where: { $0.number == choice }) else { return .error(.invalid, "Pick one of the drawings.", field: nil) }
            if st.phase == .pick {
                guard from == st.witness else { return .error(.notAllowed, "Only the Witness picks.", field: nil) }
                st.pick = choice
            } else {
                guard d.artist != from else { return .error(.notAllowed, "You can't vote for your own", field: nil) }
                st.worstVotes[from] = choice
            }
            return .ok
        default:
            return .error(.invalid, "That doesn't work in Composite Sketch.", field: nil)
        }
    }

    public static func advance(_ st: inout State, _ ctx: inout GameContext) {
        switch st.phase {
        case .brief:
            st.phase = .draw
            st.deadline = ctx.deadline(drawSeconds, input: true)
            ctx.speak("\(ctx.name(st.witness)), describe it out loud!")
        case .draw:
            var made = st.artists.compactMap { a in st.strokes[a].flatMap { $0.isEmpty ? nil : Drawing(number: 0, artist: a, strokes: $0) } }
            made.shuffle(using: &ctx.rng)
            st.drawings = made.enumerated().map { i, d in var d = d; d.number = i + 1; return d }
            if st.drawings.isEmpty {
                st.phase = .reveal
                st.deadline = ctx.deadline(revealSeconds, input: false)
            } else {
                st.phase = .pick
                st.deadline = ctx.deadline(pickSeconds, input: true)
            }
        case .pick:
            if let n = st.pick, let d = st.drawings.first(where: { $0.number == n }) {
                award(&st, d.artist, 1000)
                award(&st, st.witness, 500)
                st.pickedTotal[d.artist, default: 0] += 1
            }
            st.phase = .reveal
            st.deadline = ctx.deadline(revealSeconds, input: false)
        case .reveal:
            if st.drawings.count >= 2 {
                st.phase = .mostWanted
                st.deadline = ctx.deadline(worstSeconds, input: true)
            } else {
                toScores(&st, &ctx)
            }
        case .mostWanted:
            for n in st.worstVotes.values {
                if let d = st.drawings.first(where: { $0.number == n }) { st.mostWantedTotal[d.artist, default: 0] += 1 }
            }
            toScores(&st, &ctx)
        case .scores:
            guard st.round < st.order.count else { st.over = true; st.deadline = nil; return }
            st.round += 1
            st.scene = pickScene(&ctx)
            st.strokes = [:]; st.finals = []; st.drawings = []; st.pick = nil; st.worstVotes = [:]; st.deltas = [:]
            st.phase = .brief
            st.deadline = ctx.deadline(briefSeconds, input: false)
            ctx.speak("\(ctx.name(st.witness)) is the Witness.")
        }
    }

    static func toScores(_ st: inout State, _ ctx: inout GameContext) {
        st.phase = .scores
        st.deadline = ctx.deadline(scoresSeconds, input: false)
    }

    static func award(_ st: inout State, _ p: PlayerID, _ points: Int) {
        st.deltas[p, default: 0] += points
        st.scores[p, default: 0] += points
    }

    public static func allInputsIn(_ st: State, connected: Set<PlayerID>) -> Bool {
        switch st.phase {
        case .draw: inputsDone(expected: Set(st.artists), acted: st.finals, connected: connected)
        case .pick: inputsDone(expected: [st.witness], acted: st.pick == nil ? [] : [st.witness], connected: connected)
        case .mostWanted: inputsDone(expected: Set(st.players), acted: Set(st.worstVotes.keys), connected: connected)
        default: false
        }
    }

    public static func deadline(_ st: State) -> Double? { st.deadline }
    public static func shift(_ st: inout State, by d: Double) { st.deadline = st.deadline.map { $0 + d } }
    public static func isOver(_ st: State) -> Bool { st.over }
    public static func scores(_ st: State) -> [PlayerID: Int] { st.scores }

    public static func results(_ st: State, _ ctx: GameContext) -> GameResults {
        let awards = [
            Results.award("Most Wanted", counts: st.mostWantedTotal, ctx: ctx) { "\($0) vote\($0 == 1 ? "" : "s") for worst likeness" },
            Results.award("Sharpest Pencil", counts: st.pickedTotal, ctx: ctx) { "picked \($0) time\($0 == 1 ? "" : "s")" },
        ].compactMap { $0 }
        return Results.make(game: .sketch, scores: st.scores, deltas: st.deltas, ctx: ctx, awards: awards, rounds: st.round)
    }

    public static func wrap(_ st: State) -> GameSession { .sketch(st) }
    public static func unwrap(_ s: GameSession) -> State? {
        if case .sketch(let st) = s { return st }
        return nil
    }
}
