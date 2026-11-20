import Foundation
@testable import NallaCore

enum Fixtures {
    /// The repository's bundled content folder, found from this file's path.
    static var contentDir: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()   // NallaCoreTests
            .deletingLastPathComponent().deletingLastPathComponent()  // Tests, NallaCore
            .deletingLastPathComponent().deletingLastPathComponent()  // Packages, repo root
            .appendingPathComponent("app/Resources/Content")
    }

    static func library(passages: Int = 6, scenes: Int = 6, questions: Int = 6) -> ContentLibrary {
        ContentLibrary(
            passages: (1...max(passages, 1)).prefix(passages).map {
                Passage(id: "p\($0)", text: "The mayor of Leeds was found hiding in a {1} with {2}.",
                        answers: ["laundromat", "a goose"], family: $0 != 2)
            },
            scenes: (1...max(scenes, 1)).prefix(scenes).map {
                Scene(id: "s\($0)", caption: "A raccoon in a tuxedo buys bread", art: "🦝🤵🥖🏪", image: nil,
                      banned: ["raccoon", "tuxedo", "bread"], family: true)
            },
            questions: (1...max(questions, 1)).prefix(questions).map {
                Question(id: "q\($0)", text: "Which planet has the most known moons?",
                         choices: ["Jupiter", "Saturn", "Uranus", "Neptune"], answer: 1, family: true)
            },
            profanity: ProfanityFilter(words: ["shit", "damn"]))
    }
}
