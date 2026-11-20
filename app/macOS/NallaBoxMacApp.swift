import SwiftUI

@main
struct NallaBoxMacApp: App {
    var body: some Scene {
        WindowGroup {
            ZStack {
                NB.Palette.ink
                Text("nallabox").foregroundStyle(NB.Palette.text)
            }
            .frame(minWidth: 640, minHeight: 400)
        }
    }
}
