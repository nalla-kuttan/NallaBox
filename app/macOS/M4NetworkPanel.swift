import AppKit
import SwiftUI

/// M4: shown in the room window's side column when phones can't connect.
struct M4NetworkPanel: View {
    var joinURL: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Phones can't connect?").font(.custom("Nunito", size: 16).weight(.black))
            VStack(alignment: .leading, spacing: 6) {
                Text("1. Phones must be on the same Wi-Fi as this Mac.")
                Text("2. Guest and office Wi-Fi often block phones from reaching each other.")
                Text("3. Check the macOS firewall allows NallaBox.")
                Text("4. Still stuck? Share this Mac's connection, or use an iPhone hotspot.")
            }
            .font(.custom("Nunito", size: 14).weight(.bold)).foregroundStyle(NB.Palette.textDim)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(joinURL, forType: .string)
            } label: {
                Text("Copy join link · \(JoinColumn.short(joinURL) ?? joinURL)").font(.custom("Nunito", size: 13).weight(.heavy))
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(NB.Palette.ink, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .leading) { Rectangle().fill(NB.Palette.danger).frame(width: 4) }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
