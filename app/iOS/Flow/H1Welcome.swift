import SwiftUI

struct H1Welcome: View {
    var next: () -> Void
    var body: some View {
        PhoneScreen {
            Image("Symbol").resizable().frame(width: 120, height: 120).accessibilityHidden(true)
            Text("nallabox").font(.custom("Nunito", size: 34).weight(.black))
            Text("Turn any TV into a party").phoneTitle()
            VStack(spacing: 14) {
                point("📱", "Friends join with their phones")
                point("🚫", "No app or account for guests")
                point("📺", "Play on your TV with AirPlay or a cable")
            }
        } action: {
            PhoneButton(title: "Get started", action: next)
        }
    }

    private func point(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Text(icon).font(.system(size: 24)).accessibilityHidden(true)
            Text(text).font(NB.PhoneType.body.weight(.heavy)).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: NB.Radius.md, style: .continuous))
    }
}
