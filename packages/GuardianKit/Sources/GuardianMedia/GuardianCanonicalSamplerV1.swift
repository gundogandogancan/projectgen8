//
//  GuardianCanonicalSamplerV1.swift — R3 §1.1: the ONE CANONICAL SAMPLING CONTRACT shared by BOTH photo-shield paths.
//
//  WHY THIS EXISTS (R3 §1 — the top R2 defect): the SAME user image reached only MEDIUM/LOW across the two paths,
//  and only HIGH/EXACT is actionable — so a user looking at their own forbidden image could get NO warning. The two
//  paths diverged in THREE ways:
//    1. CHANNEL. The ingest path (VisualSignatureEngine, via CGColorSpaceCreateDeviceGray) produced a real luminance;
//       the live path's `lumaPlane` took ONLY the B channel of BGRA — a blue-only proxy, not luminance. Different
//       bytes → different hash bits → a weaker match tier for identical content.
//    2. SAMPLING. The ingest path rendered via CGContext at the EXACT grid size with `.medium` interpolation (an
//       AREA/box average of the source). The live path sampled NEAREST-NEIGHBOUR, twice (first a ~128px NN downsample,
//       then a second NN down to 8×8). Two lossy point-samples vs one area average → the aHash mean threshold and the
//       dHash row gradient landed on different sides of the boundary for many pixels.
//    3. NO VERSIONED CONTRACT tying the two together, so a drift in either path was invisible.
//
//  THE FIX: a single pure function — `grid(fromLuma:width:height:roi:targetW:targetH)` — that performs an AREA-AVERAGE
//  (box filter) downsample of a full-resolution 8-bit luma plane into the exact target grid. BOTH paths feed it:
//    • The LIVE path: `PhotoShieldLumaMatcherV1.lumaPlane` extracts a FULL-RES real-luminance plane (BT.601 from B,G,R
//      for BGRA/ARGB, or plane-0 for YUV), then this sampler area-averages it to 8×8 / 9×8 / 16×16.
//    • The INGEST path: `PersonalPhotoShieldV1` renders the CGImage to a full-res real-luminance plane (device-gray),
//      then this SAME sampler area-averages it to the SAME grids. No more CGContext-vs-NN mismatch.
//  Area averaging is the headless, platform-independent equivalent of CGContext's `.medium` interpolation for a
//  downscale, so the two paths now produce near-identical grids → the aHash/dHash/vector bits agree → the SAME image
//  reaches HIGH/EXACT on both sides.
//
//  VERSIONED (`basisTag`): the grids a signature was built from now carry an explicit sampling-basis tag. A signature
//  built under the OLD (pre-canonical) basis is NOT silently compared against a canonical one — it is surfaced as
//  NEEDS_REAUTHOR so the user re-adds the reference (or it is reauthored on load where the raw basis is still
//  available). We never mix bases and quietly match.
//
//  PURE + headless (no CoreGraphics, no CoreVideo). Lives in GuardianMedia (GuardianCore is frozen — §1.1 change-
//  control note), dual-compiled into the app AND the extension. Unit-testable with a synthetic luma grid.
//
import Foundation

public enum GuardianCanonicalSamplerV1 {

    /// R3 §1.1 — the sampling-basis version tag. Any signature built through the canonical sampler carries this in its
    /// algorithm id suffix; the comparator path treats a non-canonical basis as NEEDS_REAUTHOR rather than matching it.
    public static let basisTag = "canon-area-v1"

    /// BT.601 integer luma weights (×1024) for a BGRA/ARGB byte triple. Rec.601 (Y = 0.299R + 0.587G + 0.114B) is the
    /// classic SD luminance; it matches what a gray colour-space render approximates closely enough that the perceptual
    /// hash bits agree. Integer math keeps the live per-frame path allocation-free and deterministic across devices.
    @inline(__always)
    public static func luma601(r: UInt8, g: UInt8, b: UInt8) -> UInt8 {
        let y = (306 &* Int(r)) &+ (601 &* Int(g)) &+ (117 &* Int(b))   // 306+601+117 = 1024
        return UInt8(truncatingIfNeeded: y >> 10)
    }

    /// R3 §1.1 — AREA-AVERAGE (box filter) downsample of a full-resolution row-major 8-bit luma plane into a
    /// `targetW × targetH` grid, sampling ONLY the normalized `roi` sub-rect. This is the SINGLE sampling path both
    /// the ingest and the live matcher use, so identical content yields identical grids regardless of which path
    /// produced the source plane.
    ///
    /// Each output cell averages the full block of source pixels it covers (clamped to the ROI), so no source detail is
    /// dropped the way a single nearest-neighbour point-sample drops it. When the source is smaller than the target in
    /// some dimension (tiny image), the block collapses to a single pixel (graceful, never out-of-bounds).
    ///
    /// - Returns: `targetW*targetH` bytes, or nil on a degenerate input (too small / size mismatch) — an honest
    ///   failure the caller surfaces as UNAVAILABLE, never a wrong read.
    public static func grid(fromLuma luma: [UInt8], width: Int, height: Int,
                            roi: (x0: Double, y0: Double, x1: Double, y1: Double),
                            targetW: Int, targetH: Int) -> [UInt8]? {
        guard width >= 1, height >= 1, targetW >= 1, targetH >= 1,
              luma.count >= width * height,
              roi.x1 > roi.x0, roi.y1 > roi.y0 else { return nil }
        // ROI mapped to source pixel bounds (clamped). We average the block [bx0,bx1) × [by0,by1) per output cell.
        let rx0 = max(0.0, min(1.0, roi.x0)), rx1 = max(0.0, min(1.0, roi.x1))
        let ry0 = max(0.0, min(1.0, roi.y0)), ry1 = max(0.0, min(1.0, roi.y1))
        let spanX = (rx1 - rx0) * Double(width)
        let spanY = (ry1 - ry0) * Double(height)
        guard spanX > 0, spanY > 0 else { return nil }
        var out = [UInt8](repeating: 0, count: targetW * targetH)
        luma.withUnsafeBufferPointer { src in
            for gy in 0..<targetH {
                // Vertical block bounds for this output row.
                let y0f = ry0 * Double(height) + spanY * (Double(gy) / Double(targetH))
                let y1f = ry0 * Double(height) + spanY * (Double(gy + 1) / Double(targetH))
                var by0 = Int(y0f.rounded(.down)); var by1 = Int(y1f.rounded(.up))
                by0 = min(height - 1, max(0, by0)); by1 = min(height, max(by0 + 1, by1))
                for gx in 0..<targetW {
                    let x0f = rx0 * Double(width) + spanX * (Double(gx) / Double(targetW))
                    let x1f = rx0 * Double(width) + spanX * (Double(gx + 1) / Double(targetW))
                    var bx0 = Int(x0f.rounded(.down)); var bx1 = Int(x1f.rounded(.up))
                    bx0 = min(width - 1, max(0, bx0)); bx1 = min(width, max(bx0 + 1, bx1))
                    var sum = 0, n = 0
                    var y = by0
                    while y < by1 {
                        let row = y * width
                        var x = bx0
                        while x < bx1 { sum += Int(src[row + x]); n += 1; x += 1 }
                        y += 1
                    }
                    out[gy * targetW + gx] = UInt8(truncatingIfNeeded: n > 0 ? sum / n : 0)
                }
            }
        }
        return out
    }
}
