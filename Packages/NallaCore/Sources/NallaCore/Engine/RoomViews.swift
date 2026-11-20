import Foundation

// MARK: Room screen payloads (read by the controller as JSON and by the TV as these structs)

public struct LobbyData: Codable, Equatable, Sendable {           // T1/T2/T3, P3/P4
    public var code: String
    public var joinURL: String?
    public var players: [PlayerSummary]
    public var leaderName: String?
    public var seats: Int
    public var canStart: Bool
    public var startBlockedReason: String?
}

public struct PickerData: Codable, Equatable, Sendable {          // T4, P5
    public var games: [GameCard]
    public var preview: GameID?
    public var playerCount: Int
    public var leaderName: String?
}

public struct SettingsData: Codable, Equatable, Sendable {        // T5, P6
    public var game: GameCard
    public var rounds: Int?
    public var roundsLabel: String
    public var roundsRule: RoundsRule?
    public var timer: TimerSpeed
    public var familyFriendly: Bool
    public var bannedWords: Bool?
    public var canStart: Bool
    public var startBlockedReason: String?
    public var playerCount: Int
    public var leaderName: String?
}

public struct HowToData: Codable, Equatable, Sendable {           // T6
    public var game: GameCard
    public var steps: [HowToStep]
    public var leaderName: String?
}

public struct LateJoinData: Codable, Equatable, Sendable {        // P2 in-progress
    public var reason: String
    public var game: String
}

public struct WaitingData: Codable, Equatable, Sendable {         // P8, built by games
    public var top: String
    public var title: String
    public var detail: String?
    public var waitingOn: [PlayerSummary]
    public var canChange: Bool
    public init(top: String, title: String = "Done!", detail: String? = nil, waitingOn: [PlayerSummary], canChange: Bool = false) {
        self.top = top; self.title = title; self.detail = detail; self.waitingOn = waitingOn; self.canChange = canChange
    }
}

public struct PausedData: Codable, Equatable, Sendable {          // P10
    public var top: String
    public var by: String
    public var byYou: Bool
}

public struct ResultsData: Codable, Equatable, Sendable {         // T10
    public var game: GameCard
    public var podium: [Standing]
    public var awards: [Award]
    public var standings: [Standing]
    public var rounds: Int
}

public struct PhoneResultsData: Codable, Equatable, Sendable {    // P12
    public var gameName: String
    public var rank: Int
    public var points: Int
    public var line: String
    public var award: Award?
}

// MARK: Views

extension Engine {
    static func scores(_ s: RoomState) -> [PlayerID: Int] {
        switch s.phase {
        case .playing(let g): GameRunner.scores(g.rules, g)
        case .results(let r): Dictionary(uniqueKeysWithValues: r.standings.map { ($0.player.id, $0.points) })
        default: [:]
        }
    }

    static func currentGame(_ s: RoomState) -> GameID? {
        switch s.phase {
        case .lobby, .picker: nil
        case .settings(let g), .howTo(let g, _): g
        case .playing(let g): g.rules.game
        case .results(let r): r.game
        }
    }

    public static func roomInfo(_ s: RoomState) -> RoomInfo {
        let sc = scores(s)
        return RoomInfo(code: s.code, players: s.players.map { summary($0, s, sc) }, leaderId: s.leaderId,
                        game: currentGame(s), paused: s.pause.map { PauseInfo(by: $0.by) }, settings: s.settings)
    }

    public static func youInfo(_ s: RoomState, _ id: PlayerID) -> YouInfo? {
        guard let p = s.player(id) else { return nil }
        return YouInfo(id: p.id, name: p.name, colour: p.colour, isLeader: s.leaderId == id, isHost: p.isHost, score: scores(s)[id] ?? 0)
    }

    static func summary(_ p: Player, _ s: RoomState, _ sc: [PlayerID: Int]) -> PlayerSummary {
        PlayerSummary(id: p.id, name: p.name, colour: p.colour, connected: p.connected, isLeader: s.leaderId == p.id, score: sc[p.id] ?? 0)
    }

    static func lobbyData(_ s: RoomState) -> LobbyData {
        let enough = s.players.count >= 3
        return LobbyData(code: s.code, joinURL: s.joinURL, players: s.players.map { summary($0, s, [:]) }, leaderName: s.leader?.name,
                         seats: maxPlayers, canStart: enough, startBlockedReason: enough ? nil : "Need 3 players to start")
    }

    static func pickerData(_ s: RoomState) -> PickerData {
        PickerData(games: GameID.playable.compactMap { $0.rules?.card }, preview: s.preview,
                   playerCount: s.players.count, leaderName: s.leader?.name)
    }

    static func settingsData(_ s: RoomState, _ rules: any GameRules.Type) -> SettingsData {
        let ok = s.players.count >= rules.minPlayers
        return SettingsData(game: rules.card, rounds: s.settings.rounds, roundsLabel: rules.roundsLabel(s.settings.rounds),
                            roundsRule: rules.rounds, timer: s.settings.timer, familyFriendly: s.settings.familyFriendly,
                            bannedWords: rules.game == .sketch ? s.settings.bannedWords : nil, canStart: ok,
                            startBlockedReason: ok ? nil : "\(rules.card.name) needs \(rules.minPlayers) players",
                            playerCount: s.players.count, leaderName: s.leader?.name)
    }

    public static func playerView(_ s: RoomState, _ id: PlayerID, now: Double) -> ScreenView {
        guard let p = s.player(id) else { return ScreenView("P11") }
        let isLeader = s.leaderId == id
        let gameName = currentGame(s)?.rules?.card.name ?? "NallaBox"
        switch s.phase {
        case .howTo, .playing:
            if p.waitingForNextGame { return ScreenView("P2", payload: LateJoinData(reason: "in-progress", game: gameName)) }
            if let pause = s.pause {
                return ScreenView("P10", payload: PausedData(top: gameName, by: pause.by, byYou: pause.byPlayer == id && isLeader))
            }
        default: break
        }
        switch s.phase {
        case .lobby:
            return ScreenView(isLeader ? "P4" : "P3", payload: lobbyData(s))
        case .picker:
            return isLeader ? ScreenView("P5", payload: pickerData(s)) : ScreenView("P3", payload: lobbyData(s))
        case .settings(let g):
            guard isLeader, let rules = g.rules else { return ScreenView("P3", payload: lobbyData(s)) }
            return ScreenView("P6", payload: settingsData(s, rules))
        case .howTo(let g, let until):
            let job = g.rules?.job(for: id, players: s.players) ?? JobData(label: gameName, icon: "✓", job: "Get ready", detail: nil)
            return ScreenView("P7", deadline: until, payload: job)
        case .playing(let g):
            return GameRunner.playerView(g.rules, g, id, Reducer.context(s, now: now, content: .empty))
        case .results(let r):
            return ScreenView("P12", payload: phoneResults(r, id))
        }
    }

    static func phoneResults(_ r: GameResults, _ id: PlayerID) -> PhoneResultsData {
        let name = r.game.rules?.card.name ?? "NallaBox"
        guard let me = r.standings.first(where: { $0.player.id == id }) else {
            return PhoneResultsData(gameName: name, rank: 0, points: 0, line: "You joined after this game started", award: nil)
        }
        let top = r.standings.first!
        let line: String
        if me.rank == 1 {
            line = "\(signed(me.delta)) this round · winner"
        } else {
            line = "\(signed(me.delta)) this round · \(grouped(top.points - me.points)) behind \(top.player.name)"
        }
        var award = r.awards.first { $0.player.id == id }
        if award == nil, me.rank == 1 {
            award = Award(title: "Top score", player: me.player, note: "Highest total after \(r.rounds) rounds")
        }
        return PhoneResultsData(gameName: name, rank: me.rank, points: me.points, line: line, award: award)
    }

    public static func tvView(_ s: RoomState, now: Double) -> TVView {
        let (screen, face) = tvScreen(s, now: now)
        let reconnecting: [ReconnectBanner]
        switch s.phase {
        case .howTo, .playing:
            let sc = scores(s)
            reconnecting = s.players.filter { !$0.connected && !$0.waitingForNextGame }
                .compactMap { p in p.disconnectedAt.map { ReconnectBanner(player: summary(p, s, sc), since: $0) } }
        default: reconnecting = []
        }
        return TVView(screen: screen, face: s.pause == nil ? face : FaceCue(.sleepy), room: roomInfo(s),
                      overlays: TVOverlays(paused: s.pause.map { PauseInfo(by: $0.by) }, reconnecting: reconnecting, toast: s.toast?.text))
    }

    static let numberWords = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight"]

    static func tvScreen(_ s: RoomState, now: Double) -> (ScreenView, FaceCue) {
        let leader = s.leader?.name ?? "the leader"
        switch s.phase {
        case .lobby:
            let n = s.players.count
            if n == 0 {
                return s.helpShown
                    ? (ScreenView("T3", payload: lobbyData(s)), FaceCue(.suspicious, "Still nobody? Let's check the Wi-Fi."))
                    : (ScreenView("T1", payload: lobbyData(s)), FaceCue(.wink, "Scan to join."))
            }
            if n >= maxPlayers { return (ScreenView("T2", payload: lobbyData(s)), FaceCue(.grin, "Full house! Over to you, \(leader).")) }
            let free = numberWords[maxPlayers - n].lowercased()
            return (ScreenView("T2", payload: lobbyData(s)), FaceCue(.wink, "\(numberWords[n]) in. Room for \(free) more."))
        case .picker:
            return (ScreenView("T4", payload: pickerData(s)), FaceCue(.wink, "\(leader) is picking a game."))
        case .settings(let g):
            guard let rules = g.rules else { return (ScreenView("T4", payload: pickerData(s)), FaceCue(.idle)) }
            return (ScreenView("T5", payload: settingsData(s, rules)), FaceCue(.idle))
        case .howTo(let g, let until):
            let card = g.rules?.card ?? GameCard(id: g, name: "NallaBox", players: "", length: "", tagline: "", pitch: "", colour: .sky, icon: "", minPlayers: 3)
            return (ScreenView("T6", deadline: until, payload: HowToData(game: card, steps: g.rules?.howTo ?? [], leaderName: s.leader?.name)),
                    FaceCue(.wink, "Quick rules, then we go."))
        case .playing(let g):
            return GameRunner.tvView(g.rules, g, Reducer.context(s, now: now, content: .empty))
        case .results(let r):
            let card = r.game.rules?.card ?? GameCard(id: r.game, name: "NallaBox", players: "", length: "", tagline: "", pitch: "", colour: .sky, icon: "", minPlayers: 3)
            let data = ResultsData(game: card, podium: Array(r.standings.prefix(3)), awards: r.awards, standings: r.standings, rounds: r.rounds)
            let winners = r.standings.filter { $0.rank == 1 }
            let caption = winners.count == 1 ? "And the winner is \(winners[0].player.name)!" : "It's a tie at the top!"
            return (ScreenView("T10", payload: data), FaceCue(.celebrate, caption))
        }
    }
}
