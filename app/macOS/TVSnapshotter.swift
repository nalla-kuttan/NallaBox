import AppKit
import SwiftUI
import NallaCore

/// Debug aid: with `-tvSnapshotDir <dir>` the Mac app writes each new TV screen (and overlay state)
/// to <dir>/<screen>[-state].png at 1920×1080, for comparing against design/mockups/_shots.
@MainActor
final class TVSnapshotter {
    static let shared = TVSnapshotter()
    let dir: URL? = UserDefaults.standard.string(forKey: "tvSnapshotDir").map { URL(fileURLWithPath: $0) }
    private var written: Set<String> = []

    func capture(_ tv: TVView, qr: CGImage?) {
        guard let dir else { return }
        var name = tv.screen.screen
        if tv.overlays.paused != nil { name += "-paused" }
        if !tv.overlays.reconnecting.isEmpty { name += "-reconnecting" }
        if tv.overlays.toast != nil { name += "-toast" }
        if let state = tv.screen.data["state"]?.string { name += "-\(state)" }
        guard !written.contains(name) else { return }
        written.insert(name)
        // Let the face/text settle a moment, then render.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            let view = TVRootView(tv: tv, qr: qr).frame(width: 1920, height: 1080)
            let r = ImageRenderer(content: view)
            r.scale = 1
            guard let cg = r.cgImage else { return }
            let rep = NSBitmapImageRep(cgImage: cg)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(name).png"))
        }
    }
}
