import Foundation
import CoreGraphics
import GuardianCore

// MARK: - Visual signature engine (PROMPT 006C Strategy A) — serializable perceptual signature under OUR control.
// aHash(64) + dHash(64) + normalized 16×16 vector, computed from CoreGraphics grayscale. NO Vision feature-print,
// NO raw image retained. The persisted signature is fully matcher-consumable after process teardown.

public struct VisualSignatureEngine: Sendable {
    public static let aHashAlgo = "ahash-8x8-v1"
    public static let dHashAlgo = "dhash-9x8-v1"
    public static let vecAlgo = "normvec-16x16-v1"
    public let engineRevision: String
    public init(engineRevision: String = PersistedVisualReferenceSignature.currentEngineRevision) { self.engineRevision = engineRevision }

    public func signature(from cgImage: CGImage, ruleID: String, nowEpoch: Double) -> PersistedVisualReferenceSignature? {
        guard let g8 = grayscale(cgImage, 8, 8),
              let g9 = grayscale(cgImage, 9, 8),
              let g16 = grayscale(cgImage, 16, 16) else { return nil }

        // aHash: bit set when pixel >= mean.
        let mean = g8.reduce(0, { $0 + Int($1) }) / max(1, g8.count)
        var aBits: UInt64 = 0
        for (i, p) in g8.enumerated() where Int(p) >= mean { aBits |= (1 << UInt64(i)) }

        // dHash: per-row, bit set when next pixel brighter than current (9 wide → 8 comparisons × 8 rows).
        var dBits: UInt64 = 0; var bit = 0
        for row in 0..<8 { for col in 0..<8 {
            let l = g9[row * 9 + col]; let r = g9[row * 9 + col + 1]
            if r > l { dBits |= (1 << UInt64(bit)) }; bit += 1
        } }

        // Normalized vector: 256 floats in 0..1, mean-centered for brightness tolerance.
        var vec = g16.map { Float($0) / 255.0 }
        let vMean = vec.reduce(0, +) / Float(vec.count)
        vec = vec.map { $0 - vMean }

        func comp(_ kind: VisualSignatureComponent.Kind, _ algo: String, _ dim: Int, _ data: Data, _ norm: String) -> VisualSignatureComponent {
            VisualSignatureComponent(kind: kind, algorithmID: algo, engineRevision: engineRevision, dimension: dim,
                                     data: data, normalization: norm, createdAtEpoch: nowEpoch)
        }
        return PersistedVisualReferenceSignature(ruleID: ruleID, components: [
            comp(.aHash, Self.aHashAlgo, 64, VisualSignatureBits.pack(aBits), "mean-threshold"),
            comp(.dHash, Self.dHashAlgo, 64, VisualSignatureBits.pack(dBits), "row-gradient"),
            comp(.normVector, Self.vecAlgo, 256, VisualSignatureBits.floatsToData(vec), "mean-centered-0..1"),
        ])
    }

    /// Render into a WxH 8-bit grayscale buffer (row-major). Raw pixels never leave this function.
    private func grayscale(_ image: CGImage, _ w: Int, _ h: Int) -> [UInt8]? {
        let space = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                  space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return nil }
        let ptr = data.bindMemory(to: UInt8.self, capacity: w * h)
        return Array(UnsafeBufferPointer(start: ptr, count: w * h))
    }
}
