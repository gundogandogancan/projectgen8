//
//  PhotoShieldLumaMatcherV1.swift — R2 §B/§G: the LIVE-FRAME photo-shield matcher that runs on the SAME cheap
//  in-place luma path the ReplayKit extension already uses for Tier-0 segmentation — NO second full-frame decode.
//
//  WHY THIS EXISTS (mandate §B / §B2): PersonalPhotoShieldV1.matchFrame(cgImage:) needs a CGImage, but the broadcast
//  extension only ever holds a CVPixelBuffer and samples its luma in place (SampleHandler.segmentFrame) — decoding a
//  CGImage per frame would be the exact "heavy model on every frame" the mandate forbids. This type closes that gap:
//  it builds a P006C-compatible PersistedVisualReferenceSignature DIRECTLY from an already-downsampled luma grid
//  (no CoreImage, no vImage, no CGImage), for the WHOLE frame first and — only when the whole-frame hint is
//  ambiguous AND budget allows — for a SMALL, BOUNDED set of region candidates (center crop + content-area crop;
//  NOT dozens of random crops, §B2). It then compares against the persisted reference signatures with the EXISTING
//  VisualSignatureComparator (same locked P006C thresholds — we do not invent a second signature system).
//
//  HONESTY / PRECISION-FIRST (mandate §B3):
//    • Only a HIGH/EXACT perceptual match (near-exact) is ACTIONABLE (`isActionable`). LOW/MEDIUM are recorded as
//      EVIDENCE ONLY and surface as insufficient — never a WARN in V1. This mirrors the FP cost discipline: a
//      perceptual match is a VISUAL match, never a semantic claim about who/what the image depicts.
//    • The luma grid here is produced on-device from the live buffer; the reference signature was produced by the
//      SAME VisualSignatureEngine algorithm family (ahash-8x8 / dhash-9x8 / normvec-16x16) at ingest time, so the
//      two are directly comparable. P006C thresholds were measured on SYNTHETIC structured fixtures — real
//      social-media imagery remains DEVICE_UNVERIFIED (we never claim calibration we do not have).
//
//  STALE-RESULT DISCIPLINE (mandate §B5): a match is stamped with the item identity revision + session id + policy
//  revision + shot id it was computed for. The caller discards any result whose item identity != the current item
//  (reusing the existing generation/identity-authority pattern) — a match computed for item N can never drive a
//  surface for item N+1.
//
//  This type is PURE over the luma bytes + persisted signatures (no IPC, no disk). It lives in GuardianMedia
//  (ungoverned) and is dual-compiled into BOTH the app and the GuardianBroadcastExtension.
//
import Foundation
import GuardianCore
#if canImport(CoreVideo)
import CoreVideo
#endif

// NOTE: this type deliberately depends ONLY on GuardianCore (PersistedVisualReferenceSignature /
// VisualSignatureComparator / VisualSignatureBits all live there). It does NOT import GuardianIntelligence, because
// the ReplayKit broadcast extension links ONLY GuardianCore (keeping the ~50MB extension lean — it must not pull in
// the NaturalLanguage/Vision-heavy GuardianIntelligence module). The algorithm IDs below are the SAME stable P006C
// ids VisualSignatureEngine emits; a reference signature ingested by GuardianIntelligence.VisualSignatureEngine is
// therefore directly comparable to a live signature built here (same ahash-8x8 / dhash-9x8 / normvec-16x16 family).

/// §B2 — a bounded region candidate the matcher evaluates. V1 ships exactly three (WHOLE, CENTER, CONTENT): the
/// whole frame first (cheapest, catches full-screen references), then — only if the whole-frame hint is ambiguous —
/// a center crop (the user's photo centered with chrome around it) and a "content area" crop (a social feed's media
/// region: the horizontal band below the top bar and above the action buttons). This is the "small bounded set" the
/// mandate asks for, NOT dozens of random crops. Each ROI is a normalized sub-rect of the frame (0..1).
public enum PhotoShieldROIV1: String, Sendable, Equatable, CaseIterable {
    case whole = "WHOLE"
    case center = "CENTER"
    case content = "CONTENT"
    /// Normalized (x0,y0,x1,y1) sub-rect of the frame this ROI samples.
    public var rect: (x0: Double, y0: Double, x1: Double, y1: Double) {
        switch self {
        case .whole:   return (0.0, 0.0, 1.0, 1.0)
        case .center:  return (0.15, 0.15, 0.85, 0.85)
        // Social-feed media band: skip the top status/nav bar (~12%) and the bottom caption/action area (~22%).
        case .content: return (0.02, 0.12, 0.98, 0.78)
        }
    }
}

/// §B4 — the FULL-PROVENANCE outcome of a live-frame photo-shield pass. Every field the mandate's §2.3 chain needs
/// so the Guardian decision + timeline carry an honest, non-fabricated record. `state` is the REUSED P006C match
/// tier; `isActionable` is TRUE only for a near-exact (HIGH/EXACT) visual match — the precision-first V1 law.
public struct PhotoShieldLiveMatchV1: Sendable, Equatable {
    public let ruleID: String
    public let featureID: String
    public let state: ShieldMatchState
    public let roi: PhotoShieldROIV1
    public let aHashHamming: Int?
    public let dHashHamming: Int?
    // Provenance (mandate §B4 / §2.3) — carried so a match for item N can never be reused for item N+1.
    public let itemIdentityRevision: Int
    public let policyRevision: UInt64
    public let sessionID: String
    public let shotID: UInt64
    public let eventEpoch: Double

    /// §B3 — ONLY a near-exact perceptual match may drive a WARN surface in V1. LOW/MEDIUM are evidence-only.
    public var isActionable: Bool { state == .matchHigh || state == .matchExact }
    /// A real (any-tier) visual match, recorded as evidence regardless of actionability.
    public var isAnyMatch: Bool { state.isMatch }

    public init(ruleID: String, featureID: String, state: ShieldMatchState, roi: PhotoShieldROIV1,
                aHashHamming: Int?, dHashHamming: Int?, itemIdentityRevision: Int, policyRevision: UInt64,
                sessionID: String, shotID: UInt64, eventEpoch: Double) {
        self.ruleID = ruleID; self.featureID = featureID; self.state = state; self.roi = roi
        self.aHashHamming = aHashHamming; self.dHashHamming = dHashHamming
        self.itemIdentityRevision = itemIdentityRevision; self.policyRevision = policyRevision
        self.sessionID = sessionID; self.shotID = shotID; self.eventEpoch = eventEpoch
    }
}

/// §B/§B6 — the live photo-shield matcher. Stateless; the caller (SampleHandler) owns throttle/governor state. The
/// signature-building is PURE over a raw 8-bit luma plane, so it is unit-testable off-device by handing it a
/// synthetic luma grid (no CoreVideo needed in tests).
public enum PhotoShieldLumaMatcherV1 {

    // P006C stable algorithm IDs (identical to GuardianIntelligence.VisualSignatureEngine.{aHash,dHash,vec}Algo — kept
    // as literals so this type needs no GuardianIntelligence dependency; see the module note above).
    static let aHashAlgo = "ahash-8x8-v1"
    static let dHashAlgo = "dhash-9x8-v1"
    static let vecAlgo = "normvec-16x16-v1"

    /// Decode a persisted reference signature from a durable feature's bytes (a pure JSONDecoder over the GuardianCore
    /// `PersistedVisualReferenceSignature` — no GuardianIntelligence needed). Mirrors
    /// `ShieldVisualReferenceMatcher.decodeSignature`, which GuardianIntelligence provides for the app side.
    static func decodeSignature(_ feature: DerivedReferenceFeature) -> PersistedVisualReferenceSignature? {
        try? JSONDecoder().decode(PersistedVisualReferenceSignature.self, from: feature.serializedFeature)
    }

    // MARK: - §G — stable, collision-free persistent rule id (NOT hashValue, which is unstable across processes).

    /// §G FIX — a deterministic, process-stable rule id for a photo reference, derived from a FNV-1a digest over the
    /// label bytes + creation epoch (NOT Swift `hashValue`, which is randomized per process and would make a rule's
    /// id differ between the app that wrote it and the extension that reads it). Re-adding the SAME label at the SAME
    /// epoch yields the SAME id (so a replace is stable); different labels/epochs collide only on a full 64-bit FNV
    /// collision (astronomically unlikely for user labels). Format: `photo-<hex16>` — opaque, no raw label leak.
    public static func stableRuleID(forLabel label: String, createdAtEpoch: Double) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for b in label.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        // Fold the creation epoch (ms, rounded) into the digest so two different references with the same label do
        // not collide, while a stable re-add (same label + same epoch) reproduces the id.
        let ms = UInt64(max(0, createdAtEpoch) * 1000.0)
        withUnsafeBytes(of: ms.littleEndian) { for b in $0 { h = (h ^ UInt64(b)) &* 0x100000001b3 } }
        return "photo-" + String(format: "%016llx", h)
    }

    /// §G MIGRATION — recognise a legacy `photo-<n>-<epoch>` (hashValue-based) id so existing stored rules still load
    /// and match (we tolerate them; we never rewrite the user's store silently). Any id starting with `photo-` is a
    /// photo rule; the matcher keys off the persisted feature's ruleID regardless of the id's internal format.
    public static func isPhotoRuleID(_ ruleID: String) -> Bool { ruleID.hasPrefix("photo-") }

    // MARK: - §B2 — build a P006C signature from an in-place luma grid (no CGImage decode).

    /// Build a `PersistedVisualReferenceSignature` from a raw 8-bit luma plane, sampling ONLY the given ROI sub-rect.
    /// This reproduces exactly what `VisualSignatureEngine.signature(from:)` computes (ahash-8x8 mean-threshold,
    /// dhash-9x8 row-gradient, normvec-16x16 mean-centered) but reads the luma directly — so a live frame already in
    /// memory as luma never needs a CoreGraphics render. PURE + testable with a synthetic grid.
    ///
    /// - Parameters:
    ///   - luma: row-major 8-bit luma, `width*height` bytes.
    ///   - roi: normalized sub-rect to sample (whole frame = full 0..1).
    ///   - ruleID: stamped into the signature (matcher ignores it at compare time; kept for provenance).
    ///   - nowEpoch: creation stamp for the signature components.
    public static func signature(luma: [UInt8], width: Int, height: Int, roi: PhotoShieldROIV1,
                                 ruleID: String, nowEpoch: Double) -> PersistedVisualReferenceSignature? {
        guard width >= 8, height >= 8, luma.count >= width * height else { return nil }
        let r = roi.rect
        // Nearest-neighbour sample of the ROI at a target grid size (grid aligned to the engine's hash dimensions).
        func sampleGrid(_ gw: Int, _ gh: Int) -> [UInt8] {
            var out = [UInt8](repeating: 0, count: gw * gh)
            for gy in 0..<gh {
                let yf = r.y0 + (r.y1 - r.y0) * (Double(gy) + 0.5) / Double(gh)
                let y = min(height - 1, max(0, Int(yf * Double(height))))
                for gx in 0..<gw {
                    let xf = r.x0 + (r.x1 - r.x0) * (Double(gx) + 0.5) / Double(gw)
                    let x = min(width - 1, max(0, Int(xf * Double(width))))
                    out[gy * gw + gx] = luma[y * width + x]
                }
            }
            return out
        }
        let g8 = sampleGrid(8, 8), g9 = sampleGrid(9, 8), g16 = sampleGrid(16, 16)

        // aHash: bit set when pixel >= mean (identical rule to VisualSignatureEngine).
        let mean = g8.reduce(0) { $0 + Int($1) } / max(1, g8.count)
        var aBits: UInt64 = 0
        for (i, p) in g8.enumerated() where Int(p) >= mean { aBits |= (1 << UInt64(i)) }
        // dHash: per-row next-pixel-brighter (9 wide → 8 comparisons × 8 rows).
        var dBits: UInt64 = 0; var bit = 0
        for row in 0..<8 { for col in 0..<8 {
            let l = g9[row * 9 + col]; let rr = g9[row * 9 + col + 1]
            if rr > l { dBits |= (1 << UInt64(bit)) }; bit += 1
        } }
        // Normalized vector: 256 floats mean-centered (brightness tolerance).
        var vec = g16.map { Float($0) / 255.0 }
        let vMean = vec.reduce(0, +) / Float(vec.count)
        vec = vec.map { $0 - vMean }

        let rev = PersistedVisualReferenceSignature.currentEngineRevision
        func comp(_ kind: VisualSignatureComponent.Kind, _ algo: String, _ dim: Int, _ data: Data, _ norm: String) -> VisualSignatureComponent {
            VisualSignatureComponent(kind: kind, algorithmID: algo, engineRevision: rev, dimension: dim,
                                     data: data, normalization: norm, createdAtEpoch: nowEpoch)
        }
        return PersistedVisualReferenceSignature(ruleID: ruleID, components: [
            comp(.aHash, Self.aHashAlgo, 64, VisualSignatureBits.pack(aBits), "mean-threshold"),
            comp(.dHash, Self.dHashAlgo, 64, VisualSignatureBits.pack(dBits), "row-gradient"),
            comp(.normVector, Self.vecAlgo, 256, VisualSignatureBits.floatsToData(vec), "mean-centered-0..1"),
        ])
    }

    // MARK: - §B2 — match a live luma frame against persisted reference features (bounded ROI escalation).

    /// The outcome of a full live-frame pass: the strongest match found (if any), plus the measured cost telemetry
    /// the mandate's §E asks for (how many signatures we computed, how many ROIs we evaluated). The caller stamps the
    /// provenance; this function returns the raw per-feature comparison so the stamping stays in one place.
    public struct PassResultV1: Sendable, Equatable {
        public let best: PhotoShieldLiveMatchV1?
        public let signaturesComputed: Int
        public let roisEvaluated: Int
        public init(best: PhotoShieldLiveMatchV1?, signaturesComputed: Int, roisEvaluated: Int) {
            self.best = best; self.signaturesComputed = signaturesComputed; self.roisEvaluated = roisEvaluated
        }
    }

    /// §B2 — match a raw luma frame against ALL persisted image-reference features. Strategy (precision-first, cost-
    /// bounded): (1) compute the WHOLE-frame live signature ONCE and compare to every reference; if any reference is
    /// already an ACTIONABLE (HIGH/EXACT) match we STOP (cheapest win). (2) Otherwise, when `allowROIEscalation` is
    /// true (the caller's budget permits), compute the CENTER + CONTENT ROI signatures and compare — this catches a
    /// reference embedded inside social-app chrome. We keep the STRONGEST real match across all ROIs. Non-image /
    /// corrupt / incompatible features are skipped (never fabricated into a match).
    public static func matchLuma(_ luma: [UInt8], width: Int, height: Int,
                                 features: [DerivedReferenceFeature],
                                 itemIdentityRevision: Int, policyRevision: UInt64, sessionID: String,
                                 shotID: UInt64, nowEpoch: Double,
                                 allowROIEscalation: Bool) -> PassResultV1 {
        let comparator = VisualSignatureComparator()
        // Decode the reference signatures once (ignore non-image / corrupt / undecodable features — honest skip).
        let refs: [(feature: DerivedReferenceFeature, sig: PersistedVisualReferenceSignature)] = features.compactMap {
            guard $0.featureType == .image || $0.featureType == .logo,
                  let sig = decodeSignature($0) else { return nil }
            return ($0, sig)
        }
        guard !refs.isEmpty else { return PassResultV1(best: nil, signaturesComputed: 0, roisEvaluated: 0) }

        var best: PhotoShieldLiveMatchV1?
        var sigCount = 0
        var roiCount = 0

        func evaluate(_ roi: PhotoShieldROIV1) -> Bool {   // returns true if an ACTIONABLE match was found at this ROI
            guard let live = signature(luma: luma, width: width, height: height, roi: roi,
                                       ruleID: "live", nowEpoch: nowEpoch) else { return false }
            sigCount += 1; roiCount += 1
            var actionableHere = false
            for ref in refs {
                let (state, d) = comparator.compare(live, ref.sig)
                guard state.isMatch else { continue }
                let candidate = PhotoShieldLiveMatchV1(
                    ruleID: ref.feature.ruleID, featureID: ref.feature.featureID, state: state, roi: roi,
                    aHashHamming: d?.aHashHamming, dHashHamming: d?.dHashHamming,
                    itemIdentityRevision: itemIdentityRevision, policyRevision: policyRevision,
                    sessionID: sessionID, shotID: shotID, eventEpoch: nowEpoch)
                if candidate.state.matchRank > (best?.state.matchRank ?? ShieldMatchState.noMatch.matchRank) {
                    best = candidate
                }
                if candidate.isActionable { actionableHere = true }
            }
            return actionableHere
        }

        // (1) Whole-frame first.
        if evaluate(.whole) { return PassResultV1(best: best, signaturesComputed: sigCount, roisEvaluated: roiCount) }
        // (2) Bounded ROI escalation only when the whole-frame hint was NOT already actionable AND budget permits.
        if allowROIEscalation {
            if evaluate(.center) { return PassResultV1(best: best, signaturesComputed: sigCount, roisEvaluated: roiCount) }
            _ = evaluate(.content)
        }
        return PassResultV1(best: best, signaturesComputed: sigCount, roisEvaluated: roiCount)
    }

    #if canImport(CoreVideo)
    /// §B1 — extract the row-major 8-bit luma plane from a CVPixelBuffer WITHOUT a CGImage decode. Handles the two
    /// formats ReplayKit delivers: 420 bi-planar YUV (plane 0 is luma) and 32BGRA (we take the B channel as a cheap
    /// luma proxy — the signature is brightness-structure based and mean-centered, so a single-channel proxy is
    /// sufficient for the perceptual hash, exactly as the existing in-place segmentFrame path does). The buffer is
    /// locked read-only and never retained. Returns nil on an unsupported/degenerate buffer (honest failure).
    public static func lumaPlane(from px: CVPixelBuffer) -> (luma: [UInt8], width: Int, height: Int)? {
        CVPixelBufferLockBaseAddress(px, .readOnly); defer { CVPixelBufferUnlockBaseAddress(px, .readOnly) }
        let w = CVPixelBufferGetWidth(px), h = CVPixelBufferGetHeight(px)
        guard w >= 8, h >= 8 else { return nil }
        let fmt = CVPixelBufferGetPixelFormatType(px)
        // Downsample target: cap the sampled grid so we never copy a full 1080p plane (cost discipline §F). We sample
        // at most ~128px on the long side — more than enough for 8/9/16-wide hash grids, a tiny bounded buffer.
        let maxSide = 128
        let scale = max(1, max(w, h) / maxSide)
        let dw = max(8, w / scale), dh = max(8, h / scale)
        guard let base = CVPixelBufferGetBaseAddressOfPlane(px, 0) ?? CVPixelBufferGetBaseAddress(px) else { return nil }
        let stride = CVPixelBufferGetBytesPerRowOfPlane(px, 0) != 0 ? CVPixelBufferGetBytesPerRowOfPlane(px, 0)
                                                                    : CVPixelBufferGetBytesPerRow(px)
        let bpp = (fmt == kCVPixelFormatType_32BGRA || fmt == kCVPixelFormatType_32ARGB) ? 4 : 1
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        var out = [UInt8](repeating: 0, count: dw * dh)
        for y in 0..<dh {
            let sy = min(h - 1, y * scale)
            for x in 0..<dw {
                let sx = min(w - 1, x * scale)
                out[y * dw + x] = ptr[sy * stride + sx * bpp]
            }
        }
        return (out, dw, dh)
    }
    #endif
}
