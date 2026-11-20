import Foundation
import Network
import NallaCore

public enum WSEvent: Sendable {
    case open(ConnectionID, ip: String, send: @Sendable (String) -> Void, close: @Sendable () -> Void)
    case text(ConnectionID, String)
    case close(ConnectionID)
}

/// WebSocket listener (Network.framework). Events for all connections arrive in order on one stream.
public final class WebSocketServer: @unchecked Sendable {
    public static let maxMessage = 65_536
    private let queue = DispatchQueue(label: "nallabox.ws")
    private var listener: NWListener?
    private var connections: [ConnectionID: NWConnection] = [:]
    public let events: AsyncStream<WSEvent>
    private let sink: AsyncStream<WSEvent>.Continuation

    public init() {
        (events, sink) = AsyncStream<WSEvent>.makeStream()
    }

    public func start(port: UInt16) async throws {
        let params = NWParameters.tcp
        let ws = NWProtocolWebSocket.Options()
        ws.autoReplyPing = true
        ws.maximumMessageSize = Self.maxMessage
        params.defaultProtocolStack.applicationProtocols.insert(ws, at: 0)
        guard let p = NWEndpoint.Port(rawValue: port), let l = try? NWListener(using: params, on: p) else { throw ServerError.noFreePort }
        l.newConnectionHandler = { [weak self] c in self?.accept(c) }
        let ok: Bool = await withCheckedContinuation { cont in
            let once = Once()
            l.stateUpdateHandler = { state in
                switch state {
                case .ready: once.run { cont.resume(returning: true) }
                case .failed, .cancelled: once.run { cont.resume(returning: false) }
                case .waiting: once.run { l.cancel(); cont.resume(returning: false) }
                default: break
                }
            }
            l.start(queue: queue)
        }
        guard ok else { l.cancel(); throw ServerError.noFreePort }
        l.stateUpdateHandler = nil
        queue.sync { listener = l }
    }

    public func stop() {
        queue.sync {
            listener?.cancel()
            listener = nil
            for c in connections.values { c.cancel() }
            connections = [:]
        }
        sink.finish()
    }

    private func accept(_ c: NWConnection) {
        let id = ConnectionID()
        let ip: String = {
            if case .hostPort(let host, _) = c.endpoint {
                let s = "\(host)"
                return String(s.split(separator: "%").first ?? Substring(s))
            }
            return "?"
        }()
        let once = Once(), closedOnce = Once()
        c.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                once.run {
                    self.connections[id] = c
                    let send: @Sendable (String) -> Void = { text in
                        let meta = NWProtocolWebSocket.Metadata(opcode: .text)
                        let ctx = NWConnection.ContentContext(identifier: "text", metadata: [meta])
                        c.send(content: Data(text.utf8), contentContext: ctx, isComplete: true, completion: .contentProcessed { _ in })
                    }
                    self.sink.yield(.open(id, ip: ip, send: send, close: { c.cancel() }))
                    self.receive(c, id)
                }
            case .failed, .cancelled:
                closedOnce.run {
                    self.connections[id] = nil
                    self.sink.yield(.close(id))
                }
            default: break
            }
        }
        c.start(queue: queue)
    }

    private func receive(_ c: NWConnection, _ id: ConnectionID) {
        c.receiveMessage { [weak self] data, ctx, _, error in
            guard let self else { return }
            if error != nil { c.cancel(); return }
            let meta = ctx?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
            switch meta?.opcode {
            case .close?: c.cancel(); return
            case .text?:
                if let data, let s = String(data: data, encoding: .utf8) { self.sink.yield(.text(id, s)) }
            default: break
            }
            self.receive(c, id)
        }
    }
}
