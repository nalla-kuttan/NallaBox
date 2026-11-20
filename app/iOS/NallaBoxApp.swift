import SwiftUI
import NallaCore

@main
struct NallaBoxApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup {
            HostFlow(model: sharedModel, display: .shared)
                .preferredColorScheme(.dark)
        }
    }
}

/// H1 → H2 → H3 → H4 → H5, with H6 (menu), H7 (TV gone) and H8 (back from background) on top.
struct HostFlow: View {
    var model: HostModel
    var display: ExternalDisplay
    enum Step { case welcome, localNetwork, connectTV, name, live }

    @AppStorage("onboarded") private var onboarded = false
    @AppStorage("hostName") private var name = ""
    @AppStorage("hostColour") private var colour = PlayerColour.saffron.rawValue
    @State private var step: Step = .localNetwork
    @State private var wasAway = false
    @State private var showAway = false
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack {
            NB.Palette.ink.ignoresSafeArea()
            switch step {
            case .welcome: H1Welcome { onboarded = true; step = .localNetwork }
            case .localNetwork: H2LocalNetwork(model: model) { step = .connectTV }
            case .connectTV: H3ConnectTV(display: display) { step = .name }
            case .name:
                H4Name(name: $name, colour: $colour) {
                    Task {
                        if !model.running { await model.startRoom() }
                        await model.reserveHostSeat(name: name, colour: PlayerColour(rawValue: colour) ?? .saffron)
                        step = .live
                    }
                }
            case .live:
                if display.isConnected { H5LiveRoom(model: model, display: display) } else { H7TVDisconnected(model: model) }
            }
        }
        .onAppear { if !onboarded { step = .welcome } }
        .onChange(of: model.running) { UIApplication.shared.isIdleTimerDisabled = model.running; if !model.running && step == .live { step = .name } }
        .onChange(of: display.isConnected) { if !display.isConnected && step == .live && model.inGame && !model.paused { model.send(.pause) } }
        .onChange(of: phase) {
            switch phase {
            case .background:
                if step == .live, model.inGame, !model.paused { model.send(.pause); wasAway = true }
            case .active:
                if wasAway { wasAway = false; showAway = true }
            default: break
            }
        }
        .alert("The room paused while you were away", isPresented: $showAway) {
            Button("Resume game") { model.send(.resume) }
        } message: {
            Text("NallaBox has to stay open to run the game. All \(model.players.count) players are still connected.")
        }
    }
}
