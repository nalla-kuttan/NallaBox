import SwiftUI
import UIKit

/// H2: explain why, start the room (which makes iOS ask), then go on or show the denied state.
struct H2LocalNetwork: View {
    var model: HostModel
    var next: () -> Void
    @State private var denied = false
    @State private var asking = false
    @Environment(\.scenePhase) private var phase

    var body: some View {
        if denied {
            PhoneScreen {
                BigIcon(glyph: "🔒")
                Text("Local network is off").phoneTitle()
                Text("Without it, no one can join. Turn it on in Settings:").phoneBodyDim()
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Open Settings › NallaBox")
                    Text("2. Turn on Local Network")
                    Text("3. Come back here")
                }
                .font(NB.PhoneType.body).foregroundStyle(NB.Palette.textDim)
            } action: {
                PhoneButton(title: "Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            .onChange(of: phase) { if phase == .active { Task { await ask() } } }
        } else {
            PhoneScreen {
                BigIcon(glyph: "📡")
                Text("Let friends' phones find this iPhone").phoneTitle()
                Text("NallaBox needs your local network so friends' phones can reach this iPhone. Nothing leaves your Wi-Fi.").phoneBodyDim()
                (Text("Next, iOS will ask. Tap ") + Text("Allow").bold().foregroundColor(.white) + Text("."))
                    .font(NB.PhoneType.caption).foregroundStyle(NB.Palette.textDim)
                if let e = model.lastError { Text(e).font(NB.PhoneType.caption).foregroundStyle(NB.Palette.danger) }
            } action: {
                PhoneButton(title: asking ? "Waiting for iOS…" : "Continue", disabledReason: asking ? "Answer the iOS prompt" : nil) {
                    Task { await ask() }
                }
            }
        }
    }

    private func ask() async {
        asking = true
        defer { asking = false }
        await model.startRoom()
        guard model.running else { return }
        switch await LocalNetwork().request() {
        case .granted: denied = false; next()
        case .denied: denied = true
        }
    }
}
