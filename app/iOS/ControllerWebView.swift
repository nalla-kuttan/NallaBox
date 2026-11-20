import SwiftUI
import WebKit

/// The host's own controller: the same web page guests use, loaded from the local server.
struct ControllerWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let v = WKWebView(frame: .zero, configuration: config)
        v.isOpaque = false
        v.backgroundColor = UIColor(NB.Palette.ink)
        v.scrollView.backgroundColor = UIColor(NB.Palette.ink)
        v.scrollView.bounces = false
        v.scrollView.contentInsetAdjustmentBehavior = .never
        v.load(URLRequest(url: url))
        return v
    }

    func updateUIView(_ v: WKWebView, context: Context) {
        if v.url?.absoluteString != url.absoluteString, v.url?.host != url.host { v.load(URLRequest(url: url)) }
    }
}
