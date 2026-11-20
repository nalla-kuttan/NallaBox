import Foundation

public struct Standing: Codable, Equatable, Sendable {
    public var player: PlayerSummary
    public var rank: Int
    public var points: Int
    public var delta: Int
}

public struct Award: Codable, Equatable, Sendable {
    public var title: String
    public var player: PlayerSummary
    public var note: String
    public init(title: String, player: PlayerSummary, note: String) { self.title = title; self.player = player; self.note = note }
}

public struct GameResults: Codable, Equatable, Sendable {
    public var game: GameID
    public var standings: [Standing]
    public var awards: [Award]
    public var rounds: Int
}

public enum Results {
    /// Highest points first, ties share a rank (1, 2, 2, 4) and keep join order.
    public static func standings(scores: [PlayerID: Int], deltas: [PlayerID: Int], players: [Player], leaderId: PlayerID?) -> [Standing] {
        func before(_ a: Player, _ b: Player) -> Bool {
            let sa = scores[a.id] ?? 0, sb = scores[b.id] ?? 0
            if sa != sb { return sa > sb }
            if a.joinedAt != b.joinedAt { return a.joinedAt < b.joinedAt }
            return a.id < b.id
        }
        let rows = players.filter { scores[$0.id] != nil }.sorted(by: before)
        var out: [Standing] = []
        for (i, p) in rows.enumerated() {
            let pts = scores[p.id]!
            let rank = (i > 0 && out[i - 1].points == pts) ? out[i - 1].rank : i + 1
            out.append(Standing(player: PlayerSummary(id: p.id, name: p.name, colour: p.colour, connected: p.connected,
                                                      isLeader: p.id == leaderId, score: pts),
                                rank: rank, points: pts, delta: deltas[p.id] ?? 0))
        }
        return out
    }

    public static func make(game: GameID, scores: [PlayerID: Int], deltas: [PlayerID: Int], ctx: GameContext,
                            awards: [Award], rounds: Int) -> GameResults {
        GameResults(game: game, standings: standings(scores: scores, deltas: deltas, players: ctx.players, leaderId: ctx.leaderId),
                    awards: awards, rounds: rounds)
    }

    /// The player with the highest positive count wins the award (ties: earliest joiner).
    public static func award(_ title: String, counts: [PlayerID: Int], ctx: GameContext, note: (Int) -> String) -> Award? {
        var best: Player?
        var bestCount = 0
        for p in ctx.players {
            let n = counts[p.id] ?? 0
            if n > bestCount { best = p; bestCount = n }
        }
        guard let p = best, let s = ctx.summary(p.id) else { return nil }
        return Award(title: title, player: s, note: note(bestCount))
    }
}

/// "1,500" without depending on the device locale.
public func grouped(_ n: Int) -> String {
    let digits = String(abs(n))
    var out = ""
    for (i, c) in digits.reversed().enumerated() {
        if i > 0 && i % 3 == 0 { out.append(",") }
        out.append(c)
    }
    return (n < 0 ? "−" : "") + String(out.reversed())
}

/// "+1,000" / "−300" / "+0".
public func signed(_ n: Int) -> String { n < 0 ? grouped(n) : "+" + grouped(n) }
