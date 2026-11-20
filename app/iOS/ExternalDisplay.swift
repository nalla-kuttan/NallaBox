import AVFoundation
import SwiftUI
import UIKit

/// Shared host state for the iPhone app (the TV scene and the main scene both read it).
@MainActor let sharedModel = HostModel()

/// Is a TV attached (AirPlay or cable), and what is it called?
@MainActor
@Observable
final class ExternalDisplay {
    static let shared = ExternalDisplay()
    var isConnected = false
    var name: String?

    init() {
        #if DEBUG
        // Debug aid for the simulator (no command-line way to attach a display): `-simulateTV YES`.
        if UserDefaults.standard.bool(forKey: "simulateTV") { isConnected = true; name = "Simulated TV" }
        #endif
    }

    func refreshName() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "simulateTV") { return }
        #endif
        let route = AVAudioSession.sharedInstance().currentRoute.outputs
        name = route.first { $0.portType == .airPlay }?.portName
            ?? route.first { $0.portType == .HDMI }?.portName
            ?? (isConnected ? "TV" : nil)
    }
}

/// The TV: a non-interactive external-display scene showing the TV renderer.
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        w.rootViewController = UIHostingController(rootView: ExternalTVView(model: sharedModel))
        w.backgroundColor = UIColor(NB.Palette.ink)
        w.isHidden = false
        window = w
        ExternalDisplay.shared.isConnected = true
        ExternalDisplay.shared.refreshName()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        ExternalDisplay.shared.isConnected = false
        ExternalDisplay.shared.refreshName()
    }
}

struct ExternalTVView: View {
    var model: HostModel
    var body: some View {
        Group {
            if let tv = model.tv {
                TVRootView(tv: tv, qr: model.qr, captionSize: model.prefs.captions.points)
            } else {
                TVCanvas {
                    VStack(spacing: 32) {
                        Image("Symbol").resizable().frame(width: 200, height: 200)
                        Text("nallabox").font(NB.TVType.title).foregroundStyle(NB.Palette.text)
                        Text("Getting the room ready on the host iPhone…").font(NB.TVType.body).foregroundStyle(NB.Palette.textDim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .ignoresSafeArea()
    }
}
