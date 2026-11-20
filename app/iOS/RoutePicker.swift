import AVKit
import SwiftUI

/// The system AirPlay picker, styled as the H3 route button.
/// `invisible` draws nothing but still opens the menu on tap (laid over our own button).
struct RoutePicker: UIViewRepresentable {
    var invisible = false
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.prioritizesVideoDevices = true
        v.activeTintColor = invisible ? .clear : UIColor(NB.Palette.coral)
        v.tintColor = invisible ? .clear : UIColor(NB.Palette.text)
        return v
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
