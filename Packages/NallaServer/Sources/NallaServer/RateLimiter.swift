/// At most `limit` join attempts per IP in any rolling `window` seconds.
public struct JoinRateLimiter: Sendable {
    let limit: Int
    let window: Double
    private var attempts: [String: [Double]] = [:]

    public init(limit: Int = 10, window: Double = 60) { self.limit = limit; self.window = window }

    public mutating func allow(ip: String, now: Double) -> Bool {
        var recent = (attempts[ip] ?? []).filter { now - $0 < window }
        guard recent.count < limit else { attempts[ip] = recent; return false }
        recent.append(now)
        attempts[ip] = recent
        return true
    }
}
