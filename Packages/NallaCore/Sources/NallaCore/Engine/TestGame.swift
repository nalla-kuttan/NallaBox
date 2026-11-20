#if DEBUG
import Foundation

/// A two-phase fake game for engine and hub tests: an input phase (10 s, everyone taps once, +100)
/// then a fixed phase (5 s), for `rounds` rounds.
public enum TestGame: GameRules {
    public struct State: Equatable, Sendable {
        var round = 1
        var rounds: Int
        var phase = "input"
        var deadline: Double?
        var acted: Set<PlayerID> = []
        var scores: [PlayerID: Int]
        var deltas: [PlayerID: Int] = [:]
        var over = false
    }

    public static let game = GameID.test
    public static let minPlayers = 3
    public static let rounds: RoundsRule? = RoundsRule(min: 2, max: 5, default: 2)
    public static let card = GameCard(id: .test, name: "Test Game", players: "3–8 players", length: "2 min",
                                      tagline: "Tap to win.", pitch: "A game for tests.", colour: .sky, icon: "T", minPlayers: 3)
    public static let howTo = [HowToStep(icon: "1", title: "1 · Tap", text: "Tap once."),
                               HowToStep(icon: "2", title: "2 · Wait", text: "Wait a bit."),
                               HowToStep(icon: "3", title: "3 · Score", text: "+100 a tap.")]
    public static func roundsLabel(_ rounds: Int?) -> String { "\(rounds ?? 2) rounds" }
    public static func job(for id: PlayerID, players: [Player]) -> JobData {
        JobData(label: "Test Game · Round 1", icon: "✓", job: "Tap the button", detail: nil)
    }

    public static func start(_ ctx: inout GameContext) -> State {
        State(rounds: ctx.settings.rounds ?? 2, deadline: ctx.deadline(10, input: true),
              scores: Dictionary(uniqueKeysWithValues: ctx.players.map { ($0.id, 0) }))
    }

    public static func handle(_ st: inout State, _ m: ClientMessage, from: PlayerID, _ ctx: inout GameContext) -> GameReply {
        guard case .castVote(let round, _) = m else { return .error(.invalid, "Not in this game.", field: nil) }
        guard round == st.round, st.phase == "input", !st.acted.contains(from) else { return .ignored }
        st.acted.insert(from)
        st.scores[from, default: 0] += 100
        st.deltas[from, default: 0] += 100
        return .ok
    }

    public static func advance(_ st: inout State, _ ctx: inout GameContext) {
        if st.phase == "input" {
            st.phase = "fixed"; st.deadline = ctx.deadline(5, input: false)
        } else if st.round >= st.rounds {
            st.over = true; st.deadline = nil
        } else {
            st.round += 1; st.phase = "input"; st.acted = []; st.deltas = [:]; st.deadline = ctx.deadline(10, input: true)
        }
    }

    public static func allInputsIn(_ st: State, connected: Set<PlayerID>) -> Bool {
        st.phase == "input" && inputsDone(expected: Set(st.scores.keys), acted: st.acted, connected: connected)
    }
    public static func deadline(_ st: State) -> Double? { st.deadline }
    public static func shift(_ st: inout State, by d: Double) { st.deadline = st.deadline.map { $0 + d } }
    public static func isOver(_ st: State) -> Bool { st.over }
    public static func scores(_ st: State) -> [PlayerID: Int] { st.scores }

    public static func results(_ st: State, _ ctx: GameContext) -> GameResults {
        Results.make(game: .test, scores: st.scores, deltas: st.deltas, ctx: ctx, awards: [], rounds: st.round)
    }

    public static func playerView(_ st: State, for id: PlayerID, _ ctx: GameContext) -> ScreenView {
        ScreenView("X1", deadline: st.deadline, data: .object(["round": .number(Double(st.round)), "phase": .string(st.phase)]))
    }

    public static func tvView(_ st: State, _ ctx: GameContext) -> (ScreenView, FaceCue) {
        (ScreenView("X1", deadline: st.deadline, data: .object(["round": .number(Double(st.round))])), FaceCue(.idle))
    }

    public static func wrap(_ st: State) -> GameSession { .test(st) }
    public static func unwrap(_ s: GameSession) -> State? {
        if case .test(let st) = s { return st }
        return nil
    }
}
#endif
