import SwiftUI
import NallaCore

/// H5: host strip (code · players · TV, Pause, menu) over the host's own controller.
struct H5LiveRoom: View {
    var model: HostModel
    var display: ExternalDisplay
    @State private var showMenu = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.endpoint?.code ?? "····").font(.custom("Nunito", size: 20).weight(.black)).tracking(2.8).foregroundStyle(NB.Palette.coral)
                    Text("\(model.players.count) player\(model.players.count == 1 ? "" : "s") · \(display.name ?? "TV")")
                        .font(.custom("Nunito", size: 13).weight(.heavy)).foregroundStyle(NB.Palette.textDim).lineLimit(1)
                }
                Spacer()
                stripButton(model.paused ? "play.fill" : "pause.fill", label: model.paused ? "Resume" : "Pause") { model.send(model.paused ? .resume : .pause) }
                    .disabled(!model.inGame && !model.paused)
                stripButton("ellipsis", label: "Host menu") { showMenu = true }
            }
            .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(NB.Palette.inkLine).frame(height: 1) }
            if let url = model.localControllerURL {
                ControllerWebView(url: url).ignoresSafeArea(edges: .bottom)
            } else {
                Spacer()
            }
        }
        .background(NB.Palette.ink)
        .foregroundStyle(NB.Palette.text)
        .sheet(isPresented: $showMenu) {
            H6HostMenu(model: model).presentationDetents([.medium, .large]).presentationBackground(NB.Palette.inkRaised)
        }
    }

    private func stripButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15, weight: .black))
                .frame(minWidth: 44, minHeight: 44).padding(.horizontal, 4)
                .background(NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
