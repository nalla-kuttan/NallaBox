import SwiftUI
import WebKit

/// The host's own controller: the same web page guests use, loaded from the local server.
/// Zoom is off (a double tap must never magnify the controller mid-game).
struct ControllerWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { nil }
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let v = WKWebView(frame: .zero, configuration: config)
        v.isOpaque = false
        v.backgroundColor = UIColor(NB.Palette.ink)
        v.scrollView.backgroundColor = UIColor(NB.Palette.ink)
        v.scrollView.bounces = false
        v.scrollView.contentInsetAdjustmentBehavior = .never
        v.scrollView.minimumZoomScale = 1
        v.scrollView.maximumZoomScale = 1
        v.scrollView.pinchGestureRecognizer?.isEnabled = false
        v.scrollView.delegate = context.coordinator
        #if DEBUG
        v.isInspectable = true
        #endif
        v.load(URLRequest(url: url))
        return v
    }

    func updateUIView(_ v: WKWebView, context: Context) {
        if v.url?.host != url.host || v.url?.port != url.port { v.load(URLRequest(url: url)) }
    }
}
