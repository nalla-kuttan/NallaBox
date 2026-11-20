import AppKit
import SwiftUI

enum DisplayChoice: Hashable {
    case screen(CGDirectDisplayID)
    case thisWindow
}

struct DisplayOption: Identifiable, Hashable {
    var id: DisplayChoice
    var name: String
    var detail: String
}

enum Displays {
    static func id(of s: NSScreen) -> CGDirectDisplayID {
        (s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    static func screen(_ id: CGDirectDisplayID) -> NSScreen? { NSScreen.screens.first { Self.id(of: $0) == id } }

    /// Every screen except the one showing the room window, then "This window, full screen".
    static func options(excluding host: NSScreen?) -> [DisplayOption] {
        let others = NSScreen.screens.filter { $0 != (host ?? NSScreen.main) }
        var out = others.map { s -> DisplayOption in
            let px = s.frame.size.applying(.init(scaleX: s.backingScaleFactor, y: s.backingScaleFactor))
            let builtIn = CGDisplayIsBuiltin(id(of: s)) != 0
            return DisplayOption(id: .screen(id(of: s)), name: s.localizedName,
                                 detail: builtIn ? "This Mac's screen" : "\(Int(px.width))×\(Int(px.height)) · recommended")
        }
        out.append(DisplayOption(id: .thisWindow, name: "This window, full screen", detail: "For a projector mirroring this Mac"))
        return out
    }
}

struct DisplayRow: View {
    var option: DisplayOption
    var selected: Bool
    var body: some View {
        HStack(spacing: 12) {
            Circle().strokeBorder(selected ? NB.Palette.coral : NB.Palette.inkLine, lineWidth: selected ? 5 : 2).frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(option.name).font(.custom("Nunito", size: 15).weight(.heavy))
                Text(option.detail).font(.custom("Nunito", size: 12).weight(.bold)).foregroundStyle(NB.Palette.textDim)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(selected ? NB.Palette.coral : .clear, lineWidth: 2))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
