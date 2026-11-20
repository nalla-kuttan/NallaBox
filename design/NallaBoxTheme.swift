// NallaBoxTheme.swift — design tokens for the NallaBox host app (spec §9).
// Mirrors design/mockups/shared/tokens.css; tests/design/test_tokens.py checks the colours match.
//
// Font: add design/mockups/shared/fonts/Nunito[wght].ttf to the app target and register it:
//   iOS:   Info.plist  UIAppFonts = ["Nunito[wght].ttf"]
//   macOS: Info.plist  ATSApplicationFontsPath = "."  (font in the bundle's Resources)
// The variable font registers as the family "Nunito"; weights come from .weight(_:).

import SwiftUI

extension Color {
    /// Colour from a 0xRRGGBB literal.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum NB {
    // MARK: Colour (§9.1)
    enum Palette {
        static let ink = Color(hex: 0x1E1B2E)
        static let inkRaised = Color(hex: 0x2B2742)
        static let inkLine = Color(hex: 0x3A3556)
        static let coral = Color(hex: 0xFF5C39)
        static let coralPress = Color(hex: 0xE54826)
        static let text = Color(hex: 0xFFFFFF)
        static let textDim = Color(hex: 0xB9B4CF)
        static let success = Color(hex: 0x4ED19A)
        static let danger = Color(hex: 0xFF6B7A)
        static let paper = Color(hex: 0xFFF4EA)
    }

    /// Player avatar colours. Coral is reserved for the system and is never a player colour.
    enum PlayerColor: String, CaseIterable, Identifiable {
        case saffron, sky, mint, lilac, pink, lime, teal, sand
        var id: String { rawValue }
        var color: Color {
            switch self {
            case .saffron: return Color(hex: 0xFFB020)
            case .sky: return Color(hex: 0x3DB7FF)
            case .mint: return Color(hex: 0x4ED19A)
            case .lilac: return Color(hex: 0xB58CFF)
            case .pink: return Color(hex: 0xFF7AB6)
            case .lime: return Color(hex: 0xC6E85A)
            case .teal: return Color(hex: 0x2EC4B6)
            case .sand: return Color(hex: 0xE9D8B4)
            }
        }
    }

    // MARK: Type (§9.2) — sizes in points on the 1920×1080 TV canvas / 393-pt phone
    private static func nunito(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        Font.custom("Nunito", size: size).weight(weight)
    }

    enum TVType {
        static let display = nunito(120, .black)
        static let title = nunito(72, .black)
        static let heading = nunito(52, .heavy)
        static let body = nunito(40, .bold)
        static let label = nunito(32, .heavy)      // use with .textCase(.uppercase) and .tracking(labelTracking)
        static let caption = nunito(36, .bold)
        static let labelTracking: CGFloat = 1
    }

    enum PhoneType {
        static let display = nunito(40, .black)
        static let title = nunito(28, .heavy)
        static let heading = nunito(22, .heavy)
        static let body = nunito(17, .bold)
        static let label = nunito(13, .heavy)      // use with .textCase(.uppercase)
        static let caption = nunito(15, .semibold)
        static let labelTracking: CGFloat = 0
    }

    // MARK: Spacing, radii, layout (§9.3)
    enum Space {
        /// 4-pt grid: s(4) == 16.
        static func s(_ n: Int) -> CGFloat { CGFloat(n) * 4 }
        static let tvGutter: CGFloat = 96
        static let tvSection: CGFloat = 48
        static let phoneMargin: CGFloat = 20
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 22
        static let xl: CGFloat = 32
        /// Avatars: 30% of their side, echoing the logo body.
        static func avatar(_ side: CGFloat) -> CGFloat { side * 0.3 }
    }

    static let tvCanvas = CGSize(width: 1920, height: 1080)
    static let tvSafeInset: CGFloat = 80
    static let faceSize: CGFloat = 160
    static let phoneActionHeight: CGFloat = 56
    static let tapMin: CGFloat = 44

    // MARK: Motion (§9.6)
    enum Motion {
        static let tap: Double = 0.15
        static let screen: Double = 0.25
        static let reveal: Double = 0.4
        static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
        /// Face state change: squash to 0.9 and settle over 0.18 s.
        static let faceSwap: Double = 0.18
    }
}
