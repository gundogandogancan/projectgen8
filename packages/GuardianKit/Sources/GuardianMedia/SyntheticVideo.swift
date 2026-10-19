import Foundation
#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreText

// MARK: - Synthetic MP4 generator (PROMPT 005 §30) — project-OWNED, legally-safe real media fixtures.
// Writes a real H.264 MP4 headless via AVAssetWriter so the decode/OCR/scene pipeline can be proven on
// a genuine video-decode path (not synthetic frame descriptors). No copyrighted/private media.

public enum SyntheticVideo {

    public struct Spec: Sendable {
        public let durationSeconds: Double
        public let fps: Int
        public let width: Int
        public let height: Int
        /// (timeSeconds, text) overlays drawn at/after the given time.
        public let textEvents: [(Double, String)]
        /// (timeSeconds, gray) background scene changes.
        public let sceneChanges: [(Double, CGFloat)]
        public init(durationSeconds: Double, fps: Int = 6, width: Int = 320, height: Int = 180,
                    textEvents: [(Double, String)] = [], sceneChanges: [(Double, CGFloat)] = []) {
            self.durationSeconds = durationSeconds; self.fps = fps; self.width = width; self.height = height
            self.textEvents = textEvents; self.sceneChanges = sceneChanges
        }
    }

    /// Write the MP4 to `url`. Returns true on success. Overwrites existing.
    public static func write(_ spec: Spec, to url: URL) async -> Bool {
        try? FileManager.default.removeItem(at: url)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return false }
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: spec.width,
            AVVideoHeightKey: spec.height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: spec.width,
            kCVPixelBufferHeightKey as String: spec.height
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
        guard writer.canAdd(input) else { return false }
        writer.add(input)
        guard writer.startWriting() else { return false }
        writer.startSession(atSourceTime: .zero)

        let totalFrames = Int(spec.durationSeconds * Double(spec.fps))
        let scale: Int32 = 600
        for i in 0..<totalFrames {
            let t = Double(i) / Double(spec.fps)
            // current scene gray = last sceneChange ≤ t (default 0.9 light)
            let gray = spec.sceneChanges.filter { $0.0 <= t }.last?.1 ?? 0.9
            // current text = last textEvent ≤ t within 1.0s window
            let text = spec.textEvents.filter { $0.0 <= t && t < $0.0 + 1.0 }.last?.1
            guard let img = frame(gray: gray, text: text, w: spec.width, h: spec.height),
                  let pb = pixelBuffer(from: img, w: spec.width, h: spec.height) else { continue }
            while !input.isReadyForMoreMediaData { try? await Task.sleep(nanoseconds: 1_000_000) }
            adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(Int32(i) * (scale / Int32(spec.fps))), timescale: scale))
        }
        input.markAsFinished()
        await writer.finishWriting()
        return writer.status == .completed
    }

    static func frame(gray: CGFloat, text: String?, w: Int, h: Int) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: gray, green: gray, blue: gray, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        if let text {
            let font = CTFontCreateWithName("Helvetica" as CFString, 40, nil)
            let attrs: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1)]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs) as CFAttributedString)
            ctx.textPosition = CGPoint(x: 16, y: CGFloat(h)/2 - 14)
            CTLineDraw(line, ctx)
        }
        return ctx.makeImage()
    }

    static func pixelBuffer(from image: CGImage, w: Int, h: Int) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32ARGB, attrs, &pb)
        guard let buf = pb else { return nil }
        CVPixelBufferLockBaseAddress(buf, [])
        defer { CVPixelBufferUnlockBaseAddress(buf, []) }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return buf
    }
}
#endif
