import Foundation

/// Built-in word list, matched on whole folded words so "Scunthorpe" stays clean.
public struct ProfanityFilter: Equatable, Sendable {
    public let words: Set<String>

    public init(words: [String]) {
        self.words = Set(words.map(TextMatch.fold).filter { !$0.isEmpty })
    }

    public init(contentsOf url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        self.init(words: text.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.hasPrefix("#") })
    }

    public func contains(_ text: String) -> Bool {
        let folded = TextMatch.fold(text)
        let tokens = folded.split(separator: " ").map(String.init)
        if tokens.contains(where: words.contains) { return true }
        // Multi-word entries ("son of a bitch") match as a phrase on word boundaries.
        let padded = " \(folded) "
        return words.contains { $0.contains(" ") && padded.contains(" \($0) ") }
    }
}
