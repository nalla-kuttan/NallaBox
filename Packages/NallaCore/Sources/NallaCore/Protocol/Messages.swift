import Foundation

// MARK: Phone → host

public struct JoinRequest: Equatable, Sendable {
    public var room: String
    public var name: String
    public var colour: PlayerColour
    public var seatToken: String?
    public init(room: String, name: String, colour: PlayerColour, seatToken: String? = nil) {
        self.room = room; self.name = name; self.colour = colour; self.seatToken = seatToken
    }
}

/// One drawing stroke: colour index 0–5, size index 0–2, flat x,y pairs normalised to 0…1 on the square canvas.
public struct Stroke: Codable, Equatable, Sendable {
    public var c: Int
    public var s: Int
    public var p: [Double]
    public init(c: Int, s: Int, p: [Double]) { self.c = c; self.s = s; self.p = p }
    public var pointCount: Int { p.count / 2 }
}

public struct SettingsPatch: Codable, Equatable, Sendable {
    public var rounds: Int?
    public var timer: TimerSpeed?
    public var familyFriendly: Bool?
    public var bannedWords: Bool?
    public init(rounds: Int? = nil, timer: TimerSpeed? = nil, familyFriendly: Bool? = nil, bannedWords: Bool? = nil) {
        self.rounds = rounds; self.timer = timer; self.familyFriendly = familyFriendly; self.bannedWords = bannedWords
    }
}

public enum LeaderAction: Equatable, Sendable {
    case pickGame(GameID), previewGame(GameID), setSettings(SettingsPatch), start, pause, resume, skip, end
    case removePlayer(PlayerID), passLeader(PlayerID), playAgain, newGame
}

public enum ClientMessage: Equatable, Sendable {
    case join(JoinRequest)
    case submitText(round: Int, fields: [String])
    case strokeData(round: Int, strokes: [Stroke], final: Bool)
    case castVote(round: Int, choice: Int)
    case placeBet(round: Int, choice: Int, chips: Int)
    case leader(LeaderAction)
    case ping(t: Double)
}

public struct DecodedMessage: Equatable, Sendable {
    public var id: String
    public var message: ClientMessage
    public init(id: String, message: ClientMessage) { self.id = id; self.message = message }
}

// MARK: Host → phone

public enum ErrorCode: String, Codable, Sendable {
    case badMessage = "bad_message", wrongVersion = "wrong_version", notJoined = "not_joined", wrongCode = "wrong_code"
    case roomFull = "room_full", nameTaken = "name_taken", nameInvalid = "name_invalid", colourTaken = "colour_taken"
    case rateLimited = "rate_limited", notLeader = "not_leader", notAllowed = "not_allowed", tooClose = "too_close"
    case empty, tooLong = "too_long", invalid
}

public enum RemovalReason: String, Codable, Sendable {
    case byHost = "by_host", sessionEnded = "session_ended", replaced
}

public enum ServerMessage: Equatable, Sendable {
    case welcome(playerId: PlayerID, seatToken: String)
    case view(PlayerView)
    case ack(id: String)
    case error(id: String?, code: ErrorCode, message: String, field: Int?)
    case pong(t: Double, hostTime: Double)
    case removed(RemovalReason)
}

public struct WireError: Error, Equatable, Sendable {
    public var id: String?
    public var code: ErrorCode
    public var message: String
    public init(id: String?, code: ErrorCode, message: String) { self.id = id; self.code = code; self.message = message }
}

// MARK: Coding

/// JSON wire format, protocol version 1. Every message carries `v` and `type`; client messages carry `id`,
/// and the host echoes it in `ack`/`error`. Protocol keys are snake_case; view payloads are camelCase.
public enum Wire {
    static let badMessage = "That message didn't make sense."

    public static func decodeClient(_ text: String) -> Result<DecodedMessage, WireError> {
        guard let root = JSONValue.parse(text), let obj = root.object else {
            return .failure(WireError(id: nil, code: .badMessage, message: badMessage))
        }
        let id = obj["id"]?.string
        let bad = WireError(id: id, code: .badMessage, message: badMessage)
        guard let v = obj["v"]?.int else { return .failure(bad) }
        guard v == nallaProtocolVersion else {
            return .failure(WireError(id: id, code: .wrongVersion, message: "This page is out of date. Reload to keep playing."))
        }
        guard let id, let type = obj["type"]?.string else { return .failure(bad) }
        guard let message = clientMessage(type, obj) else { return .failure(bad) }
        return .success(DecodedMessage(id: id, message: message))
    }

    private static func clientMessage(_ type: String, _ o: [String: JSONValue]) -> ClientMessage? {
        switch type {
        case "join":
            guard let room = o["room"]?.string, let name = o["name"]?.string,
                  let colour = o["colour"]?.string.flatMap(PlayerColour.init(rawValue:)) else { return nil }
            return .join(JoinRequest(room: room, name: name, colour: colour, seatToken: o["seat_token"]?.string))
        case "submit_text":
            guard let round = o["round"]?.int, let fields = o["fields"]?.array else { return nil }
            let strings = fields.compactMap(\.string)
            guard strings.count == fields.count else { return nil }
            return .submitText(round: round, fields: strings)
        case "stroke_data":
            guard let round = o["round"]?.int, let raw = o["strokes"],
                  let strokes = try? raw.decode([Stroke].self) else { return nil }
            return .strokeData(round: round, strokes: strokes, final: o["final"]?.bool ?? false)
        case "cast_vote":
            guard let round = o["round"]?.int, let choice = o["choice"]?.int else { return nil }
            return .castVote(round: round, choice: choice)
        case "place_bet":
            guard let round = o["round"]?.int, let choice = o["choice"]?.int, let chips = o["chips"]?.int else { return nil }
            return .placeBet(round: round, choice: choice, chips: chips)
        case "leader":
            guard let action = o["action"]?.string, let a = leaderAction(action, o["args"]?.object ?? [:]) else { return nil }
            return .leader(a)
        case "ping":
            guard let t = o["t"]?.double else { return nil }
            return .ping(t: t)
        default:
            return nil
        }
    }

    private static func leaderAction(_ action: String, _ args: [String: JSONValue]) -> LeaderAction? {
        let game = args["game"]?.string.flatMap(GameID.init(rawValue:))
        let player = args["player"]?.int
        switch action {
        case "pick_game": return game.map(LeaderAction.pickGame)
        case "preview_game": return game.map(LeaderAction.previewGame)
        case "set_settings":
            var p = SettingsPatch()
            p.rounds = args["rounds"]?.int
            if let t = args["timer"]?.string { guard let speed = TimerSpeed(rawValue: t) else { return nil }; p.timer = speed }
            p.familyFriendly = args["family_friendly"]?.bool
            p.bannedWords = args["banned_words"]?.bool
            return .setSettings(p)
        case "start": return .start
        case "pause": return .pause
        case "resume": return .resume
        case "skip": return .skip
        case "end": return .end
        case "remove_player": return player.map(LeaderAction.removePlayer)
        case "pass_leader": return player.map(LeaderAction.passLeader)
        case "play_again": return .playAgain
        case "new_game": return .newGame
        default: return nil
        }
    }

    public static func encode(_ message: ServerMessage) -> String {
        var o: [String: JSONValue] = ["v": .number(Double(nallaProtocolVersion))]
        switch message {
        case .welcome(let pid, let token):
            o["type"] = .string("welcome"); o["player_id"] = .number(Double(pid)); o["seat_token"] = .string(token)
        case .view(let view):
            if case .object(let fields) = JSONValue.encode(view) { o.merge(fields) { a, _ in a } }
            o["type"] = .string("view")
        case .ack(let id):
            o["type"] = .string("ack"); o["id"] = .string(id)
        case .error(let id, let code, let text, let field):
            o["type"] = .string("error"); o["code"] = .string(code.rawValue); o["message"] = .string(text)
            if let id { o["id"] = .string(id) }
            if let field { o["field"] = .number(Double(field)) }
        case .pong(let t, let hostTime):
            o["type"] = .string("pong"); o["t"] = .number(t); o["host_time"] = .number(hostTime)
        case .removed(let reason):
            o["type"] = .string("removed"); o["reason"] = .string(reason.rawValue)
        }
        return JSONValue.object(o).jsonText
    }

    /// Decodes a host message (used by test clients and tools).
    public static func decodeServer(_ text: String) -> ServerMessage? {
        guard let root = JSONValue.parse(text), let o = root.object, let type = o["type"]?.string else { return nil }
        switch type {
        case "welcome":
            guard let pid = o["player_id"]?.int, let token = o["seat_token"]?.string else { return nil }
            return .welcome(playerId: pid, seatToken: token)
        case "view":
            var fields = o
            fields["v"] = nil; fields["type"] = nil
            return (try? JSONValue.object(fields).decode(PlayerView.self)).map(ServerMessage.view)
        case "ack":
            return o["id"]?.string.map { .ack(id: $0) }
        case "error":
            guard let code = o["code"]?.string.flatMap(ErrorCode.init(rawValue:)), let text = o["message"]?.string else { return nil }
            return .error(id: o["id"]?.string, code: code, message: text, field: o["field"]?.int)
        case "pong":
            guard let t = o["t"]?.double, let h = o["host_time"]?.double else { return nil }
            return .pong(t: t, hostTime: h)
        case "removed":
            return o["reason"]?.string.flatMap(RemovalReason.init(rawValue:)).map(ServerMessage.removed)
        default:
            return nil
        }
    }
}
