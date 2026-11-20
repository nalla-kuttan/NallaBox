import SwiftUI
import NallaCore

/// Draws a phone drawing (normalised strokes on a square) with the same palette and brush sizes as canvas.js.
struct StrokeCanvas: View {
    var strokes: [Stroke]
    static let colours: [Color] = [0x1E1B2E, 0xFF5C39, 0xFFB020, 0x3DB7FF, 0x4ED19A, 0xB58CFF].map { Color(hex: $0) }
    static let sizes: [CGFloat] = [0.0125, 0.025, 0.045]
    static let paper = Color(hex: 0xF6F1EA)

    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            let ox = (size.width - side) / 2, oy = (size.height - side) / 2
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Self.paper))
            for s in strokes where s.p.count >= 2 {
                var path = Path()
                path.move(to: CGPoint(x: ox + s.p[0] * side, y: oy + s.p[1] * side))
                if s.p.count == 2 { path.addLine(to: CGPoint(x: ox + s.p[0] * side + 0.5, y: oy + s.p[1] * side)) }
                for i in stride(from: 2, to: s.p.count - 1, by: 2) {
                    path.addLine(to: CGPoint(x: ox + s.p[i] * side, y: oy + s.p[i + 1] * side))
                }
                let colour = Self.colours[min(max(s.c, 0), 5)]
                let width = Self.sizes[min(max(s.s, 0), 2)] * side
                ctx.stroke(path, with: .color(colour), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityLabel("Drawing")
    }
}

/// A numbered drawing tile, optionally with the artist's name.
struct DrawingTileView: View {
    var number: Int
    var strokes: [Stroke]
    var artist: PlayerSummary?
    var body: some View {
        StrokeCanvas(strokes: strokes)
            .overlay(alignment: .topLeading) {
                Text("\(number)").font(.custom("Nunito", size: 32).weight(.black)).foregroundStyle(.white)
                    .padding(.horizontal, 10).frame(minWidth: 52, minHeight: 52)
                    .background(NB.Palette.ink, in: RoundedRectangle(cornerRadius: 10)).padding(10)
            }
            .overlay(alignment: .bottomLeading) {
                if let artist {
                    HStack(spacing: 8) {
                        TVAvatar(name: artist.name, colour: artist.colour, size: 40)
                        Text(artist.name).font(.custom("Nunito", size: 30).weight(.heavy)).lineLimit(1)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(NB.Palette.ink.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white).padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: NB.Radius.lg, style: .continuous))
    }
}
