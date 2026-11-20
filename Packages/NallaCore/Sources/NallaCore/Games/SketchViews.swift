import Foundation

// Screen payloads for Composite Sketch (C1–C6).

public struct SceneCard: Codable, Equatable, Sendable { public var caption: String; public var art: String; public var image: String? }
public struct DrawingTile: Codable, Equatable, Sendable { public var number: Int; public var strokes: [Stroke]; public var mine: Bool }

public struct C1TV: Codable, Equatable, Sendable { public var top: String; public var witness: PlayerSummary; public var bannedOn: Bool }
public struct C1WitnessPhone: Codable, Equatable, Sendable { public var top: String; public var scene: SceneCard; public var banned: [String]?; public var hint: String }
public struct C1ArtistPhone: Codable, Equatable, Sendable { public var top: String; public var witnessName: String }
public struct C2TV: Codable, Equatable, Sendable { public var top: String; public var witness: PlayerSummary; public var artists: [PlayerSummary]; public var done: [PlayerID] }
public struct C2ArtistPhone: Codable, Equatable, Sendable {
    public var top: String; public var round: Int; public var witnessName: String; public var done: Bool; public var waitingOn: [PlayerSummary]
}
public struct C3TV: Codable, Equatable, Sendable { public var top: String; public var witness: PlayerSummary; public var drawings: [DrawingTile] }
public struct C3WitnessPhone: Codable, Equatable, Sendable { public var top: String; public var round: Int; public var drawings: [DrawingTile]; public var pick: Int? }
public struct C3ArtistPhone: Codable, Equatable, Sendable { public var top: String; public var witnessName: String; public var number: Int?; public var strokes: [Stroke]? }
public struct PickedDrawing: Codable, Equatable, Sendable { public var number: Int; public var strokes: [Stroke]; public var artist: PlayerSummary }
public struct C4TV: Codable, Equatable, Sendable {
    public var top: String; public var witness: PlayerSummary; public var scene: SceneCard; public var picked: PickedDrawing?
    public var artistPoints: Int; public var witnessPoints: Int
}
public struct C4Phone: Codable, Equatable, Sendable {
    public var top: String; public var role: String; public var witnessName: String; public var picked: PickedDrawing?
    public var yours: Bool; public var points: Int
}
public struct C5TV: Codable, Equatable, Sendable { public var top: String; public var drawings: [DrawingTile]; public var voted: Int; public var players: Int }
public struct C5Phone: Codable, Equatable, Sendable { public var top: String; public var round: Int; public var drawings: [DrawingTile]; public var vote: Int? }
public struct C6TV: Codable, Equatable, Sendable { public var top: String; public var standings: [Standing]; public var worst: PickedDrawing? }
public struct C6Phone: Codable, Equatable, Sendable {
    public var top: String; public var label: String; public var rank: Int; public var points: Int; public var line: String; public var nextWitness: String?
}

extension Sketch {
    static func top(_ st: State) -> String { "Composite Sketch · Round \(st.round) of \(st.order.count)" }

    static func card(_ s: Scene) -> SceneCard { SceneCard(caption: s.caption, art: s.art, image: s.image) }

    static func tiles(_ st: State, for id: PlayerID? = nil) -> [DrawingTile] {
        st.drawings.map { DrawingTile(number: $0.number, strokes: $0.strokes, mine: $0.artist == id) }
    }

    static func picked(_ st: State, _ number: Int?, _ ctx: GameContext) -> PickedDrawing? {
        guard let number, let d = st.drawings.first(where: { $0.number == number }), let a = ctx.summary(d.artist, scores: st.scores) else { return nil }
        return PickedDrawing(number: d.number, strokes: d.strokes, artist: a)
    }

    /// The drawing with the most worst-likeness votes this round (ties: lowest number).
    static func worst(_ st: State) -> Int? {
        var counts: [Int: Int] = [:]
        for n in st.worstVotes.values { counts[n, default: 0] += 1 }
        return counts.max { ($0.value, -$0.key) < ($1.value, -$1.key) }?.key
    }

    static func standings(_ st: State, _ ctx: GameContext) -> [Standing] {
        Results.standings(scores: st.scores, deltas: st.deltas, players: ctx.players.filter { st.players.contains($0.id) }, leaderId: ctx.leaderId)
    }

    public static func playerView(_ st: State, for id: PlayerID, _ ctx: GameContext) -> ScreenView {
        let t = top(st)
        let isWitness = id == st.witness
        let wName = ctx.name(st.witness)
        let banned = ctx.settings.bannedWords && !st.scene.banned.isEmpty ? st.scene.banned : nil
        switch st.phase {
        case .brief:
            return isWitness
                ? ScreenView("C1-witness", deadline: st.deadline, payload: C1WitnessPhone(top: t, scene: card(st.scene), banned: banned,
                    hint: "You'll describe it out loud for 30 seconds. Keep your screen to yourself."))
                : ScreenView("C1-artist", deadline: st.deadline, payload: C1ArtistPhone(top: t, witnessName: wName))
        case .draw:
            if isWitness {
                return ScreenView("C2-witness", deadline: st.deadline, payload: C1WitnessPhone(top: t, scene: card(st.scene), banned: banned,
                    hint: "Hold to peek again any time."))
            }
            let waiting = st.artists.filter { !st.finals.contains($0) && $0 != id }.compactMap { ctx.summary($0) }
            return ScreenView("C2-artist", deadline: st.deadline, payload: C2ArtistPhone(
                top: t, round: st.round, witnessName: wName, done: st.finals.contains(id), waitingOn: waiting))
        case .pick:
            if isWitness {
                return ScreenView("C3-witness", deadline: st.deadline, payload: C3WitnessPhone(top: t, round: st.round, drawings: tiles(st), pick: st.pick))
            }
            let mine = st.drawings.first { $0.artist == id }
            return ScreenView("C3-artist", deadline: st.deadline, payload: C3ArtistPhone(top: t, witnessName: wName, number: mine?.number, strokes: mine?.strokes))
        case .reveal:
            let p = picked(st, st.pick, ctx)
            return ScreenView("C4", deadline: st.deadline, payload: C4Phone(
                top: t, role: isWitness ? "witness" : "artist", witnessName: wName, picked: p,
                yours: p?.artist.id == id, points: st.deltas[id] ?? 0))
        case .mostWanted:
            return ScreenView("C5", deadline: st.deadline, payload: C5Phone(top: t, round: st.round, drawings: tiles(st, for: id), vote: st.worstVotes[id]))
        case .scores:
            let s = standingLine(standings(st, ctx), id)
            let next = st.round < st.order.count ? ctx.name(st.order[st.round]) : nil
            return ScreenView("C6", deadline: st.deadline, payload: C6Phone(
                top: t, label: st.round < st.order.count ? "After round \(st.round)" : "Final scores", rank: s.rank, points: s.points, line: s.line, nextWitness: next))
        }
    }

    public static func tvView(_ st: State, _ ctx: GameContext) -> (ScreenView, FaceCue) {
        let t = top(st)
        let w = ctx.summary(st.witness, scores: st.scores) ?? PlayerSummary(id: st.witness, name: "Witness", colour: .sky, connected: true, isLeader: false, score: 0)
        switch st.phase {
        case .brief:
            return (ScreenView("C1", deadline: st.deadline, payload: C1TV(top: t, witness: w, bannedOn: ctx.settings.bannedWords)),
                    FaceCue(.gasp, caption("\(w.name) saw something. Listen closely.")))
        case .draw:
            return (ScreenView("C2", deadline: st.deadline, payload: C2TV(top: t, witness: w, artists: st.artists.compactMap { ctx.summary($0) },
                                                                          done: Array(st.finals).sorted())),
                    FaceCue(.suspicious, "Artists: eyes on your own phone."))
        case .pick:
            return (ScreenView("C3", deadline: st.deadline, payload: C3TV(top: t, witness: w, drawings: tiles(st))),
                    FaceCue(.suspicious, caption("\(w.name), which one did you see?")))
        case .reveal:
            let p = picked(st, st.pick, ctx)
            let face = p.map { FaceCue(.gasp, caption("Nailed it, \($0.artist.name).")) } ?? FaceCue(.idle, st.drawings.isEmpty ? "Nobody drew anything!" : "No pick this time.")
            return (ScreenView("C4", deadline: st.deadline, payload: C4TV(top: t, witness: w, scene: card(st.scene), picked: p,
                                                                          artistPoints: p == nil ? 0 : 1000, witnessPoints: p == nil ? 0 : 500)), face)
        case .mostWanted:
            return (ScreenView("C5", deadline: st.deadline, payload: C5TV(top: t, drawings: tiles(st), voted: st.worstVotes.count, players: st.players.count)),
                    FaceCue(.grin, "Now vote for the worst likeness."))
        case .scores:
            let worst = picked(st, worst(st), ctx)
            let face = worst.map { FaceCue(.grin, caption("Most Wanted goes to \($0.artist.name)'s drawing.")) } ?? FaceCue(.idle, "Round \(st.round) done.")
            return (ScreenView("C6", deadline: st.deadline, payload: C6TV(top: t, standings: standings(st, ctx), worst: worst)), face)
        }
    }
}
