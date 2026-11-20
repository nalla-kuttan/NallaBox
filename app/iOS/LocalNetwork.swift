import Foundation
import Network

enum LocalNetworkStatus { case granted, denied }

/// Triggers and detects the Local Network permission by browsing for our own Bonjour service
/// (the room must already be advertising). Denied shows up as a DNS "policy denied" error.
@MainActor
final class LocalNetwork {
    func request(timeout: Double = 60) async -> LocalNetworkStatus {
        let browser = NWBrowser(for: .bonjour(type: "_nallabox._tcp", domain: nil), using: .tcp)
        let result: LocalNetworkStatus = await withCheckedContinuation { cont in
            let once = OnceFlag()
            browser.browseResultsChangedHandler = { results, _ in
                if !results.isEmpty, once.take() { cont.resume(returning: .granted) }
            }
            browser.stateUpdateHandler = { state in
                if case .waiting(let e) = state, case .dns(let code) = e, code == -65570, once.take() {
                    cont.resume(returning: .denied)
                }
                if case .failed = state, once.take() { cont.resume(returning: .denied) }
            }
            browser.start(queue: .main)
            Task {
                try? await Task.sleep(for: .seconds(timeout))
                if once.take() { cont.resume(returning: .granted) }
            }
        }
        browser.cancel()
        return result
    }
}

final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func take() -> Bool { lock.withLock { if done { return false }; done = true; return true } }
}
