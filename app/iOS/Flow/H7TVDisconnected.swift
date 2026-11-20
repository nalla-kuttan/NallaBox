import SwiftUI

/// H7: shown over the live room when the TV goes away; the game is paused for everyone.
struct H7TVDisconnected: View {
    var model: HostModel
    var body: some View {
        PhoneScreen {
            TVArt(glyph: "✕", tint: NB.Palette.danger)
            Text("TV disconnected").phoneTitle().padding(.top, 20)
            Text("The game is paused for everyone. Players stay connected while you reconnect.").phoneBodyDim()
        } action: {
            ZStack {
                PhoneButton(title: "Reconnect AirPlay") {}
                RoutePicker(invisible: true).frame(height: NB.phoneActionHeight)
            }
            PhoneButton(title: "End session", kind: .secondary) { model.send(.endSession) }
        }
    }
}
