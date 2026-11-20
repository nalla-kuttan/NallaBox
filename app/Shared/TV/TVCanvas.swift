import SwiftUI

/// Lays out content on the fixed 1920×1080 TV canvas and scales it to fit, letterboxed in Night Ink.
struct TVCanvas<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width / NB.tvCanvas.width, g.size.height / NB.tvCanvas.height)
            content
                .frame(width: NB.tvCanvas.width, height: NB.tvCanvas.height)
                .clipped()
                .scaleEffect(s)
                .frame(width: g.size.width, height: g.size.height)
        }
        .background(NB.Palette.ink)
        .environment(\.colorScheme, .dark)
    }
}
