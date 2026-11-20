import Foundation
import Testing
@testable import NallaCore
@testable import NallaServer

func controllerSite() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("nb-ctrl-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try Data("<!doctype html><title>NallaBox controller</title>".utf8).write(to: dir.appendingPathComponent("index.html"))
    return dir
}

func wsURL(_ e: RoomEndpoint) -> URL { URL(string: "ws://127.0.0.1:\(e.wsPort)/")! }

@Test func endToEndJoin() async throws {
    let server = RoomServer(controllerRoot: try controllerSite(), content: .empty, code: "BCDF")
    let e = try await server.start(ports: 19080...19089)
    let (data, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(e.httpPort)/")!)
    #expect(String(decoding: data, as: UTF8.self).contains("NallaBox controller"))
    let phone = TestClient(url: wsURL(e))
    try await phone.sendText(joinJSON("Priya", .saffron))
    #expect(await phone.wait { $0.lastView?.screen == "P4" })
    #expect(phone.playerId == 1)
    phone.close()
    await server.stop()
}

@Test func oversizedFrameClosesOnlyThatClient() async throws {
    let server = RoomServer(controllerRoot: try controllerSite(), content: .empty, code: "BCDF")
    let e = try await server.start(ports: 19180...19189)
    let a = TestClient(url: wsURL(e)), b = TestClient(url: wsURL(e))
    try await a.sendText(joinJSON("Priya", .saffron))
    try await b.sendText(joinJSON("Sam", .sky))
    #expect(await b.wait { $0.lastView?.room.players.count == 2 })
    try? await a.sendText(String(repeating: "x", count: 2 << 20))
    #expect(await a.wait { $0.failed })
    #expect(await b.wait { $0.lastView?.room.players.first?.connected == false })
    let c = TestClient(url: wsURL(e))
    try await c.sendText(joinJSON("Lena", .lilac))
    #expect(await b.wait { $0.lastView?.room.players.count == 3 })
    b.close(); c.close()
    await server.stop()
}

@Test func endpointURL() async throws {
    let server = RoomServer(controllerRoot: try controllerSite(), content: .empty, code: "BCDF")
    let e = try await server.start(ports: 19280...19289)
    let ip = LANAddress.current() ?? "127.0.0.1"
    #expect(e.wsPort == e.httpPort + 1)
    #expect(e.joinURL == "http://\(ip):\(e.httpPort)/?room=BCDF&ws=\(e.wsPort)")
    #expect(e.localControllerURL(seatToken: "abc") == "http://127.0.0.1:\(e.httpPort)/?room=BCDF&ws=\(e.wsPort)&seat=abc")
    let lobby = try await server.hub.currentTV().screen.data.decode(LobbyData.self)
    #expect(lobby.joinURL == e.joinURL)
    await server.stop()
}
