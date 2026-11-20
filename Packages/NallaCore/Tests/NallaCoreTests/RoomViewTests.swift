import Foundation
import Testing
@testable import NallaCore

@Test func lobbyPayloads() throws {
    var h = Harness.three()
    h.s.joinURL = "http://192.168.1.20:8080/?room=BCDF&ws=8081"
    let tv = try h.tv().screen.data.decode(LobbyData.self)
    #expect(tv.code == "BCDF")
    #expect(tv.joinURL == "http://192.168.1.20:8080/?room=BCDF&ws=8081")
    #expect(tv.players.map(\.name) == ["Priya", "Sam", "Lena"])
    #expect(tv.leaderName == "Priya")
    #expect(tv.seats == 8)
    #expect(tv.canStart)
    #expect(h.tv().face.caption == "Three in. Room for five more.")
}

@Test func pickerPayload() throws {
    var h = Harness.three()
    h.leader(1, .previewGame(.test))
    let d = try h.phone(1).data.decode(PickerData.self)
    #expect(d.preview == .test)
    #expect(d.playerCount == 3)
    #expect(!d.games.contains { $0.id == .test })
    #expect(try h.tv().screen.data.decode(PickerData.self) == d)
}

@Test func howToPayload() throws {
    var h = Harness.three()
    h.leader(1, .pickGame(.test)); h.leader(1, .start)
    let d = try h.tv().screen.data.decode(HowToData.self)
    #expect(d.game.name == "Test Game")
    #expect(d.steps.count == 3)
    let job = try h.phone(1).data.decode(JobData.self)
    #expect(!job.job.isEmpty)
}

@Test func pausedPayloadForLeader() throws {
    var h = Harness.playing()
    h.leader(1, .pause)
    let mine = try h.phone(1).data.decode(PausedData.self)
    #expect(mine.byYou)
    #expect(mine.by == "Priya")
    #expect(try h.phone(2).data.decode(PausedData.self).byYou == false)
}

@Test func rankingSharesTies() {
    let players = [1, 2, 3, 4].map { Player(id: $0, name: "P\($0)", colour: .sky, seatToken: "", joinedAt: Double($0)) }
    let s = Results.standings(scores: [1: 500, 2: 900, 3: 500, 4: 0], deltas: [1: 100], players: players, leaderId: 1)
    #expect(s.map(\.player.id) == [2, 1, 3, 4])
    #expect(s.map(\.rank) == [1, 2, 2, 4])
    #expect(s[1].delta == 100)
}

@Test func roomInfoScores() {
    var h = Harness.playing()
    h.msg(1, .castVote(round: 1, choice: 0))
    #expect(Engine.roomInfo(h.s).players.first { $0.id == 1 }?.score == 100)
    #expect(Engine.roomInfo(h.s).game == .test)
}
