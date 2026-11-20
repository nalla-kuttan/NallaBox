import SwiftUI
import NallaCore

/// Draws the whole TV from a snapshot: the screen for `tv.screen.screen`, then the overlays
/// (T7 pause, T8 reconnect banners, T9 toast).
struct TVRootView: View {
    var tv: TVView
    var qr: CGImage?
    var captionSize: CGFloat = 36

    var body: some View {
        TVCanvas {
            ZStack {
                NB.Palette.ink
                screen
                    .blur(radius: tv.overlays.paused == nil ? 0 : 2)
                    .opacity(tv.overlays.paused == nil ? 1 : 0.35)
                overlays
            }
            .environment(\.captionSize, captionSize)
            .animation(.easeInOut(duration: NB.Motion.screen), value: tv.screen.screen)
        }
    }

    @ViewBuilder private var screen: some View {
        let s = tv.screen
        switch s.screen {
        case "T1", "T2", "T3":
            if let d = try? s.data.decode(LobbyData.self) { LobbyScreen(tv: tv, data: d, qr: qr, help: s.screen == "T3") }
        case "T4":
            if let d = try? s.data.decode(PickerData.self) { PickerScreen(tv: tv, data: d) }
        case "T5":
            if let d = try? s.data.decode(SettingsData.self) { SettingsScreen(tv: tv, data: d) }
        case "T6":
            if let d = try? s.data.decode(HowToData.self) { HowToScreen(tv: tv, data: d) }
        case "T10":
            if let d = try? s.data.decode(ResultsData.self) { ResultsScreen(tv: tv, data: d) }
        default:
            if let game = GameScreens.view(for: tv) { game } else { fallback }
        }
    }

    private var fallback: some View {
        TVSafe {
            TVTop { TVBrand(label: "") } right: { FaceCorner(cue: tv.face) }
            Spacer()
        }
    }

    @ViewBuilder private var overlays: some View {
        if let p = tv.overlays.paused {
            ZStack {
                Color(red: 18 / 255, green: 16 / 255, blue: 25 / 255).opacity(0.78)
                VStack(spacing: 32) {
                    FaceView(state: .sleepy, size: 320)
                    Text("Paused").font(NB.TVType.display)
                    Text("\(p.by) paused the game · resume from their phone").font(NB.TVType.heading).foregroundStyle(NB.Palette.textDim)
                }
                .foregroundStyle(NB.Palette.text)
            }
        }
        VStack(spacing: 20) {
            Spacer()
            ForEach(tv.overlays.reconnecting, id: \.player.id) { b in
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let s = max(0, Int(ctx.date.timeIntervalSince1970 - b.since))
                    HStack(spacing: 24) {
                        Text("📶")
                        Text("Waiting for \(b.player.name) to reconnect… the round keeps going.").frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(s / 60):\(String(format: "%02d", s % 60))").foregroundStyle(NB.Palette.textDim).monospacedDigit()
                    }
                    .font(NB.TVType.body.weight(.heavy))
                    .padding(.horizontal, 28).padding(.vertical, 17)
                    .background(NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: NB.Radius.lg, style: .continuous))
                    .overlay(alignment: .leading) { Rectangle().fill(NB.Palette.coral).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2)) }
                    .foregroundStyle(NB.Palette.text)
                }
            }
            if let toast = tv.overlays.toast {
                Text("👑 \(toast)").font(NB.TVType.heading.weight(.black)).foregroundStyle(NB.Palette.ink)
                    .padding(.horizontal, 52).padding(.vertical, 26)
                    .background(NB.Palette.paper, in: Capsule())
                    .shadow(color: .black.opacity(0.35), radius: 15, y: 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, NB.tvSafeInset)
        .padding(.bottom, 96)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tv.overlays.toast)
    }
}

/// Game screens register here (Tasks 10, 12, 14).
enum GameScreens {
    @MainActor static func view(for tv: TVView) -> AnyView? {
        RedactedTV.view(for: tv) ?? SketchTV.view(for: tv) ?? InsiderTV.view(for: tv)
    }
}

private struct CaptionSizeKey: EnvironmentKey { static let defaultValue: CGFloat = 36 }
extension EnvironmentValues {
    var captionSize: CGFloat {
        get { self[CaptionSizeKey.self] }
        set { self[CaptionSizeKey.self] = newValue }
    }
}
