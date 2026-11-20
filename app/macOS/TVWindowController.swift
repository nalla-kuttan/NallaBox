import AppKit
import SwiftUI

/// The game on a second display: a borderless window covering the chosen screen.
@MainActor
final class TVWindowController {
    private var window: NSWindow?
    private let model: HostModel

    init(model: HostModel) { self.model = model }

    func show(on screen: NSScreen) {
        close()
        let w = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
        w.isReleasedWhenClosed = false
        w.level = .mainMenu + 1
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        w.backgroundColor = NSColor(NB.Palette.ink)
        w.contentView = NSHostingView(rootView: TVHostView(model: model))
        w.setFrame(screen.frame, display: true)
        w.orderFrontRegardless()
        window = w
    }

    func close() {
        window?.orderOut(nil)
        window = nil
    }
}

/// The TV as the host model sees it (used on the external screen and as the room window's preview).
struct TVHostView: View {
    var model: HostModel
    var body: some View {
        if let tv = model.tv {
            TVRootView(tv: tv, qr: model.qr, captionSize: model.prefs.captions.points)
                .onChange(of: tv, initial: true) { TVSnapshotter.shared.capture(tv, qr: model.qr) }
        } else {
            NB.Palette.ink
        }
    }
}
