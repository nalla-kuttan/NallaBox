import Foundation
import Testing
@testable import NallaCore

private func decoded(_ json: String) -> DecodedMessage? {
    if case .success(let d) = Wire.decodeClient(json) { return d }
    return nil
}

private func wireError(_ json: String) -> WireError? {
    if case .failure(let e) = Wire.decodeClient(json) { return e }
    return nil
}

private func object(_ text: String) -> [String: Any] {
    (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any] ?? [:]
}

@Test func decodeEveryClientMessage() {
    #expect(decoded(#"{"v":1,"type":"join","id":"1","room":"BCDF","name":"Priya","colour":"saffron"}"#)
            == DecodedMessage(id: "1", message: .join(JoinRequest(room: "BCDF", name: "Priya", colour: .saffron, seatToken: nil))))
    #expect(decoded(#"{"v":1,"type":"join","id":"1","room":"BCDF","name":"Priya","colour":"sky","seat_token":"ab"}"#)?.message
            == .join(JoinRequest(room: "BCDF", name: "Priya", colour: .sky, seatToken: "ab")))
    #expect(decoded(#"{"v":1,"type":"submit_text","id":"2","round":1,"fields":["a","b"]}"#)?.message
            == .submitText(round: 1, fields: ["a", "b"]))
    #expect(decoded(#"{"v":1,"type":"stroke_data","id":"3","round":2,"strokes":[{"c":1,"s":2,"p":[0.1,0.2,0.3,0.4]}],"final":true}"#)?.message
            == .strokeData(round: 2, strokes: [Stroke(c: 1, s: 2, p: [0.1, 0.2, 0.3, 0.4])], final: true))
    #expect(decoded(#"{"v":1,"type":"cast_vote","id":"4","round":3,"choice":2}"#)?.message == .castVote(round: 3, choice: 2))
    #expect(decoded(#"{"v":1,"type":"place_bet","id":"5","round":1,"choice":0,"chips":300}"#)?.message
            == .placeBet(round: 1, choice: 0, chips: 300))
    #expect(decoded(#"{"v":1,"type":"ping","id":"6","t":12.5}"#)?.message == .ping(t: 12.5))

    let leader: [(String, LeaderAction)] = [
        (#""action":"pick_game","args":{"game":"redacted"}"#, .pickGame(.redacted)),
        (#""action":"preview_game","args":{"game":"insider"}"#, .previewGame(.insider)),
        (#""action":"set_settings","args":{"rounds":4,"timer":"1.5","family_friendly":false,"banned_words":true}"#,
         .setSettings(SettingsPatch(rounds: 4, timer: .x15, familyFriendly: false, bannedWords: true))),
        (#""action":"set_settings","args":{"timer":"off"}"#, .setSettings(SettingsPatch(timer: .off))),
        (#""action":"start""#, .start), (#""action":"pause""#, .pause), (#""action":"resume""#, .resume),
        (#""action":"skip""#, .skip), (#""action":"end""#, .end),
        (#""action":"remove_player","args":{"player":3}"#, .removePlayer(3)),
        (#""action":"pass_leader","args":{"player":2}"#, .passLeader(2)),
        (#""action":"play_again""#, .playAgain), (#""action":"new_game""#, .newGame),
    ]
    for (fields, action) in leader {
        #expect(decoded(#"{"v":1,"type":"leader","id":"9","# + fields + "}")?.message == .leader(action), "\(fields)")
    }
}

@Test func decodeErrors() {
    #expect(wireError("{") == WireError(id: nil, code: .badMessage, message: "That message didn't make sense."))
    #expect(wireError(#"{"v":2,"type":"ping","id":"a","t":1}"#)?.code == .wrongVersion)
    #expect(wireError(#"{"v":2,"type":"ping","id":"a","t":1}"#)?.id == "a")
    #expect(wireError(#"{"v":1,"type":"nope","id":"b"}"#)?.code == .badMessage)
    #expect(wireError(#"{"v":1,"type":"cast_vote","id":"c","round":1}"#)?.code == .badMessage)
    #expect(wireError(#"{"v":1,"type":"join","id":"d","room":"X","name":"A","colour":"coral"}"#)?.code == .badMessage)
    #expect(wireError(#"{"v":1,"type":"leader","id":"e","action":"explode"}"#)?.code == .badMessage)
}

@Test func encodeServerMessages() {
    let err = object(Wire.encode(.error(id: "7", code: .tooClose, message: "Too close to the real word, try another", field: 1)))
    #expect(err["v"] as? Int == 1)
    #expect(err["type"] as? String == "error")
    #expect(err["id"] as? String == "7")
    #expect(err["code"] as? String == "too_close")
    #expect(err["field"] as? Int == 1)
    #expect(err["message"] as? String == "Too close to the real word, try another")

    let welcome = object(Wire.encode(.welcome(playerId: 3, seatToken: "abc")))
    #expect(welcome["type"] as? String == "welcome")
    #expect(welcome["player_id"] as? Int == 3)
    #expect(welcome["seat_token"] as? String == "abc")

    let pong = object(Wire.encode(.pong(t: 5, hostTime: 9.5)))
    #expect(pong["host_time"] as? Double == 9.5)
    #expect(object(Wire.encode(.removed(.replaced)))["reason"] as? String == "replaced")
    #expect(object(Wire.encode(.ack(id: "4")))["id"] as? String == "4")
}

@Test func serverMessagesRoundTrip() {
    let summary = PlayerSummary(id: 1, name: "Priya", colour: .saffron, connected: true, isLeader: true, score: 0)
    let view = PlayerView(
        version: 3, screen: "P4", deadline: 1_000_060,
        you: YouInfo(id: 1, name: "Priya", colour: .saffron, isLeader: true, isHost: false, score: 0),
        room: RoomInfo(code: "BCDF", players: [summary], leaderId: 1, game: nil, paused: nil, settings: RoomSettings()),
        data: .object(["canStart": .bool(false)]))
    let messages: [ServerMessage] = [
        .welcome(playerId: 1, seatToken: "t"), .view(view), .ack(id: "1"),
        .error(id: nil, code: .roomFull, message: "This room is full (8 players).", field: nil),
        .pong(t: 1, hostTime: 2), .removed(.byHost), .removed(.sessionEnded),
    ]
    for m in messages { #expect(Wire.decodeServer(Wire.encode(m)) == m) }
    let flat = object(Wire.encode(.view(view)))
    #expect(flat["screen"] as? String == "P4")
    #expect((flat["you"] as? [String: Any])?["isLeader"] as? Bool == true)
}
