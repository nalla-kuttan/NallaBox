import CoreGraphics
import Foundation
import NallaCore

/// TV caption size (M5).
enum CaptionSize: String, Codable, CaseIterable {
    case medium, large, extraLarge
    var points: CGFloat { switch self { case .medium: 36; case .large: 44; case .extraLarge: 52 } }
    var label: String { switch self { case .medium: "Medium"; case .large: "Large"; case .extraLarge: "Extra large" } }
}

/// Host settings (Mac M5, iPhone host menu), kept in UserDefaults.
struct HostPrefs: Codable, Equatable {
    var familyFriendly = true
    var timer: TimerSpeed = .x1
    var voiceOn = true
    var captions: CaptionSize = .medium

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
