import Foundation

/// Seat number in join order, 1-based, never reused within a room.
public typealias PlayerID = Int

public struct ConnectionID: Hashable, Sendable, CustomStringConvertible {
    public let raw: UUID
    public init(_ raw: UUID = UUID()) { self.raw = raw }
    public var description: String { String(raw.uuidString.prefix(8)) }
}

/// Player avatar colours. Coral belongs to the system and is never a player colour.
public enum PlayerColour: String, Codable, CaseIterable, Sendable {
    case saffron, sky, mint, lilac, pink, lime, teal, sand
}

public struct Player: Codable, Equatable, Sendable {
    public var id: PlayerID
    public var name: String
    public var colour: PlayerColour
    public var seatToken: String
    public var connected: Bool
    public var disconnectedAt: Double?
    public var isHost: Bool
    public var waitingForNextGame: Bool
    public var joinedAt: Double

    public init(id: PlayerID, name: String, colour: PlayerColour, seatToken: String, connected: Bool = true,
                disconnectedAt: Double? = nil, isHost: Bool = false, waitingForNextGame: Bool = false, joinedAt: Double) {
        self.id = id; self.name = name; self.colour = colour; self.seatToken = seatToken; self.connected = connected
        self.disconnectedAt = disconnectedAt; self.isHost = isHost; self.waitingForNextGame = waitingForNextGame
        self.joinedAt = joinedAt
    }
}
