import SwiftUI
import NallaCore

// Composite Sketch TV screens C1–C6, ported from design/mockups/_build/pages_sketch.py.

enum SketchTV {
    @MainActor static func view(for tv: TVView) -> AnyView? {
        let d = tv.screen.data
        switch tv.screen.screen {
        case "C1": return (try? d.decode(C1TV.self)).map { AnyView(C1Screen(tv: tv, data: $0)) }
        case "C2": return (try? d.decode(C2TV.self)).map { AnyView(C2Screen(tv: tv, data: $0)) }
        case "C3": return (try? d.decode(C3TV.self)).map { AnyView(LineupScreen(tv: tv, top: $0.top, drawings: $0.drawings)) }
        case "C4": return (try? d.decode(C4TV.self)).map { AnyView(C4Screen(tv: tv, data: $0)) }
        case "C5": return (try? d.decode(C5TV.self)).map { AnyView(LineupScreen(tv: tv, top: $0.top, drawings: $0.drawings)) }
        case "C6": return (try? d.decode(C6TV.self)).map { AnyView(C6Screen(tv: tv, data: $0)) }
        default: return nil
        }
    }
}

private struct SketchTop: View {
    var tv: TVView
    var label: String
    var timer = true
    var body: some View {
        TVTop {
            TVText.label(label).foregroundStyle(NB.Palette.textDim)
        } right: {
            if timer, let d = tv.screen.deadline { TVTimer(deadline: d) }
            FaceCorner(cue: tv.face)
        }
    }
}

struct C1Screen: View {
    var tv: TVView
    var data: C1TV
    var body: some View {
        TVSafe {
            SketchTop(tv: tv, label: data.top)
            HStack(spacing: 48) {
                TVAvatar(name: data.witness.name, colour: data.witness.colour, size: 144)
                VStack(alignment: .leading, spacing: 24) {
                    Text("\(data.witness.name) is the Witness").font(NB.TVType.display).lineLimit(2).minimumScaleFactor(0.6)
                    Text("Everyone else: get ready to draw what \(data.witness.name) describes.").font(NB.TVType.heading).foregroundStyle(NB.Palette.textDim)
                }
            }
            .frame(maxHeight: .infinity)
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let left = max(0, Int(((tv.screen.deadline ?? 0) - ctx.date.timeIntervalSince1970).rounded(.up)))
                TVFoot(left: data.bannedOn ? "Banned words are on" : "", right: "Drawing starts in \(left) s")
            }
        }
    }
}

struct C2Screen: View {
    var tv: TVView
    var data: C2TV
    var body: some View {
        TVSafe {
            SketchTop(tv: tv, label: data.top, timer: false)
            HStack(spacing: 64) {
                if let d = tv.screen.deadline {
                    TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                        let s = max(0, Int((d - ctx.date.timeIntervalSince1970).rounded(.up)))
                        Text("\(s / 60):\(String(format: "%02d", s % 60))").font(.custom("Nunito", size: 220).weight(.black))
                            .monospacedDigit().foregroundStyle(NB.Palette.coral).lineLimit(1).fixedSize()
                    }
                }
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(data.witness.name), describe it out loud!").font(NB.TVType.title)
                    Text("Artists are drawing on their phones.").font(NB.TVType.heading).foregroundStyle(NB.Palette.textDim)
                }
            }
            VStack(alignment: .leading, spacing: 20) {
                TVText.label("\(data.artists.count) artist\(data.artists.count == 1 ? "" : "s") drawing").foregroundStyle(NB.Palette.textDim)
                Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                    ForEach(Array(stride(from: 0, to: data.artists.count, by: 4)), id: \.self) { start in
                        GridRow {
                            ForEach(data.artists[start..<min(start + 4, data.artists.count)]) { p in
                                TVChip(player: p, submitted: data.done.contains(p.id), offline: !p.connected, avatar: 52, font: .custom("Nunito", size: 36), vPad: 12)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct LineupScreen: View {
    var tv: TVView
    var top: String
    var drawings: [DrawingTile]
    var body: some View {
        TVSafe {
            SketchTop(tv: tv, label: top)
            let cols = drawings.count <= 4 ? max(drawings.count, 1) : 4
            Grid(horizontalSpacing: 24, verticalSpacing: 24) {
                ForEach(Array(stride(from: 0, to: drawings.count, by: cols)), id: \.self) { start in
                    GridRow {
                        ForEach(drawings[start..<min(start + cols, drawings.count)], id: \.number) { d in
                            DrawingTileView(number: d.number, strokes: d.strokes).frame(width: 380, height: 285)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
    }
}

struct SceneArt: View {
    var scene: SceneCard
    var body: some View {
        ZStack {
            StrokeCanvas.paper
            if let image = scene.image, !image.isEmpty {
                Image(image).resizable().scaledToFill()
            } else {
                Text(scene.art).font(.system(size: 150)).minimumScaleFactor(0.4).lineLimit(1).padding(32)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: NB.Radius.xl, style: .continuous))
    }
}

struct C4Screen: View {
    var tv: TVView
    var data: C4TV
    var body: some View {
        TVSafe {
            SketchTop(tv: tv, label: data.top, timer: false)
            HStack(alignment: .top, spacing: 64) {
                VStack(alignment: .leading, spacing: 16) {
                    TVText.label("What \(data.witness.name) saw").foregroundStyle(NB.Palette.textDim)
                    SceneArt(scene: data.scene).frame(width: 640, height: 480)
                    Text(data.scene.caption).font(NB.TVType.heading).lineLimit(2).frame(width: 640, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 16) {
                    if let p = data.picked {
                        TVText.label("\(data.witness.name)'s pick · #\(p.number)").foregroundStyle(NB.Palette.textDim)
                        DrawingTileView(number: p.number, strokes: p.strokes, artist: p.artist).frame(width: 640, height: 480)
                        (Text("+1,000").foregroundColor(NB.Palette.success) + Text(" \(p.artist.name) · ") + Text("+500").foregroundColor(NB.Palette.success) + Text(" \(data.witness.name)"))
                            .font(NB.TVType.heading).lineLimit(1).minimumScaleFactor(0.7)
                    } else {
                        TVText.label("No pick").foregroundStyle(NB.Palette.textDim)
                        Text("No points this round.").font(NB.TVType.heading).foregroundStyle(NB.Palette.textDim)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct C6Screen: View {
    var tv: TVView
    var data: C6TV
    var body: some View {
        TVSafe {
            SketchTop(tv: tv, label: data.top, timer: false)
            HStack(alignment: .top, spacing: 48) {
                if let w = data.worst {
                    VStack(alignment: .leading, spacing: 16) {
                        TVText.label("Most Wanted").foregroundStyle(NB.Palette.coral)
                        DrawingTileView(number: w.number, strokes: w.strokes, artist: w.artist).frame(width: 420, height: 420)
                    }
                    .frame(width: 420)
                }
                TVLeaderboard(standings: data.standings, compact: true)
            }
            Spacer(minLength: 0)
        }
    }
}
