import SwiftUI

/// M1: logo, local network status, "Show game on" display picker, Start room.
struct M1StartView: View {
    var model: HostModel
    var options: [DisplayOption]
    @Binding var choice: DisplayChoice
    var start: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image("Symbol").resizable().frame(width: 96, height: 96)
            Text("Start a party room").font(.custom("Nunito", size: 32).weight(.black))
            HStack(spacing: 8) {
                Circle().fill(NB.Palette.success).frame(width: 10, height: 10)
                Text("Local network on").font(.custom("Nunito", size: 13).weight(.heavy)).foregroundStyle(NB.Palette.textDim)
            }
            Text("Show the game on").font(.custom("Nunito", size: 12).weight(.heavy)).textCase(.uppercase).foregroundStyle(NB.Palette.textDim)
            VStack(spacing: 8) {
                ForEach(options) { o in
                    DisplayRow(option: o, selected: o.id == choice).onTapGesture { choice = o.id }
                }
            }
            .frame(width: 460)
            if let e = model.lastError { Text(e).foregroundStyle(NB.Palette.danger).font(.custom("Nunito", size: 13).weight(.bold)) }
            Button(action: start) {
                Text("Start room").font(.custom("Nunito", size: 17).weight(.heavy)).frame(width: 460, height: 56)
                    .background(NB.Palette.coral, in: RoundedRectangle(cornerRadius: NB.Radius.md, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .foregroundStyle(NB.Palette.text)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NB.Palette.ink)
    }
}
