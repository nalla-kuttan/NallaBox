import Foundation
import NallaCore

/// The whole local server: static HTTP for the controller, WebSocket on HTTP port + 1, and the hub.
public actor RoomServer {
    public nonisolated let hub: Hub
    let controllerRoot: URL
    private var http: HTTPServer?
    private var ws: WebSocketServer?
    private var pump: Task<Void, Never>?

    public init(controllerRoot: URL, content: ContentLibrary, clock: any HubClock = SystemClock(),
                seed: UInt64 = UInt64.random(in: 1...UInt64.max), code: String? = nil) {
        self.controllerRoot = controllerRoot
        self.hub = Hub(content: content, clock: clock, seed: seed, code: code)
    }

    public func start(ports: ClosedRange<UInt16> = 8080...8089) async throws -> RoomEndpoint {
        var next = ports.lowerBound
        while next < ports.upperBound {
            let h = HTTPServer(root: controllerRoot, bonjourName: "NallaBox \(hub.code)")
            let port = try await h.start(ports: next...ports.upperBound)
            let w = WebSocketServer()
            do {
                try await w.start(port: port + 1)
            } catch {
                h.stop()
                next = port + 1
                continue
            }
            http = h; ws = w
            let hub = self.hub
            pump = Task {
                for await e in w.events {
                    switch e {
                    case .open(let c, let ip, let send, let close): await hub.opened(c, ip: ip, send: send, close: close)
                    case .text(let c, let s): await hub.received(s, from: c)
                    case .close(let c): await hub.closed(c)
                    }
                }
            }
            let e = RoomEndpoint(code: hub.code, ip: LANAddress.current() ?? "127.0.0.1", httpPort: port, wsPort: port + 1)
            await hub.setJoinURL(e.joinURL)
            return e
        }
        throw ServerError.noFreePort
    }

    public func stop() async {
        ws?.stop()
        http?.stop()
        pump?.cancel()
        ws = nil; http = nil; pump = nil
    }
}
