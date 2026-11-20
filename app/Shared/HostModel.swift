import CoreGraphics
import Foundation
import Observation
import NallaCore
import NallaServer

/// The host side of a room: starts the server, mirrors the TV snapshot, speaks, and forwards host actions.
@MainActor
@Observable
final class HostModel {
    private(set) var endpoint: RoomEndpoint?
    private(set) var tv: TVView?
    private(set) var hostSeatToken: String?
    private(set) var qr: CGImage?
    private(set) var running = false
    private(set) var networkOK: Bool?
    var lastError: String?

    var prefs = HostPrefs.load() {
        didSet {
            prefs.save()
            voice.enabled = prefs.voiceOn
            guard running else { return }
            if prefs.familyFriendly != oldValue.familyFriendly { send(.setFamilyFriendly(prefs.familyFriendly)) }
            if prefs.voiceOn != oldValue.voiceOn { send(.setVoice(prefs.voiceOn)) }
            if prefs.timer != oldValue.timer { send(.setTimer(prefs.timer)) }
        }
    }

    @ObservationIgnored private var server: RoomServer?
    @ObservationIgnored private var listener: Task<Void, Never>?
    @ObservationIgnored private let voice = HostVoice()

    var players: [PlayerSummary] { tv?.room.players ?? [] }
    var paused: Bool { tv?.overlays.paused != nil }
    var inGame: Bool {
        guard let s = tv?.screen.screen else { return false }
        return !["T1", "T2", "T3", "T4", "T5", "T10"].contains(s)
    }

    func startRoom() async {
        guard !running else { return }
        lastError = nil
        do {
            guard let contentDir = Bundle.main.url(forResource: "Content", withExtension: nil),
                  let controller = Bundle.main.url(forResource: "Controller", withExtension: nil) else {
                lastError = "The app is missing its game files."
                return
            }
            let content = try ContentLibrary.load(from: contentDir)
            let server = RoomServer(controllerRoot: controller, content: content)
            let endpoint = try await server.start()
            self.server = server
            self.endpoint = endpoint
            self.qr = QRCode.image(for: endpoint.joinURL)
            #if DEBUG
            print("NallaBox room \(endpoint.code) \(endpoint.joinURL)")
            #endif
            running = true
            voice.enabled = prefs.voiceOn
            send(.setFamilyFriendly(prefs.familyFriendly))
            send(.setVoice(prefs.voiceOn))
            send(.setTimer(prefs.timer))
            let hub = server.hub
            listener = Task { [weak self] in
                for await e in await hub.events() {
                    guard let self else { return }
                    switch e {
                    case .snapshot(let tv): self.tv = tv
                    case .speak(let line): self.voice.speak(line)
                    case .roomClosed: await self.stopRoom()
                    }
                }
            }
            Task { await checkNetwork() }
        } catch {
            lastError = "Couldn't start the room: \(error.localizedDescription)"
        }
    }

    func checkNetwork() async {
        guard let e = endpoint, let url = URL(string: e.joinURL) else { networkOK = false; return }
        networkOK = await NetworkSelfTest.run(url)
    }

    func stopRoom() async {
        listener?.cancel()
        listener = nil
        voice.stop()
        await server?.stop()
        server = nil
        running = false
        endpoint = nil
        hostSeatToken = nil
        tv = nil
        qr = nil
    }

    func send(_ a: HostAction) {
        guard let hub = server?.hub else { return }
        Task { await hub.host(a) }
    }

    /// iPhone host: reserve seat 1 (leader) for the host's own controller.
    func reserveHostSeat(name: String, colour: PlayerColour) async {
        guard let hub = server?.hub, hostSeatToken == nil else { return }
        hostSeatToken = await hub.reserveHostSeat(name: name, colour: colour)
    }

    var localControllerURL: URL? {
        guard let e = endpoint, let t = hostSeatToken else { return nil }
        return URL(string: e.localControllerURL(seatToken: t))
    }
}
