import Foundation

public enum Names {
    public static let maxLength = 12

    /// Trims, drops control characters and collapses whitespace. Nil when empty or longer than 12 grapheme clusters.
    public static func normalize(_ raw: String) -> String? {
        let cleaned = String(String.UnicodeScalarView(raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) || $0 == "\u{200D}" }))
        let words = cleaned.split(whereSeparator: { $0.isWhitespace })
        let name = words.joined(separator: " ")
        guard !name.isEmpty, name.count <= maxLength else { return nil }
        return name
    }

    /// Case- and accent-insensitive key, so "Zoë" and "zoe" count as the same name.
    public static func key(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
