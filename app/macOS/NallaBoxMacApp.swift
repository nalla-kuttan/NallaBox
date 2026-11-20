import SwiftUI

@main
struct NallaBoxMacApp: App {
    @State private var model = HostModel()

    init() {
        #if DEBUG
        setvbuf(stdout, nil, _IONBF, 0)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if let tv = model.tv {
                    TVRootView(tv: tv, qr: model.qr)
                        .onChange(of: tv, initial: true) { TVSnapshotter.shared.capture(tv, qr: model.qr) }
                } else {
                    NB.Palette.ink
                    Text(model.lastError ?? "Starting…").foregroundStyle(NB.Palette.text)
                }
            }
            .frame(minWidth: 960, minHeight: 540)
            .task { await model.startRoom() }
        }
    }
}
