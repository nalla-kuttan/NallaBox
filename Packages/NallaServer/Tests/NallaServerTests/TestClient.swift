import Foundation
@testable import NallaCore

/// A phone over a real WebSocket (URLSessionWebSocketTask). Buffers every message it receives.
final class TestClient: @unchecked Sendable {
    private let task: URLSessionWebSocketTask
    private let lock = NSLock()
    private var _messages: [ServerMessage] = []
    private var _failed = false
    private var counter = 0

    init(url: URL) {
        task = URLSession.shared.webSocketTask(with: url)
        task.maximumMessageSize = 4 << 20
        task.resume()
        receive()
    }

    private func receive() {
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(.string(let s)):
                if let m = Wire.decodeServer(s) { self.lock.lock(); self._messages.append(m); self.lock.unlock() }
                self.receive()
            case .success: self.receive()
            case .failure: self.lock.lock(); self._failed = true; self.lock.unlock()
            }
        }
    }

    var messages: [ServerMessage] { lock.lock(); defer { lock.unlock() }; return _messages }
    var failed: Bool { lock.lock(); defer { lock.unlock() }; return _failed }
    var views: [PlayerView] { messages.compactMap { if case .view(let v) = $0 { return v }; return nil } }
    var lastView: PlayerView? { views.last }
    var playerId: PlayerID? { messages.lazy.compactMap { if case .welcome(let p, _) = $0 { return p }; return nil }.first }
    var seatToken: String? { messages.lazy.compactMap { if case .welcome(_, let t) = $0 { return t }; return nil }.first }

    func sendText(_ s: String) async throws { try await task.send(.string(s)) }

    func send(_ type: String, _ fields: [String: JSONValue] = [:]) async throws {
        counter += 1
        var o = fields
        o["v"] = .number(1); o["type"] = .string(type); o["id"] = .string("c\(counter)")
        try await sendText(JSONValue.object(o).jsonText)
    }

    func close() { task.cancel(with: .goingAway, reason: nil) }

    /// Waits up to 3 s for a condition on the received messages.
    func wait(_ cond: @Sendable (TestClient) -> Bool) async -> Bool {
        for _ in 0..<600 {
            if cond(self) { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return false
    }
}
