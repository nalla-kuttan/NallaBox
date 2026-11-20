import Foundation

public struct RoundsRule: Codable, Equatable, Sendable {
    public var min: Int
    public var max: Int
    public var `default`: Int
    public init(min: Int, max: Int, default d: Int) { self.min = min; self.max = max; self.default = d }
}

public struct GameCard: Codable, Equatable, Sendable {
    public var id: GameID
    public var name: String
    public var players: String
    public var length: String
    public var tagline: String
    public var pitch: String
    public var colour: PlayerColour
    public var icon: String
    public var minPlayers: Int
}

public struct HowToStep: Codable, Equatable, Sendable {
    public var icon: String
    public var title: String
    public var text: String
}

/// P7 "Your job": one line for the next phase.
public struct JobData: Codable, Equatable, Sendable {
    public var label: String
    public var icon: String
    public var job: String
    public var detail: String?
}

public enum GameReply: Equatable, Sendable {
    case ok, ignored
    case error(ErrorCode, String, field: Int?)
}

/// What a game sees of the room for one step. Mutations to `rng`, `used` and `speech` flow back into the room.
public struct GameContext: Sendable {
    public var players: [Player]
    public var leaderId: PlayerID?
    public var settings: RoomSettings
    public var now: Double
    public var rng: SplitMix64
    public var content: ContentLibrary
    public var used: Set<String>
    public var speech: [String] = []

    /// Base duration for a phase. Input phases scale with the timer setting and have none when it's off.
    public func duration(_ base: Double, input: Bool) -> Double? {
        input ? settings.timer.multiplier.map { base * $0 } : base
    }

    public func deadline(_ base: Double, input: Bool) -> Double? {
        duration(base, input: input).map { now + $0 }
    }

    public mutating func speak(_ line: String) { speech.append(line) }

    public var connectedIds: Set<PlayerID> { Set(players.filter(\.connected).map(\.id)) }

    public func summary(_ id: PlayerID, scores: [PlayerID: Int] = [:]) -> PlayerSummary? {
        players.first { $0.id == id }.map {
            PlayerSummary(id: $0.id, name: $0.name, colour: $0.colour, connected: $0.connected,
                          isLeader: $0.id == leaderId, score: scores[$0.id] ?? 0)
        }
    }

    public func name(_ id: PlayerID) -> String { players.first { $0.id == id }?.name ?? "Someone" }
}

/// True when every connected player we're waiting on has acted (and at least one is connected).
public func inputsDone(expected: Set<PlayerID>, acted: Set<PlayerID>, connected: Set<PlayerID>) -> Bool {
    let live = expected.intersection(connected)
    return !live.isEmpty && live.isSubset(of: acted)
}

/// One game's rules. All functions are pure: state in, state out.
public protocol GameRules {
    associatedtype State: Equatable & Sendable
    static var game: GameID { get }
    static var minPlayers: Int { get }
    static var rounds: RoundsRule? { get }
    static var card: GameCard { get }
    static var howTo: [HowToStep] { get }
    static func roundsLabel(_ rounds: Int?) -> String
    static func job(for id: PlayerID, players: [Player]) -> JobData
    static func start(_ ctx: inout GameContext) -> State
    static func handle(_ st: inout State, _ m: ClientMessage, from: PlayerID, _ ctx: inout GameContext) -> GameReply
    /// Moves to the next phase: the deadline passed, all inputs are in, or the leader skipped.
    static func advance(_ st: inout State, _ ctx: inout GameContext)
    /// Must be false in phases that take no input.
    static func allInputsIn(_ st: State, connected: Set<PlayerID>) -> Bool
    static func deadline(_ st: State) -> Double?
    static func shift(_ st: inout State, by: Double)
    static func isOver(_ st: State) -> Bool
    static func scores(_ st: State) -> [PlayerID: Int]
    static func results(_ st: State, _ ctx: GameContext) -> GameResults
    static func playerView(_ st: State, for id: PlayerID, _ ctx: GameContext) -> ScreenView
    static func tvView(_ st: State, _ ctx: GameContext) -> (ScreenView, FaceCue)
    static func wrap(_ st: State) -> GameSession
    static func unwrap(_ s: GameSession) -> State?
}

/// The running game's state, one case per game.
public enum GameSession: Equatable, Sendable {
    case redacted(Redacted.State)
    #if DEBUG
    case test(TestGame.State)
    #endif

    public var rules: any GameRules.Type {
        switch self {
        case .redacted: Redacted.self
        #if DEBUG
        case .test: TestGame.self
        #endif
        }
    }
}

extension GameID {
    /// The rules for this game, or nil if it isn't built yet.
    public var rules: (any GameRules.Type)? {
        switch self {
        case .redacted: Redacted.self
        case .sketch, .insider: nil
        #if DEBUG
        case .test: TestGame.self
        #endif
        }
    }
}

/// Generic trampolines so the engine can call any game through `GameSession.rules` (existential opening).
enum GameRunner {
    static func start<G: GameRules>(_ g: G.Type, _ ctx: inout GameContext) -> GameSession { G.wrap(G.start(&ctx)) }

    static func handle<G: GameRules>(_ g: G.Type, _ s: inout GameSession, _ m: ClientMessage, _ from: PlayerID, _ ctx: inout GameContext) -> GameReply {
        guard var st = G.unwrap(s) else { return .ignored }
        let r = G.handle(&st, m, from: from, &ctx)
        s = G.wrap(st)
        return r
    }

    static func advance<G: GameRules>(_ g: G.Type, _ s: inout GameSession, _ ctx: inout GameContext) {
        guard var st = G.unwrap(s) else { return }
        G.advance(&st, &ctx)
        s = G.wrap(st)
    }

    static func shift<G: GameRules>(_ g: G.Type, _ s: inout GameSession, by d: Double) {
        guard var st = G.unwrap(s) else { return }
        G.shift(&st, by: d)
        s = G.wrap(st)
    }

    static func allInputsIn<G: GameRules>(_ g: G.Type, _ s: GameSession, _ connected: Set<PlayerID>) -> Bool {
        G.unwrap(s).map { G.allInputsIn($0, connected: connected) } ?? false
    }
    static func deadline<G: GameRules>(_ g: G.Type, _ s: GameSession) -> Double? { G.unwrap(s).flatMap(G.deadline) }
    static func isOver<G: GameRules>(_ g: G.Type, _ s: GameSession) -> Bool { G.unwrap(s).map(G.isOver) ?? true }
    static func scores<G: GameRules>(_ g: G.Type, _ s: GameSession) -> [PlayerID: Int] { G.unwrap(s).map(G.scores) ?? [:] }
    static func results<G: GameRules>(_ g: G.Type, _ s: GameSession, _ ctx: GameContext) -> GameResults? {
        G.unwrap(s).map { G.results($0, ctx) }
    }
    static func playerView<G: GameRules>(_ g: G.Type, _ s: GameSession, _ id: PlayerID, _ ctx: GameContext) -> ScreenView {
        G.unwrap(s).map { G.playerView($0, for: id, ctx) } ?? ScreenView("P8")
    }
    static func tvView<G: GameRules>(_ g: G.Type, _ s: GameSession, _ ctx: GameContext) -> (ScreenView, FaceCue) {
        G.unwrap(s).map { G.tvView($0, ctx) } ?? (ScreenView("T2"), FaceCue(.idle))
    }
}
