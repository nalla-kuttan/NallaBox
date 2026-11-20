import SwiftUI

@main
struct NallaBoxApp: App {
    var body: some Scene {
        WindowGroup {
            ZStack {
                NB.Palette.ink.ignoresSafeArea()
                Text("nallabox").foregroundStyle(NB.Palette.text)
            }
        }
    }
}
