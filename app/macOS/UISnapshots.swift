#if DEBUG
import AppKit
import SwiftUI

/// Debug aid: with `-tvSnapshotDir <dir>`, also renders the Mac host screens (M1, M2, M2 with M4, M5) to PNG
/// at 1280×800 so they can be compared with design/mockups/_shots/host-mac. `-autoStartRoom YES` starts a room on launch.
@MainActor
enum UISnapshots {
    static func write<V: View>(_ name: String, _ view: V, size: CGSize = CGSize(width: 1280, height: 800)) {
        guard let dir = TVSnapshotter.shared.dir else { return }
        let r = ImageRenderer(content: view.frame(width: size.width, height: size.height).preferredColorScheme(.dark))
        r.scale = 1
        guard let cg = r.cgImage, let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? png.write(to: dir.appendingPathComponent("\(name).png"))
    }

    static func captureStart(model: HostModel, options: [DisplayOption], choice: DisplayChoice) {
        write("M1", M1StartView(model: model, options: options, choice: .constant(choice), start: {}))
    }

    static func captureRoom(model: HostModel, displayName: String) {
        write("M2", M2RoomView(model: model, displayName: displayName))
        if let url = model.endpoint?.joinURL {
            write("M4-panel", M4NetworkPanel(joinURL: url).frame(width: 320).padding(20).background(NB.Palette.ink), size: CGSize(width: 360, height: 330))
        }
        write("M5", M5SettingsSheet(model: model), size: CGSize(width: 480, height: 420))
    }
}
#endif
