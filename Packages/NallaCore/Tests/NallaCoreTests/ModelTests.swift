import Foundation
import Testing
@testable import NallaCore

@Test func roomCodeAlphabet() {
    var rng = SplitMix64(seed: 7)
    for _ in 0..<1000 {
        let code = RoomCode.generate(using: &rng)
        #expect(code.count == 4)
        #expect(code.allSatisfy { RoomCode.alphabet.contains($0) })
        #expect(!code.contains { "AEIOULY".contains($0) })
    }
}

@Test func nameRules() {
    #expect(Names.normalize("  Priya  ") == "Priya")
    #expect(Names.normalize("Big   Sam") == "Big Sam")
    #expect(Names.normalize("   ") == nil)
    #expect(Names.normalize("") == nil)
    #expect(Names.normalize("Wolfgangster") == "Wolfgangster")
    #expect(Names.normalize("Wolfgangsters") == nil)
    #expect(Names.normalize("👩‍👩‍👧 Ana") == "👩‍👩‍👧 Ana")
    #expect(Names.normalize("שלום") == "שלום")
    #expect(Names.key("Zoë") == Names.key("zoe"))
    #expect(Names.key("PRIYA") == Names.key("priya"))
    #expect(Names.key("Sam") != Names.key("Sami"))
}

@Test func splitMixDeterministic() {
    var a = SplitMix64(seed: 42), b = SplitMix64(seed: 42)
    let xs = (0..<10).map { _ in a.next() }, ys = (0..<10).map { _ in b.next() }
    #expect(xs == ys)
    #expect(Set(xs).count == 10)
}

private struct Sample: Codable, Equatable {
    struct Inner: Codable, Equatable { var tags: [String]; var on: Bool }
    var name: String; var count: Int; var ratio: Double; var inner: Inner; var missing: String?
}

@Test func jsonValueRoundTrip() throws {
    let s = Sample(name: "x", count: 3, ratio: 0.5, inner: .init(tags: ["a", "b"], on: true), missing: nil)
    let v = JSONValue.encode(s)
    #expect(v["count"] == .number(3))
    #expect(v["inner"]?["on"] == .bool(true))
    #expect(try v.decode(Sample.self) == s)
}

@Test func timerMultipliers() {
    #expect(TimerSpeed.x1.multiplier == 1)
    #expect(TimerSpeed.x15.multiplier == 1.5)
    #expect(TimerSpeed.x2.multiplier == 2)
    #expect(TimerSpeed.off.multiplier == nil)
}
