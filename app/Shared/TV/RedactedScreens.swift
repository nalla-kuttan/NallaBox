import SwiftUI
import NallaCore

// Redacted TV screens R1–R5, ported from design/mockups/_build/pages_redacted.py.

enum RedactedTV {
    @MainActor static func view(for tv: TVView) -> AnyView? {
        let d = tv.screen.data
        switch tv.screen.screen {
        case "R1": return (try? d.decode(R1TV.self)).map { AnyView(R1Screen(tv: tv, data: $0)) }
        case "R2": return (try? d.decode(R2TV.self)).map { AnyView(R2Screen(tv: tv, data: $0)) }
        case "R3": return (try? d.decode(R3TV.self)).map { AnyView(R3Screen(tv: tv, data: $0)) }
        case "R4": return (try? d.decode(R4TV.self)).map { AnyView(R4Screen(tv: tv, data: $0)) }
        case "R5": return (try? d.decode(R5TV.self)).map { AnyView(R5Screen(tv: tv, data: $0)) }
        default: return nil
        }
    }

    /// The passage with numbered coral blanks, or with the fills in coral.
    static func passage(_ segments: [Segment], fills: [String]? = nil) -> Text {
        var out = AttributedString()
        for s in segments {
            switch s {
            case .text(let t): out += AttributedString(t)
            case .blank(let n):
                if let fills, n - 1 < fills.count {
                    var a = AttributedString(fills[n - 1]); a.foregroundColor = NB.Palette.coral; out += a
                } else {
                    var a = AttributedString("\u{2002}\(n)\u{2002}"); a.backgroundColor = NB.Palette.coral; a.foregroundColor = NB.Palette.ink; out += a
                }
            }
        }
        return Text(out)
    }
}

private struct GameTop: View {
    var tv: TVView
    var label: String
    var body: some View {
        TVTop {
            TVText.label(label).foregroundStyle(NB.Palette.textDim)
        } right: {
            if let d = tv.screen.deadline { TVTimer(deadline: d) }
            FaceCorner(cue: tv.face)
        }
    }
}

struct R1Screen: View {
    var tv: TVView
    var data: R1TV
    var body: some View {
        let waiting = data.players.filter { !data.submitted.contains($0.id) }.count
        TVSafe {
            GameTop(tv: tv, label: data.top)
            RedactedTV.passage(data.passage).font(NB.TVType.title).lineSpacing(18).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 24) {
                TVText.label(waiting == 0 ? "Everyone's in" : "Waiting on \(waiting) player\(waiting == 1 ? "" : "s")").foregroundStyle(NB.Palette.textDim)
                Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                    ForEach(Array(stride(from: 0, to: data.players.count, by: 4)), id: \.self) { start in
                        GridRow {
                            ForEach(data.players[start..<min(start + 4, data.players.count)]) { p in
                                TVChip(player: p, submitted: data.submitted.contains(p.id), offline: !p.connected, avatar: 52, font: .custom("Nunito", size: 36), vPad: 12)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            TVFoot(left: "Write on your phone")
        }
    }
}

struct R2Screen: View {
    var tv: TVView
    var data: R2TV
    var body: some View {
        TVSafe {
            GameTop(tv: tv, label: data.top)
            TVText.label("Version \(data.index) of \(data.count)").foregroundStyle(NB.Palette.coral)
            RedactedTV.passage(data.passage, fills: data.fills).font(NB.TVType.title).lineSpacing(18).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                ForEach(1...max(data.count, 1), id: \.self) { i in
                    Text("\(i)").font(NB.TVType.label.weight(.black))
                        .frame(width: 64, height: 64)
                        .background(i == data.index ? NB.Palette.coral : i < data.index ? NB.Palette.inkLine : NB.Palette.inkRaised,
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .foregroundStyle(i <= data.index ? .white : NB.Palette.textDim)
                }
            }
            Spacer(minLength: 0)
            TVFoot(left: "Listen. Voting opens after all \(data.count).", right: "Captions on")
        }
    }
}

private struct Tile: View {
    var number: Int
    var text: String
    var size: CGFloat = 36
    var real = false
    var tag: String?
    var author: PlayerSummary?
    var fooled = 0
    var voters: [PlayerSummary] = []
    var body: some View {
        HStack(alignment: .top, spacing: size * 0.6) {
            Text("\(number)").foregroundStyle(real ? .white : NB.Palette.coral).frame(minWidth: size * 1.2, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(text).fixedSize(horizontal: false, vertical: true)
                if let author {
                    HStack(spacing: 8) {
                        TVAvatar(name: author.name, colour: author.colour, size: 36)
                        Text(author.name + (fooled > 0 ? " · fooled \(fooled)" : "")).foregroundStyle(NB.Palette.textDim)
                        voterRow
                    }
                    .font(.custom("Nunito", size: 30).weight(.bold))
                } else if !voters.isEmpty {
                    voterRow
                }
            }
            Spacer(minLength: 0)
            if let tag {
                Text(tag).font(NB.TVType.label.weight(.black)).textCase(.uppercase)
                    .padding(.horizontal, 12).padding(.vertical, 2)
                    .background(.white, in: RoundedRectangle(cornerRadius: NB.Radius.sm))
                    .foregroundStyle(NB.Palette.coral)
            }
        }
        .font(.custom("Nunito", size: size).weight(.heavy))
        .padding(size * 0.6)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(real ? NB.Palette.coral : NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: NB.Radius.lg, style: .continuous))
        .foregroundStyle(NB.Palette.text)
    }

    private var voterRow: some View {
        HStack(spacing: 4) { ForEach(voters) { TVAvatar(name: $0.name, colour: $0.colour, size: 36) } }
    }
}

private func tileGrid<Content: View>(_ count: Int, @ViewBuilder _ cell: @escaping (Int) -> Content) -> some View {
    Grid(horizontalSpacing: 20, verticalSpacing: 20) {
        ForEach(Array(stride(from: 0, to: count, by: 3)), id: \.self) { start in
            GridRow(alignment: .top) {
                ForEach(start..<min(start + 3, count), id: \.self) { cell($0) }
                if count - start < 3 { ForEach(0..<(3 - (count - start)), id: \.self) { _ in Color.clear.gridCellUnsizedAxes(.vertical) } }
            }
        }
    }
}

struct R3Screen: View {
    var tv: TVView
    var data: R3TV
    var body: some View {
        TVSafe {
            GameTop(tv: tv, label: data.top)
            Text("Which one is the real text?").font(NB.TVType.heading)
            tileGrid(data.versions.count) { i in
                Tile(number: data.versions[i].number, text: data.versions[i].fills.joined(separator: " · "), size: data.versions.count > 6 ? 34 : 36)
            }
            Spacer(minLength: 0)
            TVFoot(left: "Vote on your phone · \(data.voted) of \(data.players) voted", right: "You can't vote for your own")
        }
    }
}

struct R4Screen: View {
    var tv: TVView
    var data: R4TV
    var body: some View {
        TVSafe {
            GameTop(tv: tv, label: data.top)
            (Text("The real text: ") + Text(data.real.joined(separator: " · ")).foregroundColor(NB.Palette.coral)).font(NB.TVType.heading)
            tileGrid(data.versions.count) { i in
                let v = data.versions[i]
                Tile(number: v.number, text: v.fills.joined(separator: " · "), size: 30, real: v.real, tag: v.real ? "Real" : nil,
                     author: v.real ? nil : v.authors.first, fooled: v.voters.count, voters: v.voters)
            }
            Spacer(minLength: 0)
        }
    }
}

struct R5Screen: View {
    var tv: TVView
    var data: R5TV
    var body: some View {
        TVSafe {
            GameTop(tv: tv, label: data.top)
            TVLeaderboard(standings: data.standings, compact: true)
            Spacer(minLength: 0)
        }
    }
}
