import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

enum QRCode {
    /// A crisp QR code for `text`, each module `scale` pixels wide.
    static func image(for text: String, scale: CGFloat = 12) -> CGImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = "M"
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else { return nil }
        return CIContext(options: [.useSoftwareRenderer: false]).createCGImage(out, from: out.extent)
    }
}
