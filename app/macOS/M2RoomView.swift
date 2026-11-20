import SwiftUI
import NallaCore

/// M2: room window. Left: code, QR, players (remove), network health or M4. Right: live TV preview.
/// The toolbar is for emergencies; the leader runs the game from their phone.
struct M2RoomView: View {
    @Bindable var model: HostModel
    var displayName: String
    var showFullScreenGame: (() -> Void)?
    @State private var removing: PlayerSummary?
    @State private var confirmEnd = false
    @State private var showSettings = false

    private var networkProblem: Bool { model.networkOK == false || model.tv?.screen.screen == "T3" }

    var body: some View {
        HStack(spacing: 0) {
            side.frame(width: 360)
            Rectangle().fill(Color(hex: 0x2E2A40)).frame(width: 1)
            main
        }
        .background(NB.Palette.ink)
        .foregroundStyle(NB.Palette.text)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let showFullScreenGame {
                    Button { showFullScreenGame() } label: { Label("Show game", systemImage: "arrow.up.left.and.arrow.down.right") }
                        .help("Show the game full screen in this window")
                }
                Button { model.send(model.paused ? .resume : .pause) } label: {
                    Label(model.paused ? "Resume" : "Pause", systemImage: model.paused ? "play.fill" : "pause.fill")
                }
                .disabled(!model.inGame && !model.paused)
                .keyboardShortcut("p", modifiers: .command)
                Button { model.send(.skip) } label: { Label("Skip round", systemImage: "forward.end.fill") }
                    .disabled(!model.inGame)
                Button(role: .destructive) { confirmEnd = true } label: { Label("End game", systemImage: "stop.fill") }
                    .disabled(!model.inGame)
                Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
        .confirmationDialog("End the game for everyone?", isPresented: $confirmEnd) {
            Button("End game", role: .destructive) { model.send(.endGame) }
            Button("Keep playing", role: .cancel) {}
        } message: { Text("Scores so far are shown on the TV.") }
        .confirmationDialog("Remove \(removing?.name ?? "") from the room?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button("Remove \(removing?.name ?? "")", role: .destructive) { if let p = removing { model.send(.removePlayer(p.id)) }; removing = nil }
            Button("Cancel", role: .cancel) { removing = nil }
        } message: { Text("\(removing?.name ?? "They") leave the game now. They can join again with the room code.") }
        .sheet(isPresented: $showSettings) { M5SettingsSheet(model: model) }
    }

    private var side: some View {
        VStack(alignment: .leading, spacing: 14) {
            label("Room code")
            Text(model.endpoint?.code ?? "····").font(.custom("Nunito", size: 44).weight(.black)).tracking(44 * 0.14).foregroundStyle(NB.Palette.coral)
            HStack(alignment: .top, spacing: 14) {
                if let qr = model.qr {
                    Image(decorative: qr, scale: 1).interpolation(.none).resizable().frame(width: 116, height: 116)
                        .padding(8).background(.white, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("QR code to join")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan, or open").foregroundStyle(NB.Palette.textDim)
                    Text(model.endpoint.flatMap { JoinColumn.short($0.joinURL) } ?? "").foregroundStyle(.white).bold().textSelection(.enabled)
                }
                .font(.custom("Nunito", size: 13).weight(.bold))
            }
            if networkProblem, let url = model.endpoint?.joinURL {
                M4NetworkPanel(joinURL: url)
                health(ok: false, text: "\(connected) connected · phones can't reach this Mac")
                Spacer(minLength: 0)
            } else {
                label("\(model.players.count) player\(model.players.count == 1 ? "" : "s")")
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(model.players) { p in playerRow(p) }
                    }
                }
                health(ok: true, text: "\(connected) connected · good")
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var connected: Int { model.players.filter(\.connected).count }

    private func playerRow(_ p: PlayerSummary) -> some View {
        HStack(spacing: 10) {
            TVAvatar(name: p.name, colour: p.colour, size: 28, dimmed: !p.connected)
            Text(p.name + (p.isLeader ? " · leader" : "") + (p.connected ? "" : " · offline")).font(.custom("Nunito", size: 14).weight(.heavy)).lineLimit(1)
            Spacer()
            Button("Remove") { removing = p }.buttonStyle(.plain)
                .font(.custom("Nunito", size: 12).weight(.heavy)).foregroundStyle(NB.Palette.textDim)
                .accessibilityLabel("Remove \(p.name)")
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func label(_ s: String) -> some View {
        Text(s).font(.custom("Nunito", size: 12).weight(.heavy)).textCase(.uppercase).foregroundStyle(NB.Palette.textDim)
    }

    private func health(ok: Bool, text: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(ok ? NB.Palette.success : NB.Palette.danger).frame(width: 10, height: 10)
            Text(text).font(.custom("Nunito", size: 13).weight(.heavy)).foregroundStyle(NB.Palette.textDim)
        }
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("On the TV now").font(.custom("Nunito", size: 18).weight(.heavy))
                Spacer()
                health(ok: true, text: displayName)
            }
            TVHostView(model: model)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(NB.Palette.inkLine, lineWidth: 1))
                .accessibilityLabel("TV preview")
            Text("The leader runs the game from their phone. These controls are for emergencies.")
                .font(.custom("Nunito", size: 13).weight(.bold)).foregroundStyle(NB.Palette.textDim)
            Spacer(minLength: 0)
        }
        .padding(24)
    }
}
