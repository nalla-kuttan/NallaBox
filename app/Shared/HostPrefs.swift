import Foundation
import NallaCore

/// Host settings (Mac M5, iPhone host menu), kept in UserDefaults.
struct HostPrefs: Codable, Equatable {
    var familyFriendly = true
    var timer: TimerSpeed = .x1
    var voiceOn = true
    var largeCaptions = false

    private static let key = "nb.hostPrefs"

    static func load() -> HostPrefs {
        guard let data = UserDefaults.standard.data(forKey: key),
              let p = try? JSONDecoder().decode(HostPrefs.self, from: data) else { return HostPrefs() }
        return p
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.key) }
    }
}
