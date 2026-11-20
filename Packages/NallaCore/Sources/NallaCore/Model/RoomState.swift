import Foundation

public enum GameID: String, Codable, CaseIterable, Sendable {
    case redacted, sketch, insider
    #if DEBUG
    /// Test-only game used by the engine and hub tests; never listed in the picker.
    case test
    #endif

    /// Games offered in the picker, in display order.
    public static let playable: [GameID] = [.redacted, .sketch, .insider]
}

/// Multiplies input-phase durations; `off` removes their deadlines.
public enum TimerSpeed: String, Codable, CaseIterable, Sendable {
    case x1 = "1", x15 = "1.5", x2 = "2", off
    public var multiplier: Double? {
        switch self {
        case .x1: 1
        case .x15: 1.5
        case .x2: 2
        case .off: nil
        }
    }
}

public struct RoomSettings: Codable, Equatable, Sendable {
    /// Normal rounds for games that have a rounds setting (Redacted, Insider Trading); nil = the game's default.
    public var rounds: Int?
    public var timer: TimerSpeed
    public var familyFriendly: Bool
    public var bannedWords: Bool
    public var voiceOn: Bool

    public init(rounds: Int? = nil, timer: TimerSpeed = .x1, familyFriendly: Bool = true, bannedWords: Bool = false, voiceOn: Bool = true) {
        self.rounds = rounds; self.timer = timer; self.familyFriendly = familyFriendly
        self.bannedWords = bannedWords; self.voiceOn = voiceOn
    }
}

public struct Pause: Codable, Equatable, Sendable {
    public var by: String
    public var byPlayer: PlayerID?
    public var at: Double
}

public struct Toast: Codable, Equatable, Sendable {
    public var text: String
    public var until: Double
}

public enum RoomPhase: Equatable, Sendable {
    case lobby
    case picker
    case settings(GameID)
    case howTo(GameID, until: Double)
    case playing(GameSession)
    case results(GameResults)
}

/// The whole room, owned by the hub and changed only through `Engine.reduce`.
public struct RoomState: Equatable, Sendable {
    public var code: String
    public var players: [Player] = []
    public var leaderId: PlayerID?
    public var nextId = 1
    public var phase: RoomPhase = .lobby
    public var settings = RoomSettings()
    public var preview: GameID?
    public var pause: Pause?
    public var rng: SplitMix64
    public var used: Set<String> = []
    public var openedAt: Double
    public var helpShown = false
    public var toast: Toast?
    /// Filled in by the hub once it knows the LAN address.
    public var joinURL: String?

    public static func new(code: String, seed: UInt64, now: Double) -> RoomState {
        RoomState(code: code, rng: SplitMix64(seed: seed), openedAt: now)
    }

    public func player(_ id: PlayerID) -> Player? { players.first { $0.id == id } }
    public var leader: Player? { leaderId.flatMap(player) }
}
