import Foundation

/// Time for the hub, injectable so tests run instantly. Seconds since 1970.
public protocol HubClock: Sendable {
    func now() -> Double
    func sleep(until: Double) async throws
}

public struct SystemClock: HubClock {
    public init() {}
    public func now() -> Double { Date().timeIntervalSince1970 }
    public func sleep(until t: Double) async throws {
        let d = t - now()
        if d > 0 { try await Task.sleep(for: .seconds(d)) }
    }
}

/// A clock that only moves when told to. `advance(by:)` wakes every sleeper that is now due.
public final class ManualClock: HubClock, @unchecked Sendable {
    private let lock = NSLock()
    private var t: Double
    private var sleepers: [(id: UUID, until: Double, cont: CheckedContinuation<Void, Error>)] = []

    public init(start: Double = 1_000_000) { t = start }

    public func now() -> Double { lock.lock(); defer { lock.unlock() }; return t }

    public func sleep(until: Double) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                lock.lock()
                if until <= t || Task.isCancelled {
                    lock.unlock()
                    if Task.isCancelled { c.resume(throwing: CancellationError()) } else { c.resume() }
                    return
                }
                sleepers.append((id, until, c))
                lock.unlock()
            }
        } onCancel: {
            lock.lock()
            let hit = sleepers.firstIndex { $0.id == id }.map { sleepers.remove(at: $0) }
            lock.unlock()
            hit?.cont.resume(throwing: CancellationError())
        }
    }

    public func advance(by d: Double) async {
        let due = lock.withLock {
            t += d
            let due = sleepers.filter { $0.until <= t }
            sleepers.removeAll { $0.until <= t }
            return due
        }
        for s in due { s.cont.resume() }
        for _ in 0..<5 { await Task.yield() }
    }
}
