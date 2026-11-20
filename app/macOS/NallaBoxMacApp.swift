import AppKit
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
        Window("NallaBox", id: "main") {
            MacRoot(model: model)
                .frame(minWidth: 960, minHeight: 640)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Room") {
                Button(model.paused ? "Resume Game" : "Pause Game") { model.send(model.paused ? .resume : .pause) }.disabled(!model.running)
                Button("Skip Round") { model.send(.skip) }.disabled(!model.inGame)
                Divider()
                Button("End Session") { model.send(.endSession) }.disabled(!model.running)
            }
        }
    }
}

/// M1 → M2, with the game either on another screen (TV window) or full screen in this window (M3).
struct MacRoot: View {
    var model: HostModel
    @State private var options: [DisplayOption] = []
    @State private var choice: DisplayChoice = .thisWindow
    @State private var tvWindow: TVWindowController?
    @State private var fullGame = false

    var body: some View {
        Group {
            if !model.running {
                M1StartView(model: model, options: options, choice: $choice, start: start)
            } else if fullGame {
                M3FullGame(model: model, exit: { pauseAndExit() })
            } else {
                M2RoomView(model: model, displayName: displayName, showFullScreenGame: choice == .thisWindow ? { enterFullGame() } : nil)
            }
        }
        .navigationTitle(model.running ? "NallaBox — Room \(model.endpoint?.code ?? "")" : "NallaBox")
        .onAppear {
            refreshDisplays()
            #if DEBUG
            UISnapshots.captureStart(model: model, options: options, choice: choice)
            if UserDefaults.standard.bool(forKey: "autoStartRoom") {
                Task {
                    await model.startRoom()
                    try? await Task.sleep(for: .seconds(1))
                    UISnapshots.captureRoom(model: model, displayName: displayName)
                }
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in refreshDisplays() }
        .onChange(of: model.running) { if !model.running { tvWindow?.close(); tvWindow = nil; setFullScreen(false); fullGame = false } }
    }

    private var displayName: String {
        guard choice != .thisWindow, let o = options.first(where: { $0.id == choice }) else { return "This window" }
        return "\(o.name) · \(o.detail.replacingOccurrences(of: " · recommended", with: ""))"
    }

    private func refreshDisplays() {
        options = Displays.options(excluding: NSApp.windows.first { $0.isVisible && $0.title.hasPrefix("NallaBox") }?.screen)
        if !options.contains(where: { $0.id == choice }) { choice = options.first?.id ?? .thisWindow }
    }

    private func start() {
        Task {
            await model.startRoom()
            guard model.running else { return }
            switch choice {
            case .screen(let id):
                if let screen = Displays.screen(id) {
                    let c = TVWindowController(model: model)
                    c.show(on: screen)
                    tvWindow = c
                }
            case .thisWindow:
                enterFullGame()
            }
        }
    }

    private func enterFullGame() {
        fullGame = true
        setFullScreen(true)
    }

    private func pauseAndExit() {
        if model.inGame { model.send(.pause) }
        fullGame = false
        setFullScreen(false)
    }

    private func setFullScreen(_ on: Bool) {
        guard let w = NSApp.windows.first(where: { $0.isVisible && $0.styleMask.contains(.titled) }) else { return }
        if w.styleMask.contains(.fullScreen) != on { w.toggleFullScreen(nil) }
    }
}

/// M3 with one display: the game fills the window; host controls appear when the pointer reaches the top edge. Esc pauses.
struct M3FullGame: View {
    var model: HostModel
    var exit: () -> Void
    @State private var showBar = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Color.black
            TVHostView(model: model)
            if showBar {
                HStack(spacing: 8) {
                    Text("Room \(model.endpoint?.code ?? "") · Esc pauses").foregroundStyle(NB.Palette.textDim).padding(.horizontal, 8)
                    barButton(model.paused ? "▶ Resume" : "⏸ Pause") { model.send(model.paused ? .resume : .pause) }
                    barButton("⏭ Skip round") { model.send(.skip) }
                    barButton("End game", danger: true) { model.send(.endGame) }
                    barButton("Exit full screen") { exit() }
                }
                .font(.custom("Nunito", size: 13).weight(.heavy))
                .padding(8)
                .background(Color(hex: 0x17151F, opacity: 0.94), in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.5), radius: 15, y: 10)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: NB.Motion.tap), value: showBar)
        .onContinuousHover { phase in
            if case .active(let p) = phase { showBar = p.y < 8 || (showBar && p.y < 80) } else { showBar = false }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(.escape) { exit(); return .handled }
    }

    private func barButton(_ title: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).padding(.horizontal, 12).frame(height: 32)
                .background(NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(danger ? NB.Palette.danger : NB.Palette.text)
        }
        .buttonStyle(.plain)
    }
}
