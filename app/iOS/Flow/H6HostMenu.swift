import SwiftUI
import NallaCore

/// H6: host controls sheet with confirm steps for remove and end.
struct H6HostMenu: View {
    @Bindable var model: HostModel
    @Environment(\.dismiss) private var dismiss
    @State private var page: Page = .menu

    enum Page: Equatable { case menu, remove, confirmRemove(PlayerSummary), confirmEnd }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch page {
            case .menu:
                title("Host controls")
                item(model.paused ? "Resume game" : "Pause game", symbol: model.paused ? "play.fill" : "pause.fill") { model.send(model.paused ? .resume : .pause); dismiss() }
                    .disabled(!model.inGame && !model.paused)
                item("Skip this round", symbol: "forward.end.fill") { model.send(.skip); dismiss() }.disabled(!model.inGame)
                item("Remove a player ›", symbol: "person.2.fill") { page = .remove }
                HStack {
                    Text("Family-friendly").font(NB.PhoneType.body.weight(.heavy))
                    Spacer()
                    Toggle("Family-friendly", isOn: $model.prefs.familyFriendly).labelsHidden().tint(NB.Palette.coral)
                }
                .padding(.horizontal, 14).frame(minHeight: 52)
                .background(NB.Palette.ink, in: RoundedRectangle(cornerRadius: NB.Radius.md, style: .continuous))
                item("End session", symbol: "stop.fill", danger: true) { page = .confirmEnd }
            case .remove:
                title("Remove a player")
                ForEach(model.players.filter { $0.id != 1 }) { p in
                    HStack(spacing: 14) {
                        TVAvatar(name: p.name, colour: p.colour, size: 32)
                        Text(p.name).font(NB.PhoneType.body.weight(.heavy)).lineLimit(1)
                        Spacer()
                        Button("Remove") { page = .confirmRemove(p) }
                            .font(NB.PhoneType.caption.weight(.heavy)).padding(.horizontal, 12).frame(minHeight: 44)
                            .background(NB.Palette.danger, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(.white)
                            .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14).frame(minHeight: 52)
                    .background(NB.Palette.ink, in: RoundedRectangle(cornerRadius: NB.Radius.md, style: .continuous))
                }
                Text("They can join again with the room code.").font(NB.PhoneType.caption).foregroundStyle(NB.Palette.textDim)
            case .confirmRemove(let p):
                title("Remove \(p.name) from the room?")
                Text("\(p.name) leaves the game now. They can join again with the room code.").phoneBodyDim()
                PhoneButton(title: "Remove \(p.name)", kind: .destructive) { model.send(.removePlayer(p.id)); dismiss() }
                PhoneButton(title: "Cancel", kind: .secondary) { page = .menu }
            case .confirmEnd:
                title("End the session?")
                Text("The game stops for all \(model.players.count) players and the room closes. Scores so far are shown on the TV.").phoneBodyDim()
                PhoneButton(title: "End session", kind: .destructive) { model.send(.endSession); dismiss() }
                PhoneButton(title: "Keep playing", kind: .secondary) { page = .menu }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, NB.Space.phoneMargin).padding(.top, 24)
        .foregroundStyle(NB.Palette.text)
    }

    private func title(_ s: String) -> some View { Text(s).font(NB.PhoneType.heading.weight(.black)) }

    private func item(_ s: String, symbol: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(s, systemImage: symbol).font(NB.PhoneType.body.weight(.heavy)).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .padding(.horizontal, 14)
                .background(NB.Palette.ink, in: RoundedRectangle(cornerRadius: NB.Radius.md, style: .continuous))
                .foregroundStyle(danger ? NB.Palette.danger : NB.Palette.text)
        }
        .buttonStyle(.plain)
    }
}
