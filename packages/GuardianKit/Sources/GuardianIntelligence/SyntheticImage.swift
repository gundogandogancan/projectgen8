import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
import CoreText
import ImageIO
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

// MARK: - Synthetic image generator (TEST_FIXTURE) — no copyrighted/real media
// Renders black text on white via CoreGraphics/CoreText so Vision OCR/feature-print can be tested
// headlessly with legally-safe, original fixtures (PROMPT 002 §14).

public enum SyntheticImage {
    /// A white image with the given text drawn in black. Returns nil if a context can't be made.
    public static func textImage(_ text: String, width: Int = 640, height: Int = 200, fontSize: CGFloat = 56) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: width * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        // Use CoreText attribute keys (CTFont + CGColor) so no AppKit/UIKit dependency is pulled in.
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ]
        let attr = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attr as CFAttributedString)
        ctx.textPosition = CGPoint(x: 24, y: CGFloat(height) / 2 - fontSize / 3)
        CTLineDraw(line, ctx)
        return ctx.makeImage()
    }

    /// Encode a CGImage to PNG bytes (for round-tripping fixtures through a real image decode path).
    public static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        let utType: CFString
        #if canImport(UniformTypeIdentifiers)
        utType = UTType.png.identifier as CFString
        #else
        utType = "public.png" as CFString
        #endif
        guard let dest = CGImageDestinationCreateWithData(data, utType, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    /// A solid-tone image (for negative/variant identity tests).
    public static func solidImage(gray: CGFloat, width: Int = 640, height: Int = 200) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: width * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: gray, green: gray, blue: gray, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }
}
#endif
