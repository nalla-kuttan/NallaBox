import Foundation

enum NetworkSelfTest {
    /// Fetches the join page over the LAN address, as a phone would. False when it doesn't answer in 3 s.
    static func run(_ url: URL) async -> Bool {
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 3)
        req.httpMethod = "GET"
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        guard let (_, resp) = try? await session.data(for: req) else { return false }
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }
}
