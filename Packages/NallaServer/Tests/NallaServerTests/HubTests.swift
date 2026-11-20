import Foundation
import Testing
@testable import NallaCore
@testable import NallaServer

@Test func joinGetsWelcomeThenView() async {
    let hub = makeHub()
    let (_, box) = await join(hub, "Priya", .saffron)
    let m = box.messages
    guard m.count >= 2, case .welcome(1, let token) = m[0], case .view(let v) = m[1] else {
        Issue.record("unexpected \(box.texts)"); return
    }
    #expect(token.count == 32)
    #expect(v.screen == "P4")
    #expect(v.version == 1)
    #expect(v.you.isLeader)
}

@Test func notJoinedRejected() async {
    let hub = makeHub()
    let (c, box) = await connect(hub)
    await hub.received(#"{"v":1,"type":"submit_text","id":"1","round":1,"fields":["x"]}"#, from: c)
    #expect(box.errors == [.notJoined])
}

@Test func versionsIncrease() async {
    let hub = makeHub()
    let (c1, b1) = await join(hub, "Priya", .saffron)
    await join(hub, "Sam", .sky)
    await hub.received(#"{"v":1,"type":"ping","id":"p","t":1}"#, from: c1)
    await join(hub, "Lena", .lilac)
    #expect(b1.views.map(\.version) == [1, 2, 3])
    #expect(b1.messages.contains { if case .pong(1, _) = $0 { return true }; return false })
}

@Test func secondConnectionTakesSeat() async {
    let hub = makeHub()
    let (_, first) = await join(hub, "Priya", .saffron)
    guard case .welcome(_, let token)? = first.messages.first else { Issue.record("no welcome"); return }
    let (_, second) = await join(hub, "Priya", .saffron, token: token)
    #expect(first.texts.contains(#"{"reason":"replaced","type":"removed","v":1}"#))
    #expect(first.closed)
    #expect(second.lastView?.you.id == 1)
    #expect(await hub.room().players.count == 1)
}

@Test func malformedMessages() async {
    let hub = makeHub()
    let (c, box) = await join(hub, "Priya", .saffron)
    await hub.received("{", from: c)
    await hub.received(#"{"v":1,"type":"nope","id":"1"}"#, from: c)
    await hub.received(#"{"v":9,"type":"ping","id":"2","t":1}"#, from: c)
    #expect(box.errors == [.badMessage, .badMessage, .wrongVersion])
    await hub.received(leaderJSON("preview_game", ["game": .string("test")]), from: c)
    #expect(box.lastView?.screen == "P5")
}

@Test func rateLimitedJoins() async {
    let hub = makeHub()
    let (c, box) = await connect(hub, ip: "10.0.0.9")
    for i in 0..<11 { await hub.received(joinJSON("P\(i)", .sky, room: "ZZZZ", id: "\(i)"), from: c) }
    #expect(box.errors.filter { $0 == .wrongCode }.count == 10)
    #expect(box.errors.last == .rateLimited)
    let (_, other) = await join(hub, "Sam", .sky, ip: "10.0.0.8")
    #expect(other.lastView?.screen == "P4")
}

@Test func timerTicks() async {
    let clock = ManualClock()
    let hub = makeHub(clock)
    let (c, box) = await join(hub, "Priya", .saffron)
    await join(hub, "Sam", .sky); await join(hub, "Lena", .lilac)
    await hub.received(leaderJSON("pick_game", ["game": .string("test")]), from: c)
    await hub.received(leaderJSON("start"), from: c)
    #expect(box.lastView?.screen == "P7")
    await clock.advance(by: 15)
    #expect(await eventually { box.lastView?.screen == "X1" })
    #expect(box.lastView?.data["phase"] == .string("input"))
    await clock.advance(by: 10)
    #expect(await eventually { box.lastView?.data["phase"] == .string("fixed") })
}

@Test func playersVoteThroughHub() async {
    let hub = makeHub()
    let (c1, b1) = await join(hub, "Priya", .saffron)
    let (c2, _) = await join(hub, "Sam", .sky)
    let (c3, _) = await join(hub, "Lena", .lilac)
    await hub.received(leaderJSON("pick_game", ["game": .string("test")]), from: c1)
    await hub.received(leaderJSON("start"), from: c1)
    await hub.received(leaderJSON("skip"), from: c1)
    for c in [c1, c2, c3] { await hub.received(voteJSON(round: 1, choice: 0), from: c) }
    #expect(b1.lastView?.data["phase"] == .string("fixed"))
    #expect(b1.lastView?.you.score == 100)
    #expect(b1.messages.contains(.ack(id: "v")))
}

@Test func disconnectShowsBannerAndRejoinClears() async {
    let hub = makeHub()
    let (c1, _) = await join(hub, "Priya", .saffron)
    let (c2, b2) = await join(hub, "Sam", .sky)
    await join(hub, "Lena", .lilac)
    await hub.received(leaderJSON("pick_game", ["game": .string("test")]), from: c1)
    await hub.received(leaderJSON("start"), from: c1)
    await hub.closed(c2)
    #expect(await hub.currentTV().overlays.reconnecting.map(\.player.name) == ["Sam"])
    guard case .welcome(_, let token)? = b2.messages.first else { Issue.record("no welcome"); return }
    let (_, again) = await join(hub, "Sam", .sky, token: token)
    #expect(again.lastView?.screen == "P7")
    #expect(await hub.currentTV().overlays.reconnecting.isEmpty)
}

@Test func kickClosesConnection() async {
    let hub = makeHub()
    await join(hub, "Priya", .saffron)
    let (_, b2) = await join(hub, "Sam", .sky)
    await hub.host(.removePlayer(2))
    #expect(b2.messages.last == .removed(.byHost))
    #expect(b2.closed)
}

@Test func hostSeatToken() async {
    let hub = makeHub()
    let token = await hub.reserveHostSeat(name: "Priya", colour: .saffron)
    await join(hub, "Sam", .sky)
    let (_, box) = await join(hub, "x", .mint, token: token)
    #expect(box.lastView?.you.isHost == true)
    #expect(box.lastView?.you.isLeader == true)
}

@Test func snapshotsStream() async {
    let hub = makeHub()
    let stream = await hub.events()
    let screens = Task { () -> [String] in
        var out: [String] = []
        for await e in stream {
            if case .snapshot(let tv) = e { out.append(tv.screen.screen) }
            if out.count == 2 { break }
        }
        return out
    }
    await join(hub, "Priya", .saffron)
    #expect(await screens.value == ["T1", "T2"])
}

@Test func joinURLReachesTV() async throws {
    let hub = makeHub()
    await hub.setJoinURL("http://10.0.0.2:8080/?room=BCDF&ws=8081")
    let data = try await hub.currentTV().screen.data.decode(LobbyData.self)
    #expect(data.joinURL == "http://10.0.0.2:8080/?room=BCDF&ws=8081")
}
