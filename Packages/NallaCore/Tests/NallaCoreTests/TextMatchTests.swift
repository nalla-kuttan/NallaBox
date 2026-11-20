import Testing
@testable import NallaCore

@Test func tooClose() {
    #expect(TextMatch.isTooClose("Banana", to: "banana"))
    #expect(TextMatch.isTooClose("café", to: "cafe"))
    #expect(TextMatch.isTooClose("laundromat", to: "laundromats"))
    #expect(TextMatch.isTooClose("boxes", to: "box"))
    #expect(TextMatch.isTooClose("cat", to: "cut"))
    #expect(TextMatch.isTooClose("  Haunted, Laundromat! ", to: "haunted laundromat"))
    #expect(!TextMatch.isTooClose("cat", to: "dog"))
    #expect(!TextMatch.isTooClose("haunted laundromat", to: "laundromat"))
}

@Test func foldAndDistance() {
    #expect(TextMatch.fold("  Crème   Brûlée!! ") == "creme brulee")
    #expect(TextMatch.editDistance("kitten", "sitting") == 3)
    #expect(TextMatch.editDistance("", "abc") == 3)
}

@Test func nearDuplicate() {
    #expect(TextMatch.isNearDuplicate(["Pickled eggs"], ["pickled egg"]))
    #expect(!TextMatch.isNearDuplicate(["pickled eggs", "a goose"], ["pickled egg", "the mayor"]))
    #expect(!TextMatch.isNearDuplicate(["one"], ["one", "two"]))
}

@Test func profanity() {
    let f = ProfanityFilter(words: ["shit", "damn"])
    #expect(f.contains("what the shit"))
    #expect(f.contains("SHIT!"))
    #expect(f.contains("well dämn"))
    #expect(!f.contains("Scunthorpe"))
    #expect(!f.contains("shiitake mushrooms"))
}

@Test func segments() {
    #expect(PassageText.segments("A {1} in a {2}.") == [.text("A "), .blank(1), .text(" in a "), .blank(2), .text(".")])
    #expect(PassageText.segments("{1} ate it") == [.blank(1), .text(" ate it")])
    #expect(PassageText.blankCount("A {1} and {2} and {3}") == 3)
    #expect(PassageText.fill("A {1} in a {2}.", with: ["goose", "bank"]) == "A goose in a bank.")
}
