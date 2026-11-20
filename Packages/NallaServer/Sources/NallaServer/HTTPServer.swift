import Foundation
import Network

public enum ServerError: Error, Equatable {
    case noFreePort
}

/// Minimal HTTP/1.1 static file server on Network.framework. All mutable state lives on `queue`.
public final class HTTPServer: @unchecked Sendable {
    let root: URL
    let bonjourName: String?
    private let queue = DispatchQueue(label: "nallabox.http")
    private var listener: NWListener?

    public init(root: URL, bonjourName: String?) {
        self.root = root
        self.bonjourName = bonjourName
    }

    /// Starts on the first free port in `ports` and returns it.
    public func start(ports: ClosedRange<UInt16>) async throws -> UInt16 {
        for port in ports {
            if try await tryStart(port) { return port }
        }
        throw ServerError.noFreePort
    }

    private func tryStart(_ port: UInt16) async throws -> Bool {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = false
        guard let nwPort = NWEndpoint.Port(rawValue: port), let l = try? NWListener(using: params, on: nwPort) else { return false }
        if let name = bonjourName { l.service = NWListener.Service(name: name, type: "_nallabox._tcp") }
        l.newConnectionHandler = { [weak self] c in self?.serve(c) }
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
        if ok {
            queue.sync { listener = l }
            l.stateUpdateHandler = nil
        } else {
            l.cancel()
        }
        return ok
    }

    public func stop() {
        queue.sync {
            listener?.cancel()
            listener = nil
        }
    }

    private func serve(_ c: NWConnection) {
        c.start(queue: queue)
        read(c, buffer: Data())
    }

    private func read(_ c: NWConnection, buffer: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, done, error in
            guard let self else { c.cancel(); return }
            var buf = buffer
            if let data { buf.append(data) }
            if let end = buf.range(of: Data("\r\n\r\n".utf8)) {
                let req = HTTPRequest.parse(buf[..<end.lowerBound])
                let resp = req.map { StaticFiles.response(for: $0, root: self.root) } ?? .text(400, "Bad request")
                c.send(content: resp.serialized(), completion: .contentProcessed { _ in c.cancel() })
            } else if buf.count > HTTPRequest.maxHead || done || error != nil {
                c.send(content: HTTPResponse.text(400, "Bad request").serialized(), completion: .contentProcessed { _ in c.cancel() })
            } else {
                self.read(c, buffer: buf)
            }
        }
    }
}

/// Runs a closure at most once (thread-safe).
final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func run(_ body: () -> Void) {
        lock.lock()
        let first = !done
        done = true
        lock.unlock()
        if first { body() }
    }
}
