import Foundation

public enum TextMatch {
    /// Lowercase, no diacritics or punctuation, single spaces.
    public static func fold(_ s: String) -> String {
        let folded = s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        let kept = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    /// Levenshtein distance over characters.
    public static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count), cur = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }

    private static func singular(_ s: String) -> String {
        if s.hasSuffix("es"), s.count > 3 { return String(s.dropLast(2)) }
        if s.hasSuffix("s"), s.count > 2 { return String(s.dropLast()) }
        return s
    }

    /// A guess counts as the real answer when it folds to the same text, is one edit away,
    /// or matches after dropping a plural s/es.
    public static func isTooClose(_ guess: String, to real: String) -> Bool {
        let g = fold(guess), r = fold(real)
        if g == r || editDistance(g, r) <= 1 { return true }
        let gs = singular(g), rs = singular(r)
        return gs == rs || gs == r || g == rs
    }

    /// Two answer sets are the same fake when every field pair is too close.
    public static func isNearDuplicate(_ a: [String], _ b: [String]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { isTooClose($0, to: $1) }
    }
}

public enum Segment: Codable, Equatable, Sendable {
    case text(String), blank(Int)

    private enum Keys: String, CodingKey { case text, blank }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        if let n = try c.decodeIfPresent(Int.self, forKey: .blank) { self = .blank(n) }
        else { self = .text(try c.decode(String.self, forKey: .text)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .text(let t): try c.encode(t, forKey: .text)
        case .blank(let n): try c.encode(n, forKey: .blank)
        }
    }
}

/// Passage text with numbered blanks `{1}`…`{3}`.
public enum PassageText {
    public static func segments(_ text: String) -> [Segment] {
        var out: [Segment] = [], buffer = "", i = text.startIndex
        while i < text.endIndex {
            if text[i] == "{", let close = text[i...].firstIndex(of: "}"),
               let n = Int(text[text.index(after: i)..<close]) {
                if !buffer.isEmpty { out.append(.text(buffer)); buffer = "" }
                out.append(.blank(n))
                i = text.index(after: close)
            } else {
                buffer.append(text[i]); i = text.index(after: i)
            }
        }
        if !buffer.isEmpty { out.append(.text(buffer)) }
        return out
    }

    public static func blankCount(_ text: String) -> Int {
        segments(text).filter { if case .blank = $0 { return true }; return false }.count
    }

    public static func fill(_ text: String, with fills: [String]) -> String {
        segments(text).map {
            switch $0 {
            case .text(let t): t
            case .blank(let n): n - 1 < fills.count ? fills[n - 1] : "____"
            }
        }.joined()
    }
}
