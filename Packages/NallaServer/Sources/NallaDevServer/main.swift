import Foundation
import NallaCore
import NallaServer

/// Runs a room in the terminal so browser tabs can play as phones.
/// Usage: swift run NallaDevServer [--controller DIR] [--content DIR] [--seed N] [--port N]
/// Keys: p = pause/resume, s = skip, q = quit.
@main
struct DevServer {
    static func main() async throws {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        var args = Array(CommandLine.arguments.dropFirst())
        func value(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            defer { args.removeSubrange(i...i + 1) }
            return args[i + 1]
        }
        let controller = value("--controller").map { URL(fileURLWithPath: $0) } ?? repo.appendingPathComponent("app/Resources/Controller")
        let contentDir = value("--content").map { URL(fileURLWithPath: $0) } ?? repo.appendingPathComponent("app/Resources/Content")
        let seed = value("--seed").flatMap(UInt64.init) ?? UInt64.random(in: 1...UInt64.max)
        let port = value("--port").flatMap(UInt16.init) ?? 8080

        let content = try ContentLibrary.load(from: contentDir)
        let server = RoomServer(controllerRoot: controller, content: content, seed: seed)
        let endpoint = try await server.start(ports: port...(port + 9))
        print("NallaBox room \(endpoint.code)")
        print("Join:  \(endpoint.joinURL)")
        print("Local: http://127.0.0.1:\(endpoint.httpPort)/?room=\(endpoint.code)&ws=\(endpoint.wsPort)")
        print("Keys: p pause/resume · s skip · q quit")
        fflush(stdout)

        let hub = server.hub
        let events = Task {
            var last = ""
            for await e in await hub.events() {
                switch e {
                case .snapshot(let tv):
                    let line = "TV \(tv.screen.screen)  face \(tv.face.state.rawValue): \(tv.face.caption ?? "")"
                        + (tv.overlays.paused.map { "  [paused by \($0.by)]" } ?? "")
                        + (tv.overlays.toast.map { "  [toast: \($0)]" } ?? "")
                    if line != last { print(line); last = line; fflush(stdout) }
                case .speak(let s): print("VOICE \(s)"); fflush(stdout)
                case .roomClosed: print("Room closed"); fflush(stdout)
                }
            }
        }
        let keys = Task.detached {
            while true {
                // No terminal attached (run in the background): keep serving until killed.
                guard let line = readLine() else {
                    try? await Task.sleep(for: .seconds(86_400 * 365))
                    return
                }
                switch line.trimmingCharacters(in: .whitespaces) {
                case "p":
                    let paused = await hub.currentTV().overlays.paused != nil
                    await hub.host(paused ? .resume : .pause)
                case "s": await hub.host(.skip)
                case "q": return
                default: break
                }
            }
        }
        _ = await keys.value
        events.cancel()
        await server.stop()
    }
}
