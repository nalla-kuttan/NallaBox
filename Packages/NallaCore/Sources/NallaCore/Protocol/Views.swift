import Foundation

public enum FaceState: String, Codable, CaseIterable, Sendable {
    case idle, blink, wink, grin, gasp, suspicious, sleepy, celebrate
}

/// What the host face shows on the TV: an expression and an optional one-line caption (≤ 48 characters).
public struct FaceCue: Codable, Equatable, Sendable {
    public var state: FaceState
    public var caption: String?
    public init(_ state: FaceState, _ caption: String? = nil) { self.state = state; self.caption = caption }
}

/// One screen: `screen` is the mockup page id ("P4", "C2-witness", "T2"), `data` its payload.
public struct ScreenView: Codable, Equatable, Sendable {
    public var screen: String
    public var deadline: Double?
    public var data: JSONValue
    public init(_ screen: String, deadline: Double? = nil, data: JSONValue = .object([:])) {
        self.screen = screen; self.deadline = deadline; self.data = data
    }
    public init<T: Encodable>(_ screen: String, deadline: Double? = nil, payload: T) {
        self.init(screen, deadline: deadline, data: JSONValue.encode(payload))
    }
}

public struct PlayerSummary: Codable, Equatable, Sendable {
    public var id: PlayerID
    public var name: String
    public var colour: PlayerColour
    public var connected: Bool
    public var isLeader: Bool
    public var score: Int
    public init(id: PlayerID, name: String, colour: PlayerColour, connected: Bool, isLeader: Bool, score: Int) {
        self.id = id; self.name = name; self.colour = colour; self.connected = connected; self.isLeader = isLeader; self.score = score
    }
}

public struct PauseInfo: Codable, Equatable, Sendable {
    public var by: String
    public init(by: String) { self.by = by }
}

public struct RoomInfo: Codable, Equatable, Sendable {
    public var code: String
    public var players: [PlayerSummary]
    public var leaderId: PlayerID?
    public var game: GameID?
    public var paused: PauseInfo?
    public var settings: RoomSettings
    public init(code: String, players: [PlayerSummary], leaderId: PlayerID?, game: GameID?, paused: PauseInfo?, settings: RoomSettings) {
        self.code = code; self.players = players; self.leaderId = leaderId; self.game = game; self.paused = paused; self.settings = settings
    }
}

public struct YouInfo: Codable, Equatable, Sendable {
    public var id: PlayerID
    public var name: String
    public var colour: PlayerColour
    public var isLeader: Bool
    public var isHost: Bool
    public var score: Int
    public init(id: PlayerID, name: String, colour: PlayerColour, isLeader: Bool, isHost: Bool, score: Int) {
        self.id = id; self.name = name; self.colour = colour; self.isLeader = isLeader; self.isHost = isHost; self.score = score
    }
}

/// Everything one phone needs to draw its current screen.
public struct PlayerView: Codable, Equatable, Sendable {
    public var version: Int
    public var screen: String
    public var deadline: Double?
    public var you: YouInfo
    public var room: RoomInfo
    public var data: JSONValue
    public init(version: Int, screen: String, deadline: Double?, you: YouInfo, room: RoomInfo, data: JSONValue) {
        self.version = version; self.screen = screen; self.deadline = deadline; self.you = you; self.room = room; self.data = data
    }
}

public struct ReconnectBanner: Codable, Equatable, Sendable {
    public var player: PlayerSummary
    public var since: Double
    public init(player: PlayerSummary, since: Double) { self.player = player; self.since = since }
}

public struct TVOverlays: Codable, Equatable, Sendable {
    public var paused: PauseInfo?
    public var reconnecting: [ReconnectBanner]
    public var toast: String?
    public init(paused: PauseInfo? = nil, reconnecting: [ReconnectBanner] = [], toast: String? = nil) {
        self.paused = paused; self.reconnecting = reconnecting; self.toast = toast
    }
}

/// Everything the TV needs: the screen, the face, the room and the overlays (T7 pause, T8 banners, T9 toast).
public struct TVView: Codable, Equatable, Sendable {
    public var screen: ScreenView
    public var face: FaceCue
    public var room: RoomInfo
    public var overlays: TVOverlays
    public init(screen: ScreenView, face: FaceCue, room: RoomInfo, overlays: TVOverlays) {
        self.screen = screen; self.face = face; self.room = room; self.overlays = overlays
    }
}
