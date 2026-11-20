import SwiftUI

/// H3: AirPlay route picker or cable; Continue once an external display is attached.
struct H3ConnectTV: View {
    var display: ExternalDisplay
    var next: () -> Void

    var body: some View {
        PhoneScreen {
            if display.isConnected {
                TVArt(glyph: "✓", on: true)
                Text("Connected to \(display.name ?? "your TV")").phoneTitle().padding(.top, 20)
                Text("You should see the NallaBox lobby on the TV now.").phoneBodyDim()
            } else {
                TVArt(glyph: "📺")
                Text("Put the game on your TV").phoneTitle().padding(.top, 20)
                Text("Pick your TV in AirPlay, or plug in an HDMI adapter. Your iPhone stays your controller.").phoneBodyDim()
            }
            routeButton
        } action: {
            PhoneButton(title: "Continue", disabledReason: display.isConnected ? nil : "Connect a TV to continue", action: next)
        }
        .onAppear { display.refreshName() }
    }

    private var routeButton: some View {
        HStack(spacing: 12) {
            Image(systemName: "airplayvideo").accessibilityHidden(true)
            Text(display.isConnected ? (display.name ?? "TV") : "Choose AirPlay display").font(NB.PhoneType.body.weight(.heavy))
            Spacer()
            Text(display.isConnected ? "✓ AirPlay" : "›").font(NB.PhoneType.body.weight(.heavy))
                .foregroundStyle(display.isConnected ? NB.Palette.success : NB.Palette.textDim)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: NB.Radius.md, style: .continuous))
        // The real system picker sits on top, nearly invisible, so a tap opens the AirPlay menu.
        .overlay { RoutePicker(invisible: true) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the AirPlay menu")
    }
}
