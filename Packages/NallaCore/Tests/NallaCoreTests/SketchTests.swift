import Foundation
import Testing
@testable import NallaCore

private func sketch(players: Int = 4, banned: Bool = false) -> Harness {
    var h = Harness()
    let names: [(String, PlayerColour)] = [("Priya", .saffron), ("Sam", .sky), ("Lena", .lilac), ("Dev", .teal), ("Aiko", .lime)]
    for (n, c) in names.prefix(players) { h.join(n, c) }
    h.leader(1, .pickGame(.sketch))
    h.leader(1, .setSettings(SettingsPatch(bannedWords: banned)))
    h.leader(1, .start)
    h.advance(15)
    return h
}

private func st(_ h: Harness) -> Sketch.State {
    guard case .playing(.sketch(let s)) = h.s.phase else { fatalError("not playing Sketch: \(h.s.phase)") }
    return s
}

private let line = Stroke(c: 1, s: 1, p: [0.1, 0.1, 0.5, 0.5, 0.9, 0.2])

/// Every artist draws one line and submits; returns at the pick.
private func drawAll(_ h: inout Harness, except skip: Set<PlayerID> = []) {
    if st(h).phase == .brief { h.advance(5) }
    for p in st(h).players where p != st(h).witness && !skip.contains(p) {
        h.msg(p, .strokeData(round: st(h).round, strokes: [line], final: true))
    }
    if st(h).phase == .draw { h.advance(30) }
}

private func number(_ h: Harness, artist: PlayerID) -> Int { st(h).drawings.first { $0.artist == artist }!.number }

@Test func witnessRotates() {
    var h = sketch()
    var witnesses: [PlayerID] = []
    while case .playing = h.s.phase {
        witnesses.append(st(h).witness)
        let r = st(h).round
        while case .playing = h.s.phase, st(h).round == r { h.advance(30) }
    }
    #expect(witnesses == [1, 2, 3, 4])
}

@Test func sceneOnlyInWitnessView() {
    var h = sketch()
    let caption = st(h).scene.caption, art = st(h).scene.art
    func leaks(_ v: JSONValue) -> Bool { v.jsonText.contains(caption) || v.jsonText.contains(art) }
    for _ in 0..<3 {   // brief, draw, pick
        if st(h).phase != .pick { #expect(leaks(h.phone(1).data)) }   // C3-witness shows only the drawings
        for p in [2, 3, 4] { #expect(!leaks(h.phone(p).data), "artist \(p) saw the scene in \(st(h).phase)") }
        #expect(!leaks(h.tv().screen.data), "TV showed the scene in \(st(h).phase)")
        if st(h).phase == .draw { drawAll(&h) } else { h.advance(5) }
    }
    #expect(st(h).phase == .pick)
    h.msg(1, .castVote(round: 1, choice: st(h).drawings[0].number))
    #expect(st(h).phase == .reveal)
    #expect(leaks(h.tv().screen.data))
    #expect(h.phone(1).screen == "C4")
    #expect(h.phone(2).screen == "C4")
}

@Test func strokePointCap() {
    var h = sketch()
    h.advance(5)
    let big = Stroke(c: 0, s: 0, p: (0..<5000).flatMap { i in [Double(i % 100) / 100, 0.5] })
    let bad = Stroke(c: 9, s: 0, p: [0.1, 0.1, 0.2, 0.2])
    let wild = Stroke(c: 2, s: 1, p: [-3, 0.5, 7, 0.5])
    h.msg(2, .strokeData(round: 1, strokes: [big, bad, wild], final: false))
    let stored = st(h).strokes[2] ?? []
    #expect(stored.map(\.pointCount).reduce(0, +) == 2000)
    #expect(!stored.contains { $0.c == 9 })
    #expect(stored.allSatisfy { $0.p.allSatisfy { (0...1).contains($0) } })
    h.msg(1, .strokeData(round: 1, strokes: [line], final: true))
    #expect(h.lastError == .notAllowed)
}

@Test func witnessOnlyPicks() {
    var h = sketch()
    drawAll(&h)
    #expect(st(h).phase == .pick)
    h.msg(2, .castVote(round: 1, choice: number(h, artist: 3)))
    #expect(h.lastError == .notAllowed)
    #expect(st(h).pick == nil)
    h.msg(1, .castVote(round: 1, choice: 99))
    #expect(h.lastError == .invalid)
}

@Test func sketchScoring() {
    var h = sketch()
    drawAll(&h)
    h.msg(1, .castVote(round: 1, choice: number(h, artist: 3)))
    #expect(st(h).deltas == [3: 1000, 1: 500])
    var late = sketch()
    drawAll(&late)
    late.advance(20)   // the Witness never picks
    #expect(st(late).phase == .reveal)
    #expect(st(late).deltas.isEmpty)
}

@Test func mostWantedNotOwn() {
    var h = sketch()
    drawAll(&h)
    h.msg(1, .castVote(round: 1, choice: number(h, artist: 2)))
    h.advance(8)
    #expect(st(h).phase == .mostWanted)
    h.msg(3, .castVote(round: 1, choice: number(h, artist: 3)))
    #expect(h.lastError == .notAllowed)
    for p in [1, 2, 3] { h.msg(p, .castVote(round: 1, choice: number(h, artist: 4))) }
    h.msg(4, .castVote(round: 1, choice: number(h, artist: 2)))
    #expect(st(h).phase == .scores)
    #expect(st(h).mostWantedTotal[4] == 3)
}

@Test func emptyDrawingsExcluded() {
    var h = sketch()
    drawAll(&h, except: [4])
    #expect(st(h).drawings.count == 2)
    #expect(!st(h).drawings.contains { $0.artist == 4 })
    #expect(h.phone(4).screen == "C3-artist")
    #expect(h.phone(4).data["number"] == nil)
}

@Test func earlyEndWhenAllArtistsDone() {
    var h = sketch()
    h.advance(5)
    for p in [2, 3] { h.msg(p, .strokeData(round: 1, strokes: [line], final: true)) }
    #expect(st(h).phase == .draw)
    h.msg(4, .strokeData(round: 1, strokes: [line], final: true))
    #expect(st(h).phase == .pick)
}

@Test func sketchAwards() {
    var h = sketch(players: 3)
    while case .playing = h.s.phase {
        drawAll(&h)
        let w = st(h).witness
        let artists = st(h).players.filter { $0 != w }
        // Every Witness picks the lower-numbered artist; everyone calls Lena's (3) drawing the worst when they can.
        let favourite = artists.min()!
        h.msg(w, .castVote(round: st(h).round, choice: number(h, artist: favourite)))
        h.advance(8)
        for p in st(h).players {
            let target = p == 3 || w == 3 ? artists.first { $0 != p }! : 3
            h.msg(p, .castVote(round: st(h).round, choice: number(h, artist: target)))
        }
        h.advance(6)
    }
    guard case .results(let r) = h.s.phase else { Issue.record("no results"); return }
    #expect(r.rounds == 3)
    #expect(r.awards.first { $0.title == "Most Wanted" }?.player.name == "Lena")
    #expect(r.awards.contains { $0.title == "Sharpest Pencil" })
}

@Test func bannedWordsSetting() throws {
    var on = sketch(banned: true)
    #expect(try on.phone(1).data.decode(C1WitnessPhone.self).banned == ["raccoon", "tuxedo", "bread"])
    let off = sketch(banned: false)
    #expect(try off.phone(1).data.decode(C1WitnessPhone.self).banned == nil)
    #expect(on.phone(2).screen == "C1-artist")
    on.advance(5)
    #expect(on.phone(1).screen == "C2-witness")
    #expect(on.phone(2).screen == "C2-artist")
}

@Test func drawingPhoneDoesNotChangeWhenOthersFinish() {
    var h = sketch()
    h.advance(5)
    let before = h.phone(2)
    h.msg(3, .strokeData(round: 1, strokes: [line], final: true))
    #expect(h.phone(2) == before)   // an unchanged view isn't re-sent, so a stroke in progress isn't interrupted
}
