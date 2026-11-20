import Foundation

public enum GameID: String, Codable, CaseIterable, Sendable {
    case redacted, sketch, insider
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
