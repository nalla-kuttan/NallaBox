import SwiftUI
import NallaCore

/// H4: the host's name and colour; they become player 1 and the leader.
struct H4Name: View {
    @Binding var name: String
    @Binding var colour: String
    var open: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        PhoneScreen(center: false) {
            Text("What should we call you?").phoneTitle()
            Text("You're player 1 and the leader. You'll play right here on this iPhone.").phoneBodyDim()
            VStack(alignment: .leading, spacing: 6) {
                Text("Your name").font(NB.PhoneType.label).textCase(.uppercase).foregroundStyle(NB.Palette.textDim)
                TextField("Up to 12 letters", text: $name)
                    .font(NB.PhoneType.body.weight(.heavy))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .padding(.horizontal, 16).frame(minHeight: 52)
                    .background(NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: NB.Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: NB.Radius.md).strokeBorder(focused ? NB.Palette.coral : NB.Palette.inkLine, lineWidth: 2))
                    .onChange(of: name) { if name.count > 12 { name = String(name.prefix(12)) } }
                HStack { Spacer(); Text("\(name.count)/12").font(NB.PhoneType.caption).foregroundStyle(NB.Palette.textDim) }
            }
            Text("Pick a colour").font(NB.PhoneType.label).textCase(.uppercase).foregroundStyle(NB.Palette.textDim)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(PlayerColour.allCases, id: \.self) { c in
                    Button { colour = c.rawValue } label: {
                        RoundedRectangle(cornerRadius: 22, style: .continuous).fill(c.color)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if colour == c.rawValue {
                                    Text("✓").font(.system(size: 24, weight: .black)).foregroundStyle(NB.Palette.ink)
                                    RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white, lineWidth: 4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(c.rawValue)
                    .accessibilityAddTraits(colour == c.rawValue ? .isSelected : [])
                }
            }
        } action: {
            PhoneButton(title: "Open the room", disabledReason: Names.normalize(name) == nil ? "Enter your name to open the room" : nil, action: open)
        }
    }
}
