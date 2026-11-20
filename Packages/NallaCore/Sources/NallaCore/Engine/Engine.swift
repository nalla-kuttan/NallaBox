import Foundation

public enum HostAction: Equatable, Sendable {
    case pause, resume, skip, removePlayer(PlayerID), setFamilyFriendly(Bool), setVoice(Bool), setTimer(TimerSpeed), endSession
}

public enum Event: Equatable, Sendable {
    case join(ConnectionID, id: String, JoinRequest, newToken: String)
    case reserveHostSeat(name: String, colour: PlayerColour, token: String)
    case message(PlayerID, id: String, ClientMessage)
    case disconnected(PlayerID)
    case tick
    case host(HostAction)
}

public enum Effect: Equatable, Sendable {
    case reply(ConnectionID, ServerMessage)
    case bind(ConnectionID, PlayerID)
    case send(PlayerID, ServerMessage)
    /// Send `removed` to the player, then close their connection.
    case kick(PlayerID, RemovalReason)
    case speak(String)
    case closeRoom
}

public enum Engine {
    public static let maxPlayers = 8
    public static let howToSeconds = 15.0
    public static let leaderGrace = 30.0
    public static let toastSeconds = 4.0
    public static let helpAfter = 60.0

    public static func reduce(_ state: RoomState, _ event: Event, now: Double, content: ContentLibrary) -> (RoomState, [Effect]) {
        var r = Reducer(s: state, now: now, content: content)
        r.handle(event)
        r.settle()
        return (r.s, r.effects)
    }

    /// The next moment something changes on its own: a deadline, a leader handoff, a toast expiry, the T3 tip.
    public static func nextWake(_ s: RoomState) -> Double? {
        var times: [Double] = []
        if let l = s.leader, !l.connected, let at = l.disconnectedAt, Reducer.nextLeader(after: l, in: s) != nil {
            times.append(at + leaderGrace)
        }
        if let t = s.toast { times.append(t.until) }
        if s.phase == .lobby, s.players.isEmpty, !s.helpShown { times.append(s.openedAt + helpAfter) }
        if s.pause == nil {
            switch s.phase {
            case .howTo(_, let until): times.append(until)
            case .playing(let g): if let d = GameRunner.deadline(g.rules, g) { times.append(d) }
            default: break
            }
        }
        return times.min()
    }
}

struct Reducer {
    var s: RoomState
    let now: Double
    let content: ContentLibrary
    var effects: [Effect] = []

    // MARK: Events

    mutating func handle(_ e: Event) {
        switch e {
        case .join(let conn, let id, let req, let token): join(conn, id, req, token)
        case .reserveHostSeat(let name, let colour, let token):
            guard s.players.count < Engine.maxPlayers else { return }
            let p = Player(id: s.nextId, name: Names.normalize(name) ?? "Host", colour: colour, seatToken: token,
                           connected: false, isHost: true, joinedAt: now)
            s.nextId += 1
            s.players.append(p)
            if s.leaderId == nil { s.leaderId = p.id }
        case .message(let pid, let id, let m): message(pid, id, m)
        case .disconnected(let pid):
            if let i = index(pid) { s.players[i].connected = false; s.players[i].disconnectedAt = now }
        case .tick: break
        case .host(let a): host(a)
        }
    }

    private func index(_ id: PlayerID) -> Int? { s.players.firstIndex { $0.id == id } }

    private mutating func fail(_ conn: ConnectionID, _ id: String, _ code: ErrorCode, _ message: String) {
        effects.append(.reply(conn, .error(id: id, code: code, message: message, field: nil)))
    }

    private mutating func failTo(_ pid: PlayerID, _ id: String, _ code: ErrorCode, _ message: String, field: Int? = nil) {
        effects.append(.send(pid, .error(id: id, code: code, message: message, field: field)))
    }

    private mutating func ack(_ pid: PlayerID, _ id: String) { effects.append(.send(pid, .ack(id: id))) }

    private var gameInProgress: Bool {
        switch s.phase { case .howTo, .playing: true; default: false }
    }

    mutating func join(_ conn: ConnectionID, _ id: String, _ req: JoinRequest, _ token: String) {
        guard req.room.trimmingCharacters(in: .whitespaces).uppercased() == s.code else {
            return fail(conn, id, .wrongCode, "That room code doesn't match. Check the TV.")
        }
        if let t = req.seatToken, let i = s.players.firstIndex(where: { $0.seatToken == t }) {
            s.players[i].connected = true
            s.players[i].disconnectedAt = nil
            effects.append(.bind(conn, s.players[i].id))
            effects.append(.reply(conn, .welcome(playerId: s.players[i].id, seatToken: t)))
            return
        }
        guard let name = Names.normalize(req.name) else {
            return fail(conn, id, .nameInvalid, "Names need 1 to 12 characters.")
        }
        if s.settings.familyFriendly, content.profanity.contains(name) {
            return fail(conn, id, .nameInvalid, "Let's keep names friendly. Try another.")
        }
        guard s.players.count < Engine.maxPlayers else { return fail(conn, id, .roomFull, "This room is full (8 players).") }
        guard !s.players.contains(where: { Names.key($0.name) == Names.key(name) }) else {
            return fail(conn, id, .nameTaken, "Someone already has that name. Try another.")
        }
        guard !s.players.contains(where: { $0.colour == req.colour }) else {
            return fail(conn, id, .colourTaken, "That colour's taken. Pick another.")
        }
        let p = Player(id: s.nextId, name: name, colour: req.colour, seatToken: token, waitingForNextGame: gameInProgress, joinedAt: now)
        s.nextId += 1
        s.players.append(p)
        if s.leaderId == nil { s.leaderId = p.id }
        effects.append(.bind(conn, p.id))
        effects.append(.reply(conn, .welcome(playerId: p.id, seatToken: token)))
    }

    mutating func message(_ pid: PlayerID, _ id: String, _ m: ClientMessage) {
        guard let player = s.player(pid) else { return }
        switch m {
        case .leader(let a):
            guard s.leaderId == pid else { return failTo(pid, id, .notLeader, "Only the leader can do that.") }
            if let problem = leaderAction(a, by: pid) { failTo(pid, id, .notAllowed, problem) } else { ack(pid, id) }
        case .join:
            failTo(pid, id, .notAllowed, "You're already in the room.")
        case .ping:
            ack(pid, id)
        case .submitText, .strokeData, .castVote, .placeBet:
            guard case .playing(var session) = s.phase, s.pause == nil, !player.waitingForNextGame else { return ack(pid, id) }
            var ctx = context()
            let reply = GameRunner.handle(session.rules, &session, m, pid, &ctx)
            s.phase = .playing(session)
            absorb(ctx)
            switch reply {
            case .ok, .ignored: ack(pid, id)
            case .error(let code, let text, let field): failTo(pid, id, code, text, field: field)
            }
        }
    }

    // MARK: Leader and host actions

    /// Returns a reason when the action isn't allowed right now.
    mutating func leaderAction(_ a: LeaderAction, by pid: PlayerID) -> String? {
        let choosing: Bool = { switch s.phase { case .lobby, .picker, .settings: true; default: false } }()
        switch a {
        case .previewGame(let g):
            guard choosing, g.rules != nil else { return "You can't pick a game right now." }
            s.phase = .picker; s.preview = g
        case .pickGame(let g):
            guard choosing, let rules = g.rules else { return "You can't pick a game right now." }
            s.phase = .settings(g); s.preview = g
            s.settings.rounds = rules.rounds?.default
        case .setSettings(let patch):
            guard case .settings(let g) = s.phase, let rules = g.rules else { return "Settings can't change right now." }
            if let r = patch.rounds, let rule = rules.rounds { s.settings.rounds = min(max(r, rule.min), rule.max) }
            if let t = patch.timer { s.settings.timer = t }
            if let f = patch.familyFriendly { s.settings.familyFriendly = f }
            if let b = patch.bannedWords { s.settings.bannedWords = b }
        case .start:
            guard case .settings(let g) = s.phase, let rules = g.rules else { return "Pick a game first." }
            guard s.players.count >= rules.minPlayers else { return "\(rules.card.name) needs \(rules.minPlayers) players" }
            enterHowTo(g)
        case .pause:
            guard gameInProgress, s.pause == nil else { return "There's nothing to pause." }
            s.pause = Pause(by: s.player(pid)?.name ?? "the leader", byPlayer: pid, at: now)
        case .resume:
            guard s.pause != nil else { return "The game isn't paused." }
            resume()
        case .skip:
            guard gameInProgress else { return "There's nothing to skip." }
            skip()
        case .end:
            switch s.phase {
            case .playing(let g): finish(g)
            case .howTo(let g, _): s.phase = .settings(g); s.pause = nil
            default: return "There's no game to end."
            }
        case .removePlayer(let t):
            guard t != pid, let p = s.player(t), !p.isHost else { return "You can't remove that player." }
            remove(t, .byHost)
        case .passLeader(let t):
            guard t != pid, let p = s.player(t), p.connected else { return "You can't pass leadership to them." }
            setLeader(t)
        case .playAgain:
            guard case .results(let r) = s.phase else { return "Finish the game first." }
            enterHowTo(r.game)
        case .newGame:
            guard case .results(let r) = s.phase else { return "Finish the game first." }
            for i in s.players.indices { s.players[i].waitingForNextGame = false }
            s.phase = .picker; s.preview = r.game
        }
        return nil
    }

    mutating func host(_ a: HostAction) {
        switch a {
        case .pause:
            guard gameInProgress, s.pause == nil else { return }
            let me = s.players.first(where: \.isHost)
            s.pause = Pause(by: me?.name ?? "the host", byPlayer: me?.id, at: now)
        case .resume: if s.pause != nil { resume() }
        case .skip: if gameInProgress { skip() }
        case .removePlayer(let t): if let p = s.player(t), !p.isHost { remove(t, .byHost) }
        case .setFamilyFriendly(let on): s.settings.familyFriendly = on
        case .setVoice(let on): s.settings.voiceOn = on
        case .setTimer(let t): s.settings.timer = t
        case .endSession:
            if case .playing(let g) = s.phase { finish(g) }
            s.pause = nil
            for p in s.players { effects.append(.kick(p.id, .sessionEnded)) }
            effects.append(.closeRoom)
        }
    }

    mutating func enterHowTo(_ g: GameID) {
        for i in s.players.indices { s.players[i].waitingForNextGame = false }
        s.pause = nil
        s.phase = .howTo(g, until: now + Engine.howToSeconds)
    }

    mutating func resume() {
        guard let p = s.pause else { return }
        let d = now - p.at
        s.pause = nil
        switch s.phase {
        case .howTo(let g, let until): s.phase = .howTo(g, until: until + d)
        case .playing(var g):
            GameRunner.shift(g.rules, &g, by: d)
            s.phase = .playing(g)
        default: break
        }
    }

    mutating func skip() {
        switch s.phase {
        case .howTo(let g, _): startGame(g)
        case .playing(var g):
            guard s.pause == nil else { return }
            var ctx = context()
            GameRunner.advance(g.rules, &g, &ctx)
            s.phase = .playing(g)
            absorb(ctx)
        default: break
        }
    }

    mutating func startGame(_ g: GameID) {
        guard let rules = g.rules else { s.phase = .lobby; return }
        var ctx = context()
        let session = GameRunner.start(rules, &ctx)
        absorb(ctx)
        s.phase = .playing(session)
    }

    mutating func finish(_ g: GameSession) {
        guard let r = GameRunner.results(g.rules, g, context()) else { s.phase = .lobby; return }
        s.pause = nil
        s.phase = .results(r)
    }

    mutating func remove(_ t: PlayerID, _ reason: RemovalReason) {
        guard let p = s.player(t) else { return }
        let wasLeader = s.leaderId == t
        let successor = wasLeader ? Reducer.nextLeader(after: p, in: s) : nil
        s.players.removeAll { $0.id == t }
        effects.append(.kick(t, reason))
        if wasLeader {
            if let n = successor { setLeader(n.id) } else { s.leaderId = s.players.first?.id }
        }
    }

    mutating func setLeader(_ id: PlayerID) {
        s.leaderId = id
        if let p = s.player(id) { s.toast = Toast(text: "\(p.name) is now the leader", until: now + Engine.toastSeconds) }
    }

    /// The next connected player in join order after `p`, wrapping around.
    static func nextLeader(after p: Player, in s: RoomState) -> Player? {
        let order = s.players.sorted { ($0.joinedAt, $0.id) < ($1.joinedAt, $1.id) }
        let later = order.filter { ($0.joinedAt, $0.id) > (p.joinedAt, p.id) }
        let earlier = order.filter { ($0.joinedAt, $0.id) < (p.joinedAt, p.id) }
        return (later + earlier).first { $0.connected && $0.id != p.id }
    }

    // MARK: Time

    mutating func settle() {
        if let l = s.leader, !l.connected, let at = l.disconnectedAt, now >= at + Engine.leaderGrace,
           let n = Reducer.nextLeader(after: l, in: s) {
            setLeader(n.id)
        }
        if let t = s.toast, now >= t.until { s.toast = nil }
        if s.phase == .lobby, s.players.isEmpty, now >= s.openedAt + Engine.helpAfter { s.helpShown = true }
        guard s.pause == nil else { return }
        if case .howTo(let g, let until) = s.phase, now >= until { startGame(g) }
        for _ in 0..<64 {
            guard case .playing(var g) = s.phase else { return }
            let rules = g.rules
            if GameRunner.isOver(rules, g) { finish(g); return }
            let due = GameRunner.deadline(rules, g).map { now >= $0 } ?? false
            guard due || GameRunner.allInputsIn(rules, g, connectedInGame) else { return }
            var ctx = context()
            GameRunner.advance(rules, &g, &ctx)
            s.phase = .playing(g)
            absorb(ctx)
        }
    }

    private var connectedInGame: Set<PlayerID> {
        Set(s.players.filter { $0.connected && !$0.waitingForNextGame }.map(\.id))
    }

    func context() -> GameContext { Reducer.context(s, now: now, content: content) }

    static func context(_ s: RoomState, now: Double, content: ContentLibrary) -> GameContext {
        GameContext(players: s.players.filter { !$0.waitingForNextGame }, leaderId: s.leaderId, settings: s.settings,
                    now: now, rng: s.rng, content: content, used: s.used)
    }

    mutating func absorb(_ ctx: GameContext) {
        s.rng = ctx.rng
        s.used = ctx.used
        effects += ctx.speech.map(Effect.speak)
    }
}
