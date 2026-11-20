import Foundation

// Screen payloads for Redacted (R1–R5). TV structs end in TV, phone structs in Phone.

public struct VersionTile: Codable, Equatable, Sendable {
    public var number: Int
    public var fills: [String]
    public var mine: Bool
}

public struct RevealTile: Codable, Equatable, Sendable {
    public var number: Int
    public var fills: [String]
    public var real: Bool
    public var authors: [PlayerSummary]
    public var voters: [PlayerSummary]
}

public struct R1TV: Codable, Equatable, Sendable { public var top: String; public var passage: [Segment]; public var players: [PlayerSummary]; public var submitted: [PlayerID] }
public struct R1Phone: Codable, Equatable, Sendable {
    public var top: String; public var round: Int; public var passage: [Segment]; public var blanks: Int
    public var submitted: Bool; public var fields: [String]?; public var waitingOn: [PlayerSummary]
}
public struct R2TV: Codable, Equatable, Sendable { public var top: String; public var passage: [Segment]; public var fills: [String]; public var index: Int; public var count: Int }
public struct R2Phone: Codable, Equatable, Sendable { public var top: String; public var index: Int; public var count: Int }
public struct R3TV: Codable, Equatable, Sendable { public var top: String; public var versions: [VersionTile]; public var voted: Int; public var players: Int }
public struct R3Phone: Codable, Equatable, Sendable { public var top: String; public var round: Int; public var versions: [VersionTile]; public var vote: Int? }
public struct R4TV: Codable, Equatable, Sendable { public var top: String; public var real: [String]; public var versions: [RevealTile] }
public struct MyFake: Codable, Equatable, Sendable { public var fills: [String]; public var fooled: [String] }
public struct MyVote: Codable, Equatable, Sendable { public var fills: [String]; public var real: Bool; public var authors: [String] }
public struct R4Phone: Codable, Equatable, Sendable { public var top: String; public var myFake: MyFake?; public var myVote: MyVote?; public var points: Int }
public struct R5TV: Codable, Equatable, Sendable { public var top: String; public var standings: [Standing] }
public struct R5Phone: Codable, Equatable, Sendable {
    public var top: String; public var label: String; public var rank: Int; public var points: Int; public var line: String
}

/// One-line face caption, cut to 48 characters.
func caption(_ s: String) -> String { s.count <= 48 ? s : String(s.prefix(47)) + "…" }

let numberWords = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]
func word(_ n: Int) -> String { n < numberWords.count ? numberWords[n] : String(n) }

/// "+500 this round · 300 behind Aiko" / "+1,500 this round · in the lead" for the player's place in `standings`.
func standingLine(_ standings: [Standing], _ id: PlayerID) -> (rank: Int, points: Int, line: String) {
    guard let i = standings.firstIndex(where: { $0.player.id == id }) else { return (0, 0, "") }
    let me = standings[i]
    let ahead = standings[..<i].last { $0.points > me.points }
    let tail = ahead.map { "\(grouped($0.points - me.points)) behind \($0.player.name)" } ?? "in the lead"
    return (me.rank, me.points, "\(signed(me.delta)) this round · \(tail)")
}

extension Redacted {
    static func base(_ st: State) -> String { st.isFinal ? "Final round · points ×3" : "Round \(st.round) of \(st.totalRounds)" }

    static func summaries(_ ids: [PlayerID], _ st: State, _ ctx: GameContext) -> [PlayerSummary] {
        ids.compactMap { ctx.summary($0, scores: st.scores) }
    }

    static func standings(_ st: State, _ ctx: GameContext) -> [Standing] {
        Results.standings(scores: st.scores, deltas: st.deltas, players: ctx.players.filter { st.players.contains($0.id) }, leaderId: ctx.leaderId)
    }

    public static func playerView(_ st: State, for id: PlayerID, _ ctx: GameContext) -> ScreenView {
        let top = "Redacted · " + base(st)
        switch st.phase {
        case .write:
            let waiting = summaries(st.players.filter { st.submissions[$0] == nil && id != $0 }, st, ctx)
            return ScreenView("R1", deadline: st.deadline, payload: R1Phone(
                top: top, round: st.round, passage: PassageText.segments(st.passage.text), blanks: st.passage.answers.count,
                submitted: st.submissions[id] != nil, fields: st.submissions[id], waitingOn: waiting))
        case .readout(let i):
            return ScreenView("R2", deadline: st.deadline, payload: R2Phone(top: top, index: i + 1, count: st.versions.count))
        case .vote:
            let tiles = st.versions.map { VersionTile(number: $0.number, fills: $0.fills, mine: $0.authors.contains(id)) }
            return ScreenView("R3", deadline: st.deadline, payload: R3Phone(top: top, round: st.round, versions: tiles, vote: st.votes[id]))
        case .reveal:
            let fake = st.versions.first { $0.authors.contains(id) }.map { v in
                MyFake(fills: v.fills, fooled: st.votes.filter { $0.value == v.number }.keys.sorted().map(ctx.name))
            }
            let vote = st.votes[id].flatMap { n in st.versions.first { $0.number == n } }.map {
                MyVote(fills: $0.fills, real: $0.real, authors: $0.authors.map(ctx.name))
            }
            return ScreenView("R4", deadline: st.deadline, payload: R4Phone(top: top, myFake: fake, myVote: vote, points: st.deltas[id] ?? 0))
        case .scores:
            let s = standingLine(standings(st, ctx), id)
            return ScreenView("R5", deadline: st.deadline, payload: R5Phone(
                top: top, label: st.isFinal ? "Final scores" : "After round \(st.round)", rank: s.rank, points: s.points, line: s.line))
        }
    }

    public static func tvView(_ st: State, _ ctx: GameContext) -> (ScreenView, FaceCue) {
        let b = base(st)
        let segments = PassageText.segments(st.passage.text)
        switch st.phase {
        case .write:
            let n = st.passage.answers.count
            let face = FaceCue(.wink, n == 1 ? "One blank. Make it believable." : "\(word(n)) blanks. Make them believable.")
            return (ScreenView("R1", deadline: st.deadline, payload: R1TV(
                top: "\(b) · Write", passage: segments, players: summaries(st.players, st, ctx), submitted: Array(st.submissions.keys).sorted())), face)
        case .readout(let i):
            let v = st.versions[i]
            return (ScreenView("R2", deadline: st.deadline, payload: R2TV(
                top: "\(b) · Read-out", passage: segments, fills: v.fills, index: i + 1, count: st.versions.count)),
                    FaceCue(.idle, caption("Version \(i + 1): \(v.fills.joined(separator: ", ")).")))
        case .vote:
            let fakes = st.versions.count - 1
            let tiles = st.versions.map { VersionTile(number: $0.number, fills: $0.fills, mine: false) }
            return (ScreenView("R3", deadline: st.deadline, payload: R3TV(top: "\(b) · Vote", versions: tiles, voted: st.votes.count, players: st.players.count)),
                    FaceCue(.suspicious, fakes == 0 ? "Only one version. Easy points!" : fakes == 1 ? "One of these is a lie." : "\(word(fakes)) of these are lies."))
        case .reveal:
            let tiles = st.versions.map { v in
                RevealTile(number: v.number, fills: v.fills, real: v.real, authors: summaries(v.authors, st, ctx),
                           voters: summaries(st.votes.filter { $0.value == v.number }.keys.sorted(), st, ctx))
            }
            let realNumber = st.versions.first(where: \.real)?.number
            let found = st.votes.values.filter { $0 == realNumber }.count
            let face = found * 2 >= max(1, st.votes.count) ? FaceCue(.grin, "Most of you spotted it.") : FaceCue(.gasp, "That one was real?!")
            return (ScreenView("R4", deadline: st.deadline, payload: R4TV(top: "\(b) · Reveal", real: st.passage.answers, versions: tiles)), face)
        case .scores:
            var fooled: [PlayerID: Int] = [:]
            for v in st.versions where !v.real {
                let n = st.votes.values.filter { $0 == v.number }.count
                for a in v.authors { fooled[a, default: 0] += n }
            }
            let best = fooled.filter { $0.value > 0 }.max { ($0.value, -$0.key) < ($1.value, -$1.key) }
            let face = best.map { FaceCue(.grin, caption("\(ctx.name($0.key)) fooled \(word($0.value).lowercased()) of you.")) }
                ?? FaceCue(.idle, "Nobody fooled anybody. Honest bunch.")
            return (ScreenView("R5", deadline: st.deadline, payload: R5TV(top: "\(b) · Scores", standings: standings(st, ctx))), face)
        }
    }
}
