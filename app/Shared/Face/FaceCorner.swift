import SwiftUI
import NallaCore

/// The host face (one of the 8 face SVGs from the logo kit) with a one-line caption bubble.
/// A state change squashes the face for 180 ms (UI/UX §9.6); with Reduce Motion it fades instead.
struct FaceView: View {
    var state: FaceState
    var size: CGFloat = NB.faceSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var squash = false

    var body: some View {
        Image("face-\(state.rawValue)")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .scaleEffect(x: squash && !reduceMotion ? 1.04 : 1, y: squash && !reduceMotion ? 0.9 : 1, anchor: .bottom)
            .opacity(squash && reduceMotion ? 0.4 : 1)
            .onChange(of: state) {
                squash = true
                withAnimation(.easeOut(duration: NB.Motion.faceSwap)) { squash = false }
            }
            .accessibilityHidden(true)
    }
}

struct FaceCorner: View {
    var cue: FaceCue
    @Environment(\.captionSize) private var captionSize

    var body: some View {
        HStack(spacing: 20) {
            if let caption = cue.caption, !caption.isEmpty {
                Text(caption)
                    .font(.custom("Nunito", size: captionSize).weight(.heavy))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(NB.Palette.ink)
                    .padding(.horizontal, 28).padding(.vertical, 18)
                    .background(NB.Palette.paper, in: RoundedRectangle(cornerRadius: NB.Radius.lg, style: .continuous))
                    .overlay(alignment: .trailing) {
                        BubbleTail().fill(NB.Palette.paper).frame(width: 14, height: 28).offset(x: 14)
                    }
                    .accessibilityLabel(caption)
            }
            FaceView(state: cue.state)
        }
    }
}

private struct BubbleTail: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }
}
