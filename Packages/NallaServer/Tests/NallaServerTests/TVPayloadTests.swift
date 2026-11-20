import Foundation
import Testing
@testable import NallaCore
@testable import NallaServer

/// The TV renderer decodes these payloads; this pins the contract between the hub and RoomScreens.swift.
@Test func roomScreensDecode() async throws {
    let clock = ManualClock()
    let hub = makeHub(clock)
    await hub.setJoinURL("http://10.0.0.2:8080/?room=BCDF&ws=8081")
    var tv = await hub.currentTV()
    #expect(tv.screen.screen == "T1")
    #expect(try tv.screen.data.decode(LobbyData.self).joinURL == "http://10.0.0.2:8080/?room=BCDF&ws=8081")
    #expect(tv.room.code == "BCDF")

    let (c, _) = await join(hub, "Priya", .saffron)
    await join(hub, "Sam", .sky); await join(hub, "Lena", .lilac)
    tv = await hub.currentTV()
    #expect(tv.screen.screen == "T2")
    #expect(try tv.screen.data.decode(LobbyData.self).players.count == 3)

    await hub.received(leaderJSON("preview_game", ["game": .string("test")]), from: c)
    tv = await hub.currentTV()
    #expect(tv.screen.screen == "T4")
    _ = try tv.screen.data.decode(PickerData.self)

    await hub.received(leaderJSON("pick_game", ["game": .string("test")]), from: c)
    tv = await hub.currentTV()
    #expect(tv.screen.screen == "T5")
    #expect(try tv.screen.data.decode(SettingsData.self).roundsLabel == "2 rounds")

    await hub.received(leaderJSON("start"), from: c)
    tv = await hub.currentTV()
    #expect(tv.screen.screen == "T6")
    #expect(tv.screen.deadline != nil)
    #expect(try tv.screen.data.decode(HowToData.self).steps.count == 3)

    await hub.received(leaderJSON("skip"), from: c)
    await hub.received(leaderJSON("end"), from: c)
    tv = await hub.currentTV()
    #expect(tv.screen.screen == "T10")
    let results = try tv.screen.data.decode(ResultsData.self)
    #expect(results.podium.count == 3)
    #expect(tv.face.state == .celebrate)
}
