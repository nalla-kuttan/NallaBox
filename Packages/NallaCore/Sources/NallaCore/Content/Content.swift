import Foundation

public protocol ContentItem: Sendable {
    var id: String { get }
    var family: Bool { get }
}

/// A Redacted passage. `text` holds numbered blanks `{1}`…`{3}`; `answers[i]` is the real word for blank i+1.
public struct Passage: Codable, Equatable, Sendable, ContentItem {
    public var id: String
    public var text: String
    public var answers: [String]
    public var family: Bool
    public init(id: String, text: String, answers: [String], family: Bool) {
        self.id = id; self.text = text; self.answers = answers; self.family = family
    }
}

/// A Composite Sketch scene: caption plus an emoji composition (or an image name once illustrations exist).
public struct Scene: Codable, Equatable, Sendable, ContentItem {
    public var id: String
    public var caption: String
    public var art: String
    public var image: String?
    public var banned: [String]
    public var family: Bool
    public init(id: String, caption: String, art: String, image: String?, banned: [String], family: Bool) {
        self.id = id; self.caption = caption; self.art = art; self.image = image; self.banned = banned; self.family = family
    }
}

/// An Insider Trading question with four choices; `answer` is the index of the correct one.
public struct Question: Codable, Equatable, Sendable, ContentItem {
    public var id: String
    public var text: String
    public var choices: [String]
    public var answer: Int
    public var family: Bool
    public init(id: String, text: String, choices: [String], answer: Int, family: Bool) {
        self.id = id; self.text = text; self.choices = choices; self.answer = answer; self.family = family
    }
}

public struct ContentLibrary: Sendable, Equatable {
    public var passages: [Passage]
    public var scenes: [Scene]
    public var questions: [Question]
    public var profanity: ProfanityFilter

    public init(passages: [Passage], scenes: [Scene], questions: [Question], profanity: ProfanityFilter) {
        self.passages = passages; self.scenes = scenes; self.questions = questions; self.profanity = profanity
    }

    public static let empty = ContentLibrary(passages: [], scenes: [], questions: [], profanity: ProfanityFilter(words: []))

    /// Loads redacted.json, sketch.json, insider.json (JSON arrays) and profanity.txt from one folder.
    public static func load(from dir: URL) throws -> ContentLibrary {
        let dec = JSONDecoder()
        func read<T: Decodable>(_ name: String) throws -> T {
            try dec.decode(T.self, from: Data(contentsOf: dir.appendingPathComponent(name)))
        }
        return ContentLibrary(passages: try read("redacted.json"), scenes: try read("sketch.json"),
                              questions: try read("insider.json"),
                              profanity: try ProfanityFilter(contentsOf: dir.appendingPathComponent("profanity.txt")))
    }

    /// Human-readable problems; empty means the packs are valid.
    public func validate() -> [String] {
        var problems: [String] = []
        func dupes(_ ids: [String], _ kind: String) {
            for (id, n) in Dictionary(grouping: ids, by: { $0 }).mapValues(\.count) where n > 1 {
                problems.append("\(kind) id \(id) is used \(n) times")
            }
        }
        dupes(passages.map(\.id), "passage"); dupes(scenes.map(\.id), "scene"); dupes(questions.map(\.id), "question")
        for p in passages {
            let blanks = PassageText.blankCount(p.text)
            if !(1...3).contains(blanks) { problems.append("\(p.id): \(blanks) blanks (need 1–3)") }
            if blanks != p.answers.count { problems.append("\(p.id): \(blanks) blanks but \(p.answers.count) answers") }
            let numbers = PassageText.segments(p.text).compactMap { if case .blank(let n) = $0 { return n }; return nil }
            if !numbers.isEmpty, numbers != Array(1...numbers.count) { problems.append("\(p.id): blanks must be {1}…{n} in order") }
            for a in p.answers where a.isEmpty || a.count > 24 { problems.append("\(p.id): answer \"\(a)\" must be 1–24 characters") }
            if p.family, p.answers.contains(where: profanity.contains) { problems.append("\(p.id): family passage has a profane answer") }
        }
        for s in scenes {
            if s.caption.isEmpty || s.caption.count > 48 { problems.append("\(s.id): caption must be 1–48 characters") }
            if s.art.isEmpty && s.image == nil { problems.append("\(s.id): needs art or an image") }
        }
        for q in questions {
            if q.choices.count != 4 { problems.append("\(q.id): needs 4 choices, has \(q.choices.count)") }
            if !(0...3).contains(q.answer) { problems.append("\(q.id): answer index \(q.answer) out of range") }
            if Set(q.choices.map(TextMatch.fold)).count != q.choices.count { problems.append("\(q.id): duplicate choices") }
        }
        return problems
    }

    /// Picks an unused item at random, honouring family-friendly, and marks it used. Nil when none are left.
    public func pick<T: ContentItem>(_ kp: KeyPath<ContentLibrary, [T]>, familyOnly: Bool,
                                     used: inout Set<String>, rng: inout SplitMix64) -> T? {
        let pool = self[keyPath: kp].filter { !used.contains($0.id) && (!familyOnly || $0.family) }
        guard let item = pool.randomElement(using: &rng) else { return nil }
        used.insert(item.id)
        return item
    }
}
