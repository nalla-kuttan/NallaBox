import Foundation
import Testing
@testable import NallaServer

private func tempSite() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("nb-site-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir.appendingPathComponent("shared/fonts"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: dir.appendingPathComponent("js"), withIntermediateDirectories: true)
    try Data("<!doctype html><title>NB</title>".utf8).write(to: dir.appendingPathComponent("index.html"))
    try Data([0, 1, 2]).write(to: dir.appendingPathComponent("shared/fonts/nunito-wght.woff2"))
    try Data("export {}".utf8).write(to: dir.appendingPathComponent("js/app.js"))
    try Data("<svg/>".utf8).write(to: dir.appendingPathComponent("logo.svg"))
    return dir
}

private func header(_ r: HTTPResponse, _ name: String) -> String? {
    r.headers.first { $0.0.lowercased() == name.lowercased() }?.1
}

@Test func parse() {
    let req = HTTPRequest.parse(Data("GET /js/app.js?x=1&room=BCDF HTTP/1.1\r\nHost: a\r\n\r\n".utf8))
    #expect(req == HTTPRequest(method: "GET", path: "/js/app.js", query: ["x": "1", "room": "BCDF"]))
    #expect(HTTPRequest.parse(Data("garbage".utf8)) == nil)
    #expect(HTTPRequest.parse(Data(("GET /" + String(repeating: "a", count: 9000) + " HTTP/1.1\r\n\r\n").utf8)) == nil)
}

@Test func staticFiles() throws {
    let root = try tempSite()
    func get(_ path: String, method: String = "GET") -> HTTPResponse {
        StaticFiles.response(for: HTTPRequest(method: method, path: path, query: [:]), root: root)
    }
    let index = get("/")
    #expect(index.status == 200)
    #expect(header(index, "Content-Type") == "text/html; charset=utf-8")
    #expect(String(decoding: index.body, as: UTF8.self).contains("<title>NB</title>"))
    #expect(header(get("/shared/fonts/nunito-wght.woff2"), "Content-Type") == "font/woff2")
    #expect(header(get("/js/app.js"), "Content-Type") == "text/javascript; charset=utf-8")
    #expect(header(get("/logo.svg"), "Content-Type") == "image/svg+xml")
    #expect(get("/../etc/passwd").status == 404)
    #expect(get("/%2e%2e/etc/passwd").status == 404)
    #expect(get("/js").status == 404)
    #expect(get("/missing.html").status == 404)
    #expect(get("/", method: "POST").status == 405)
    #expect(header(index, "Cache-Control") == "no-store")
    let wire = String(decoding: index.serialized(), as: UTF8.self)
    #expect(wire.hasPrefix("HTTP/1.1 200 OK\r\n"))
    #expect(wire.contains("Content-Length: \(index.body.count)\r\n"))
    #expect(wire.contains("Connection: close\r\n"))
}

@Test func lanPick() {
    #expect(LANAddress.pick([("lo0", "127.0.0.1"), ("en5", "169.254.1.2"), ("en1", "10.0.0.4"), ("en0", "192.168.1.20")]) == "192.168.1.20")
    #expect(LANAddress.pick([("lo0", "127.0.0.1"), ("en1", "10.0.0.4"), ("bridge100", "192.168.2.1")]) == "10.0.0.4")
    #expect(LANAddress.pick([("utun3", "100.64.0.2"), ("bridge100", "172.20.10.1")]) == "172.20.10.1")
    #expect(LANAddress.pick([]) == nil)
    #expect(LANAddress.pick([("lo0", "127.0.0.1")]) == nil)
}

@Test func rateLimiter() {
    var r = JoinRateLimiter()
    var first: [Bool] = []
    for _ in 0..<10 { first.append(r.allow(ip: "10.0.0.9", now: 0)) }
    let eleventh = r.allow(ip: "10.0.0.9", now: 1)
    let otherIP = r.allow(ip: "10.0.0.8", now: 1)
    let later = r.allow(ip: "10.0.0.9", now: 60.1)
    #expect(first == Array(repeating: true, count: 10))
    #expect(!eleventh)
    #expect(otherIP)
    #expect(later)
}

@Test func serverServesFilesAndFallsBack() async throws {
    let root = try tempSite()
    let a = HTTPServer(root: root, bonjourName: nil)
    let b = HTTPServer(root: root, bonjourName: nil)
    let pa = try await a.start(ports: 18080...18089)
    let pb = try await b.start(ports: pa...18089)
    #expect(pb > pa)
    let (data, resp) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(pa)/?room=BCDF")!)
    #expect((resp as? HTTPURLResponse)?.statusCode == 200)
    #expect(String(decoding: data, as: UTF8.self).contains("<title>NB</title>"))
    let (_, missing) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(pb)/nope")!)
    #expect((missing as? HTTPURLResponse)?.statusCode == 404)
    a.stop(); b.stop()
}
