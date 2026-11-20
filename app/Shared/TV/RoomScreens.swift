import SwiftUI
import NallaCore

// TV room screens T1–T10, ported from design/mockups/_build/pages_tv.py.

/// QR + room code + URL column used by the lobby screens.
struct JoinColumn: View {
    var code: String
    var joinURL: String?
    var qr: CGImage?
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Group {
                if let qr {
                    Image(decorative: qr, scale: 1).interpolation(.none).resizable().aspectRatio(1, contentMode: .fit)
                } else {
                    Color.white
                }
            }
            .frame(width: 276, height: 276)
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: NB.Radius.xl, style: .continuous))
            .accessibilityLabel("QR code to join")
            VStack(alignment: .leading, spacing: 8) {
                TVText.label("Room code").foregroundStyle(NB.Palette.textDim)
                Text(code).font(NB.TVType.display).tracking(120 * 0.14).foregroundStyle(NB.Palette.coral)
            }
            if let url = joinURL.flatMap(Self.short) {
                (Text("or open ").foregroundStyle(NB.Palette.textDim) + Text(url).foregroundStyle(.white).bold())
                    .font(NB.TVType.caption).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .frame(width: 560, alignment: .leading)
    }

    /// "192.168.1.24:8080" from the full join URL.
    static func short(_ url: String) -> String? {
        guard let u = URL(string: url), let host = u.host else { return nil }
        return u.port.map { "\(host):\($0)" } ?? host
    }
}

struct LobbyScreen: View {
    var tv: TVView
    var data: LobbyData
    var qr: CGImage?
    var help: Bool

    var body: some View {
        let n = data.players.count
        TVSafe {
            TVTop { TVBrand(label: n == 0 ? (help ? "Waiting for players" : "Up to 8 players") : n >= 8 ? "Room full" : "\(n) of 8 players") }
                right: { FaceCorner(cue: tv.face) }
            HStack(alignment: .top, spacing: 96) {
                JoinColumn(code: data.code, joinURL: data.joinURL, qr: qr)
                if help { helpPanel } else { seats(n) }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            if !help {
                TVFoot(left: n == 0 ? "The first player to join becomes the leader" : "\(data.leaderName ?? "The leader") starts the game from their phone",
                       right: tv.room.settings.familyFriendly ? "Family-friendly on" : "Family-friendly off")
            }
        }
    }

    private func seats(_ n: Int) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(n == 0 ? "Grab your phone and join" : n >= 8 ? "8 players in · room full" : "\(n) player\(n == 1 ? "" : "s") in")
                .font(NB.TVType.title)
            if n == 0 { Text("No app needed. Same Wi-Fi as this TV.").font(NB.TVType.body).foregroundStyle(NB.Palette.textDim) }
            Grid(horizontalSpacing: 24, verticalSpacing: 20) {
                ForEach(0..<4, id: \.self) { row in
                    GridRow {
                        ForEach(0..<2, id: \.self) { col in
                            let i = row * 2 + col
                            if i < n {
                                let p = data.players[i]
                                TVChip(player: p, leader: p.isLeader, offline: !p.connected, vPad: 8)
                            } else {
                                TVSeat(height: 88)
                            }
                        }
                    }
                }
            }
        }
    }

    private var helpPanel: some View {
        TVPanel {
            Text("Nobody in yet?").font(NB.TVType.title)
            VStack(alignment: .leading, spacing: 20) {
                Text("1. Phones must be on the ") + Text("same Wi-Fi").bold().foregroundColor(.white) + Text(" as the device running NallaBox.")
                Text("2. Guest, hotel and office Wi-Fi often stop phones reaching each other.")
                Text("3. No luck? Turn on ") + Text("Personal Hotspot").bold().foregroundColor(.white) + Text(" on the host iPhone and join that.")
            }
            .font(NB.TVType.body)
            Text("This tip shows after 60 seconds with no one in.").font(NB.TVType.caption).foregroundStyle(NB.Palette.textDim)
        }
        .frame(maxHeight: 620)
    }
}

struct GameCardView: View {
    var card: GameCard
    var selected: Bool
    var warn: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(card.icon).font(.custom("Nunito", size: 120).weight(.black)).foregroundStyle(NB.Palette.ink)
                .frame(maxWidth: .infinity).aspectRatio(21 / 9, contentMode: .fit)
                .background(card.colour.color, in: RoundedRectangle(cornerRadius: NB.Radius.lg * 0.7, style: .continuous))
            Text(card.name).font(NB.TVType.heading)
            Text(card.pitch).font(NB.TVType.body).foregroundStyle(NB.Palette.textDim).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let warn {
                Text("⚠ \(warn)").font(NB.TVType.caption.weight(.heavy)).foregroundStyle(NB.Palette.danger)
            } else {
                Text("\(card.players) · \(card.length)").font(NB.TVType.caption).foregroundStyle(NB.Palette.textDim)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(selected ? Color(hex: 0x33263A) : NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: NB.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NB.Radius.lg, style: .continuous).strokeBorder(selected ? NB.Palette.coral : .clear, lineWidth: 4))
    }
}

struct PickerScreen: View {
    var tv: TVView
    var data: PickerData
    var body: some View {
        let leader = data.leaderName ?? "The leader"
        TVSafe {
            TVTop { TVBrand(label: "Choose a game") } right: { FaceCorner(cue: tv.face) }
            HStack(alignment: .top, spacing: 40) {
                ForEach(data.games, id: \.id) { g in
                    GameCardView(card: g, selected: g.id == data.preview,
                                 warn: data.playerCount < g.minPlayers ? "Needs \(g.minPlayers) players · \(data.playerCount) in the room" : nil)
                }
            }
            .frame(maxHeight: .infinity)
            TVFoot(left: "\(leader) is choosing on their phone", right: "\(data.playerCount) players in")
        }
    }
}

struct SettingsScreen: View {
    var tv: TVView
    var data: SettingsData
    var body: some View {
        TVSafe {
            TVTop { TVBrand(label: "Next up") } right: { FaceCorner(cue: tv.face) }
            Text(data.game.name).font(NB.TVType.display)
            Text(data.game.pitch).font(NB.TVType.body).foregroundStyle(NB.Palette.textDim)
            HStack(spacing: 32) {
                box("Rounds", data.roundsLabel)
                box("Timer", Self.timerName(data.timer))
                box("Family-friendly", data.familyFriendly ? "On" : "Off")
                if let banned = data.bannedWords { box("Banned words", banned ? "On" : "Off") }
            }
            .frame(height: 220)
            Spacer(minLength: 0)
            TVFoot(left: "\(data.leaderName ?? "The leader") can still change these on their phone", right: "\(data.playerCount) players in")
        }
    }

    static func timerName(_ t: TimerSpeed) -> String {
        switch t {
        case .x1: "Normal (1×)"
        case .x15: "Relaxed (1.5×)"
        case .x2: "Slow (2×)"
        case .off: "Off"
        }
    }

    private func box(_ label: String, _ value: String) -> some View {
        TVPanel(padding: 40) {
            TVText.label(label).foregroundStyle(NB.Palette.textDim)
            Text(value).font(NB.TVType.title).lineLimit(1).minimumScaleFactor(0.6)
        }
    }
}

struct HowToScreen: View {
    var tv: TVView
    var data: HowToData
    var body: some View {
        TVSafe {
            TVTop { TVBrand(label: "How to play · \(data.game.name)") } right: { FaceCorner(cue: tv.face) }
            HStack(alignment: .top, spacing: 40) {
                ForEach(Array(data.steps.enumerated()), id: \.offset) { _, step in
                    TVPanel(padding: 44) {
                        TVBigIcon(glyph: step.icon)
                        Text(step.title).font(NB.TVType.heading)
                        Text(step.text).font(NB.TVType.body).foregroundStyle(NB.Palette.textDim).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            VStack(spacing: 24) {
                if let d = tv.screen.deadline { TVProgress(deadline: d, total: 15) }
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let left = max(0, Int(((tv.screen.deadline ?? 0) - ctx.date.timeIntervalSince1970).rounded(.up)))
                    TVFoot(left: "Starts in \(left) s", right: "\(data.leaderName ?? "The leader") can skip from their phone")
                }
            }
        }
    }
}

struct ResultsScreen: View {
    var tv: TVView
    var data: ResultsData
    var body: some View {
        TVSafe {
            TVTop { TVBrand(label: "\(data.game.name) · Final results") } right: { FaceCorner(cue: tv.face) }
            HStack(alignment: .top, spacing: 80) {
                VStack(spacing: 24) {
                    podium.frame(height: 400)
                    HStack(spacing: 24) {
                        ForEach(Array(data.awards.prefix(2).enumerated()), id: \.offset) { _, a in award(a) }
                    }
                }
                .frame(width: 820)
                TVLeaderboard(standings: data.standings, compact: true)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            TVFoot(left: "\(tv.room.players.first { $0.isLeader }?.name ?? "The leader"): Play again or pick a new game")
        }
    }

    private var podium: some View {
        let p = data.podium
        let order: [(Standing?, CGFloat, Bool)] = [(p.count > 1 ? p[1] : nil, 130, false), (p.first, 180, true), (p.count > 2 ? p[2] : nil, 100, false)]
        // One size for all three names so they read as a set (long names drop to body size).
        let nameFont = p.contains { $0.player.name.count > 8 } ? NB.TVType.body.weight(.heavy) : NB.TVType.heading
        return HStack(alignment: .bottom, spacing: 24) {
            ForEach(0..<3, id: \.self) { i in
                VStack(spacing: 12) {
                    if let s = order[i].0 {
                        TVAvatar(name: s.player.name, colour: s.player.colour)
                        Text(s.player.name).font(nameFont).lineLimit(1).truncationMode(.tail)
                        Text(tvNumber(s.points)).font(NB.TVType.body).foregroundStyle(NB.Palette.textDim)
                        Text("\(s.rank)").font(NB.TVType.title).frame(maxWidth: .infinity).frame(height: order[i].1)
                            .background(order[i].2 ? NB.Palette.coral : NB.Palette.inkRaised,
                                        in: UnevenRoundedRectangle(topLeadingRadius: NB.Radius.lg, topTrailingRadius: NB.Radius.lg))
                    } else {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func award(_ a: Award) -> some View {
        HStack(spacing: 20) {
            TVAvatar(name: a.player.name, colour: a.player.colour)
            VStack(alignment: .leading, spacing: 2) {
                TVText.label(a.title).foregroundStyle(NB.Palette.coral)
                Text(a.player.name).font(NB.TVType.body).lineLimit(1)
                Text(a.note).font(NB.TVType.caption).foregroundStyle(NB.Palette.textDim).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: NB.Radius.lg, style: .continuous))
    }
}
