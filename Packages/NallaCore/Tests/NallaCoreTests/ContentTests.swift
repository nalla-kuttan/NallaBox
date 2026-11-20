import Foundation
import Testing
@testable import NallaCore

@Test func pickWithoutRepeats() {
    var lib = Fixtures.library(passages: 3)
    lib.passages[1].family = true
    var used = Set<String>(), rng = SplitMix64(seed: 1)
    let picks = (0..<3).compactMap { _ in lib.pick(\.passages, familyOnly: false, used: &used, rng: &rng)?.id }
    #expect(Set(picks) == ["p1", "p2", "p3"])
    #expect(lib.pick(\.passages, familyOnly: false, used: &used, rng: &rng) == nil)

    var lib2 = Fixtures.library(passages: 3)
    lib2.passages[0].family = false
    var used2 = Set<String>()
    let family = (0..<3).compactMap { _ in lib2.pick(\.passages, familyOnly: true, used: &used2, rng: &rng)?.id }
    #expect(Set(family) == ["p3"])
}

@Test func validateFindsProblems() {
    var lib = Fixtures.library()
    lib.passages[0].answers = ["only one"]
    lib.questions[0].choices = ["a", "b"]
    lib.scenes[0].caption = String(repeating: "x", count: 49)
    lib.scenes[1].id = "s1"
    let problems = lib.validate()
    #expect(problems.contains { $0.contains("p1") })
    #expect(problems.contains { $0.contains("q1") })
    #expect(problems.contains { $0.contains("s1") })
    #expect(problems.count >= 4)
    #expect(Fixtures.library().validate() == [])
}

@Test func bundledContentValid() throws {
    let lib = try ContentLibrary.load(from: Fixtures.contentDir)
    #expect(lib.validate() == [])
    #expect(lib.passages.count >= 6)
    #expect(lib.scenes.count >= 6)
    #expect(lib.questions.count >= 6)
    #expect(lib.profanity.contains("oh shit"))
}
