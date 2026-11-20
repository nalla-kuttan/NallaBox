import Foundation
import Testing
@testable import NallaCore

@Test func joinAndErrors() {
    var h = Harness()
    let p = h.join("Priya", .saffron)
    #expect(p == 1)
    #expect(h.effects.contains { if case .reply(_, .welcome(1, _)) = $0 { return true }; return false })
    #expect(h.s.leaderId == 1)
    #expect(h.phone(1).screen == "P4")

    #expect(h.join("Sam", .sky, room: "ZZZZ") == nil); #expect(h.lastError == .wrongCode)
    #expect(h.join("Sam", .sky, room: "bcdf") == 2)
    #expect(h.join("priya", .mint) == nil); #expect(h.lastError == .nameTaken)
    #expect(h.join("Lena", .sky) == nil); #expect(h.lastError == .colourTaken)
    #expect(h.join("   ", .mint) == nil); #expect(h.lastError == .nameInvalid)
    #expect(h.join("shit lord", .mint) == nil); #expect(h.lastError == .nameInvalid)
    for (i, c) in [PlayerColour.mint, .lilac, .pink, .lime, .teal, .sand].enumerated() { h.join("P\(i)", c) }
    #expect(h.s.players.count == 8)
    #expect(h.join("Nine", .saffron) == nil); #expect(h.lastError == .roomFull)
    #expect(h.phone(2).screen == "P3")
}

@Test func profaneNamesAllowedWhenFamilyOff() {
    var h = Harness()
    h.s.settings.familyFriendly = false
    #expect(h.join("damn", .mint) == 1)
}

@Test func rejoinWithSeatToken() {
    var h = Harness.three()
    let token = h.tokens[2]!
    h.send(.disconnected(2))
    #expect(h.player(2)?.connected == false)
    #expect(h.join("Whatever", .pink, token: token) == 2)
    #expect(h.player(2)?.connected == true)
    #expect(h.player(2)?.name == "Sam")
    #expect(h.s.players.count == 3)
}

@Test func lateJoinerWaits() {
    var h = Harness.playing()
    let late = h.join("Dev", .mint)!
    #expect(h.player(late)?.waitingForNextGame == true)
    #expect(h.phone(late).screen == "P2")
    #expect(h.phone(late).data["reason"] == .string("in-progress"))
    while case .playing = h.s.phase { h.advance(20) }
    h.leader(1, .playAgain)
    #expect(h.player(late)?.waitingForNextGame == false)
    h.advance(15)
    #expect(h.phone(late).screen == "X1")
}

@Test func leaderOnly() {
    var h = Harness.three()
    h.leader(2, .start)
    #expect(h.lastError == .notLeader)
}

@Test func passLeader() {
    var h = Harness.three()
    h.leader(1, .passLeader(3))
    #expect(h.s.leaderId == 3)
    #expect(h.tv().overlays.toast == "Lena is now the leader")
    #expect(h.phone(3).screen == "P4")
    h.leader(3, .passLeader(3))
    #expect(h.lastError == .notAllowed)
}

@Test func startFlow() {
    var h = Harness()
    h.join("Priya", .saffron); h.join("Sam", .sky)
    h.leader(1, .previewGame(.test))
    #expect(h.s.phase == .picker)
    #expect(h.s.preview == .test)
    #expect(h.tv().screen.screen == "T4")
    #expect(h.phone(1).screen == "P5")
    h.leader(1, .pickGame(.test))
    #expect(h.s.phase == .settings(.test))
    #expect(h.tv().screen.screen == "T5")
    #expect(h.phone(1).screen == "P6")
    #expect(h.phone(2).screen == "P3")
    h.leader(1, .start)
    #expect(h.lastError == .notAllowed)
    h.join("Lena", .lilac)
    h.leader(1, .start)
    guard case .howTo(.test, let until) = h.s.phase else { Issue.record("not in how-to: \(h.s.phase)"); return }
    #expect(until == h.now + 15)
    #expect(h.tv().screen.screen == "T6")
    #expect(h.tv().screen.deadline == h.now + 15)
    #expect(h.phone(2).screen == "P7")
    h.advance(14.9)
    #expect(h.tv().screen.screen == "T6")
    h.advance(0.1)
    guard case .playing = h.s.phase else { Issue.record("not playing"); return }
    #expect(h.phone(2).screen == "X1")
}

@Test func leaderCanSkipHowTo() {
    var h = Harness.three()
    h.leader(1, .pickGame(.test)); h.leader(1, .start)
    h.leader(1, .skip)
    guard case .playing = h.s.phase else { Issue.record("not playing"); return }
}

@Test func settingsBlockedBelowMinimum() {
    var h = Harness()
    h.join("Priya", .saffron); h.join("Sam", .sky)
    h.leader(1, .pickGame(.test))
    let data = try? h.phone(1).data.decode(SettingsData.self)
    #expect(data?.canStart == false)
    #expect(data?.startBlockedReason == "Test Game needs 3 players")
    let lobby = Harness()
    #expect(lobby.s.players.isEmpty)
}

@Test func lobbyNeedsThree() throws {
    var h = Harness()
    h.join("Priya", .saffron)
    let d = try h.phone(1).data.decode(LobbyData.self)
    #expect(d.canStart == false)
    #expect(d.startBlockedReason == "Need 3 players to start")
}

@Test func settingsPatchClamped() {
    var h = Harness.three()
    h.leader(1, .pickGame(.test))
    #expect(h.s.settings.rounds == 2)
    h.leader(1, .setSettings(SettingsPatch(rounds: 9)))
    #expect(h.s.settings.rounds == 5)
    h.leader(1, .setSettings(SettingsPatch(rounds: 1, timer: .x2, familyFriendly: false, bannedWords: true)))
    #expect(h.s.settings.rounds == 2)
    #expect(h.s.settings.timer == .x2)
    #expect(h.s.settings.familyFriendly == false)
    #expect(h.s.settings.bannedWords == true)
}

@Test func timerMultiplierAppliesToInputPhases() {
    var h = Harness.three()
    h.leader(1, .pickGame(.test)); h.leader(1, .setSettings(SettingsPatch(timer: .x2))); h.leader(1, .start)
    h.advance(15)
    #expect(h.phone(1).deadline == h.now + 20)
    var off = Harness.three()
    off.leader(1, .pickGame(.test)); off.leader(1, .setSettings(SettingsPatch(timer: .off))); off.leader(1, .start)
    off.advance(15)
    #expect(off.phone(1).deadline == nil)
    off.advance(1000)
    #expect(off.phone(1).screen == "X1")
    off.leader(1, .skip)
    #expect(off.phone(1).data["phase"] == .string("fixed"))
}

@Test func pauseFreezesDeadlines() {
    var h = Harness.playing()
    let deadline = h.phone(1).deadline!
    #expect(deadline == h.now + 10)
    h.advance(4)
    h.leader(1, .pause)
    #expect(h.phone(2).screen == "P10")
    #expect(h.phone(2).data["by"] == .string("Priya"))
    #expect(h.tv().overlays.paused == PauseInfo(by: "Priya"))
    #expect(Engine.nextWake(h.s) == nil)
    h.advance(96)
    #expect(h.phone(2).screen == "P10")
    h.leader(1, .resume)
    #expect(h.phone(2).screen == "X1")
    #expect(h.phone(2).deadline == deadline + 96)
    #expect(Engine.nextWake(h.s) == deadline + 96)
}

@Test func hostPauseUsesHostName() {
    var h = Harness.playing()
    h.send(.host(.pause))
    #expect(h.tv().overlays.paused == PauseInfo(by: "the host"))
    h.send(.host(.resume))
    #expect(h.tv().overlays.paused == nil)
}

@Test func earlyEndWhenAllConnectedActed() {
    var h = Harness.playing()
    h.send(.disconnected(3))
    h.msg(1, .castVote(round: 1, choice: 0))
    #expect(h.phone(1).data["phase"] == .string("input"))
    h.msg(2, .castVote(round: 1, choice: 0))
    #expect(h.phone(1).data["phase"] == .string("fixed"))
    #expect(h.effects.contains { if case .send(2, .ack) = $0 { return true }; return false })
}

@Test func leaderHandoffAfter30s() {
    var h = Harness.three()
    h.send(.disconnected(1))
    #expect(Engine.nextWake(h.s) == h.now + 30)
    h.advance(29)
    #expect(h.s.leaderId == 1)
    h.advance(1)
    #expect(h.s.leaderId == 2)
    #expect(h.tv().overlays.toast == "Sam is now the leader")
    h.advance(3.9)
    #expect(h.tv().overlays.toast != nil)
    h.advance(0.1)
    #expect(h.tv().overlays.toast == nil)
}

@Test func leaderHandoffWhilePaused() {
    var h = Harness.playing()
    h.leader(1, .pause)
    h.send(.disconnected(1))
    #expect(Engine.nextWake(h.s) == h.now + 30)
    h.advance(30)
    #expect(h.s.leaderId == 2)
    #expect(h.phone(2).data["byYou"] == .bool(false))
    h.leader(2, .resume)
    #expect(h.tv().overlays.paused == nil)
}

@Test func leaderRemovedPassesImmediately() {
    var h = Harness.three()
    h.send(.host(.removePlayer(1)))
    #expect(h.s.leaderId == 2)
    #expect(h.player(1) == nil)
    #expect(h.effects.contains(.kick(1, .byHost)))
    #expect(h.phone(2).screen == "P4")
}

@Test func leaderRemovesPlayerWithConfirmOnPhone() {
    var h = Harness.three()
    h.leader(1, .removePlayer(3))
    #expect(h.player(3) == nil)
    #expect(h.effects.contains(.kick(3, .byHost)))
    h.leader(1, .removePlayer(1))
    #expect(h.lastError == .notAllowed)
}

@Test func staleRoundInputIgnored() {
    var h = Harness.playing()
    h.advance(10); h.advance(5)
    #expect(h.phone(1).data["round"] == .number(2))
    let before = h.s
    h.msg(1, .castVote(round: 1, choice: 0))
    #expect(h.s == before)
    #expect(h.effects.contains { if case .send(1, .ack) = $0 { return true }; return false })
    #expect(h.lastError == nil)
}

@Test func endAndPlayAgain() throws {
    var h = Harness.playing()
    h.msg(1, .castVote(round: 1, choice: 0))
    h.leader(1, .end)
    guard case .results(let r) = h.s.phase else { Issue.record("no results"); return }
    #expect(r.standings.first?.player.name == "Priya")
    #expect(h.tv().screen.screen == "T10")
    #expect(h.phone(1).screen == "P12")
    let mine = try h.phone(1).data.decode(PhoneResultsData.self)
    #expect(mine.rank == 1)
    #expect(mine.points == 100)
    h.leader(1, .playAgain)
    guard case .howTo(.test, _) = h.s.phase else { Issue.record("no how-to"); return }
    h.advance(15)
    #expect(Engine.roomInfo(h.s).players.allSatisfy { $0.score == 0 })
    h.leader(1, .end); h.leader(1, .newGame)
    #expect(h.s.phase == .picker)
}

@Test func gameRunsToResults() {
    var h = Harness.playing()
    for _ in 0..<4 { h.advance(10) }
    guard case .results = h.s.phase else { Issue.record("expected results, got \(h.s.phase)"); return }
}

@Test func endSession() {
    var h = Harness.playing()
    h.send(.host(.endSession))
    guard case .results = h.s.phase else { Issue.record("no results"); return }
    #expect(h.effects.contains(.kick(1, .sessionEnded)))
    #expect(h.effects.contains(.kick(3, .sessionEnded)))
    #expect(h.effects.contains(.closeRoom))
}

@Test func hostSeat() {
    var h = Harness()
    h.send(.reserveHostSeat(name: "Priya", colour: .saffron, token: "hosttoken"))
    #expect(h.player(1)?.isHost == true)
    #expect(h.player(1)?.connected == false)
    #expect(h.s.leaderId == 1)
    #expect(h.join("Sam", .sky) == 2)
    #expect(h.s.leaderId == 1)
    #expect(h.join("ignored", .mint, token: "hosttoken") == 1)
    #expect(h.player(1)?.connected == true)
    #expect(Engine.youInfo(h.s, 1)?.isHost == true)
    #expect(h.tv().overlays.reconnecting.isEmpty)
}

@Test func reconnectBannerDuringGame() {
    var h = Harness.playing()
    h.send(.disconnected(2))
    #expect(h.tv().overlays.reconnecting.map(\.player.name) == ["Sam"])
    #expect(h.tv().overlays.reconnecting.first?.since == h.now)
    h.join("x", .pink, token: h.tokens[2])
    #expect(h.tv().overlays.reconnecting.isEmpty)
}

@Test func tvLobbyHelpAfter60s() {
    var h = Harness()
    #expect(h.tv().screen.screen == "T1")
    #expect(Engine.nextWake(h.s) == h.now + 60)
    h.advance(59)
    #expect(h.tv().screen.screen == "T1")
    h.advance(1)
    #expect(h.tv().screen.screen == "T3")
    h.join("Priya", .saffron)
    #expect(h.tv().screen.screen == "T2")
}

@Test func speechAndFaceCaptions() {
    var h = Harness.three()
    var screens: [TVView] = [h.tv()]
    h.leader(1, .previewGame(.test)); screens.append(h.tv())
    h.leader(1, .pickGame(.test)); screens.append(h.tv())
    h.leader(1, .start); screens.append(h.tv())
    h.leader(1, .end); screens.append(h.tv())
    for v in screens { #expect((v.face.caption ?? "").count <= 48, "\(v.screen.screen): \(v.face.caption ?? "")") }
    #expect(Harness().tv().face == FaceCue(.wink, "Scan to join."))
}
