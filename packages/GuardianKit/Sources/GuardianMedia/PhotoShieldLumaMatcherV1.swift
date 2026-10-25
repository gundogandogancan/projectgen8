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

    // P006C stable algorithm IDs. R3 §1.1: BOTH the live and the ingest path now build their grids through the SAME
    // GuardianCanonicalSamplerV1 (area-average + real luminance), so the algorithm ids carry the canonical BASIS TAG.
    // A signature whose algorithm id lacks this suffix was built under the OLD (pre-canonical) basis and is treated as
    // NEEDS_REAUTHOR by the comparison path (see `basisOfSignature`) — never silently matched across mixed bases.
    static let aHashAlgo = "ahash-8x8-v1+" + GuardianCanonicalSamplerV1.basisTag
    static let dHashAlgo = "dhash-9x8-v1+" + GuardianCanonicalSamplerV1.basisTag
    static let vecAlgo = "normvec-16x16-v1+" + GuardianCanonicalSamplerV1.basisTag
    // The LEGACY (pre-R3) ids a signature from the old engine would carry (no canonical area-sampling basis).
    static let legacyAHashAlgo = "ahash-8x8-v1"
    static let legacyDHashAlgo = "dhash-9x8-v1"
    static let legacyVecAlgo = "normvec-16x16-v1"

    /// R3 §1.1 — the sampling basis a persisted signature was built under, read from its component algorithm ids. A
    /// `.canonical` signature is directly comparable to a live canonical signature; a `.legacy` one must be reauthored
    /// (surfaced as NEEDS_REAUTHOR) before it can be trusted to match — we never compare across bases silently.
    public enum SignatureBasisV1: String, Sendable, Equatable {
        case canonical = "CANONICAL"          // built through GuardianCanonicalSamplerV1 (R3)
        case legacy = "LEGACY_NEEDS_REAUTHOR" // built pre-R3 (old NN / B-channel / CGContext path) — reauthor needed
        case unknown = "UNKNOWN"              // undecodable / mixed — honest abstention
    }

    /// R3 §1.1 — classify a persisted reference signature's sampling basis from its algorithm ids.
    public static func basisOfSignature(_ sig: PersistedVisualReferenceSignature) -> SignatureBasisV1 {
        guard let a = sig.component(.aHash) else { return .unknown }
        if a.algorithmID.hasSuffix(GuardianCanonicalSamplerV1.basisTag) { return .canonical }
        if a.algorithmID == legacyAHashAlgo { return .legacy }
        return .unknown
    }

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
    /// R3 §6 — the PREFERRED rule id for a NEWLY created photo reference: a UUID minted AT CREATION, with NO
    /// label-derived identity at all. This is strictly more robust than the FNV-1a-over-label scheme:
    ///   • COLLISION-FREE by construction (a 128-bit random UUID, not a 64-bit digest of a guessable label).
    ///   • ANONYMOUS — the label is NOT recoverable from the id even by guessing (the FNV scheme leaked a guessable
    ///     label through a reversible-by-brute-force digest when labels are predictable).
    ///   • STABLE — the id never needs recomputation from the label, so a re-add of the same label is a genuinely new
    ///     rule (the user's intent), and the matcher keys off the persisted `feature.ruleID` regardless.
    /// Legacy `photo-<hex16>` (FNV) and `photo-<n>-<epoch>` (hashValue) ids remain loadable + matchable (see
    /// `isPhotoRuleID`): we key matching off the STORED feature.ruleID, so old rules are never lost.
    public static func newRuleID() -> String { "photo-" + UUID().uuidString.lowercased() }

    /// R3 §6 (migration) — a legacy, LABEL-DERIVED rule id. KEPT for loading/recomputing existing stored rules; NOT
    /// used for new creation anymore (`newRuleID` is). A re-add of the same label at the same epoch still reproduces
    /// this id, so a legacy store that recomputes ids on load stays stable.
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
        // R3 §1.1 — AREA-AVERAGE sampling through the ONE canonical sampler (NOT nearest-neighbour). This is the exact
        // same path the ingest side uses, so identical content lands on identical grids → the hash bits agree → the
        // SAME image reaches HIGH/EXACT on both paths. An area average of a tiny degenerate source fails honestly (nil).
        guard let g8 = GuardianCanonicalSamplerV1.grid(fromLuma: luma, width: width, height: height, roi: r, targetW: 8, targetH: 8),
              let g9 = GuardianCanonicalSamplerV1.grid(fromLuma: luma, width: width, height: height, roi: r, targetW: 9, targetH: 8),
              let g16 = GuardianCanonicalSamplerV1.grid(fromLuma: luma, width: width, height: height, roi: r, targetW: 16, targetH: 16)
        else { return nil }

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
        /// R3 §1.1 — how many of the user's image references are stored under the LEGACY (pre-canonical) basis and so
        /// CANNOT be trusted to match a canonical live signature. These are surfaced as NEEDS_REAUTHOR (the user
        /// re-adds the reference) rather than silently producing a weak/false match across mixed bases. A self-eval
        /// counter (§9) aggregates this so the honest "some rules need reauthoring" state is visible, never hidden.
        public let legacyNeedsReauthor: Int
        public init(best: PhotoShieldLiveMatchV1?, signaturesComputed: Int, roisEvaluated: Int,
                    legacyNeedsReauthor: Int = 0) {
            self.best = best; self.signaturesComputed = signaturesComputed; self.roisEvaluated = roisEvaluated
            self.legacyNeedsReauthor = legacyNeedsReauthor
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
        // R3 §1.1 — SPLIT by sampling basis: only CANONICAL references may be compared against the canonical live
        // signature. LEGACY references (pre-R3) are counted as NEEDS_REAUTHOR and NEVER silently matched (a mixed-basis
        // comparison is unreliable). `.unknown` basis is also excluded (honest abstention).
        var legacyNeedsReauthor = 0
        let refs: [(feature: DerivedReferenceFeature, sig: PersistedVisualReferenceSignature)] = features.compactMap {
            guard $0.featureType == .image || $0.featureType == .logo,
                  let sig = decodeSignature($0) else { return nil }
            switch basisOfSignature(sig) {
            case .canonical: return ($0, sig)
            case .legacy: legacyNeedsReauthor += 1; return nil
            case .unknown: return nil
            }
        }
        guard !refs.isEmpty else {
            return PassResultV1(best: nil, signaturesComputed: 0, roisEvaluated: 0,
                                legacyNeedsReauthor: legacyNeedsReauthor)
        }

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
        if evaluate(.whole) { return PassResultV1(best: best, signaturesComputed: sigCount, roisEvaluated: roiCount, legacyNeedsReauthor: legacyNeedsReauthor) }
        // (2) Bounded ROI escalation only when the whole-frame hint was NOT already actionable AND budget permits.
        if allowROIEscalation {
            if evaluate(.center) { return PassResultV1(best: best, signaturesComputed: sigCount, roisEvaluated: roiCount, legacyNeedsReauthor: legacyNeedsReauthor) }
            _ = evaluate(.content)
        }
        return PassResultV1(best: best, signaturesComputed: sigCount, roisEvaluated: roiCount, legacyNeedsReauthor: legacyNeedsReauthor)
    }

    #if canImport(CoreVideo)
    /// R3 §1.2 — the pixel formats the live path is allowed to read. Anything else is an honest UNAVAILABLE (nil),
    /// NEVER a wrong memory read against an unknown layout. ReplayKit delivers 420f/420v (bi-planar YUV, plane 0 luma)
    /// or 32BGRA; we also accept 32ARGB. An unknown format → the caller records UNAVAILABLE and the photo pass is a
    /// no-op for that frame (no fabricated match, no out-of-bounds read).
    public enum LumaExtractFormatV1: String, Sendable, Equatable {
        case yuv420 = "YUV_420_BIPLANAR"   // plane 0 is a real luma plane
        case bgra = "BGRA_8888"            // real BT.601 luminance computed from B,G,R
        case argb = "ARGB_8888"            // real BT.601 luminance computed from A?,R,G,B layout
        case unsupported = "UNSUPPORTED"   // honest: we will not guess the layout
    }

    /// R3 §1.2 — classify a CVPixelBuffer's format into the explicit supported set (no silent fallthrough).
    public static func extractFormat(_ fmt: OSType) -> LumaExtractFormatV1 {
        switch fmt {
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
             kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            return .yuv420
        case kCVPixelFormatType_32BGRA: return .bgra
        case kCVPixelFormatType_32ARGB: return .argb
        default: return .unsupported
        }
    }

    /// §B1 / R3 §1.2 — extract a row-major 8-bit REAL-LUMINANCE plane from a CVPixelBuffer WITHOUT a CGImage decode,
    /// AREA-AVERAGING to a bounded working size. The fix over R2: (a) BGRA/ARGB now compute true BT.601 luminance from
    /// B,G,R (not the B channel alone — the old blue-only proxy was a primary cause of the cross-path mismatch), (b)
    /// an EXPLICIT pixel-format switch (unknown → nil UNAVAILABLE, never a wrong read), (c) stride/plane-bounds
    /// validation, (d) an AREA-AVERAGE downsample (box filter) instead of the old double nearest-neighbour, matching
    /// the ingest path's interpolation so the two agree. The buffer is locked read-only and never retained.
    ///
    /// The returned plane is a bounded working buffer (≤ ~256px long side) in REAL luma; the signature builder then
    /// area-averages it again to the 8/9/16 hash grids through the SAME canonical sampler. Returns nil on an
    /// unsupported format, a degenerate size, or a plane-bounds inconsistency (all honest failures).
    public static func lumaPlane(from px: CVPixelBuffer) -> (luma: [UInt8], width: Int, height: Int)? {
        let fmtType = CVPixelBufferGetPixelFormatType(px)
        let fmt = extractFormat(fmtType)
        guard fmt != .unsupported else { return nil }   // R3 §1.2 — never guess an unknown layout.
        CVPixelBufferLockBaseAddress(px, .readOnly); defer { CVPixelBufferUnlockBaseAddress(px, .readOnly) }
        let w = CVPixelBufferGetWidth(px), h = CVPixelBufferGetHeight(px)
        guard w >= 8, h >= 8 else { return nil }
        // Bounded working size — AREA-AVERAGE the full frame down to ≤256px long side (ample for 8/9/16 grids, cheap).
        let maxSide = 256
        let scale = max(1, max(w, h) / maxSide)
        let dw = max(8, w / scale), dh = max(8, h / scale)
        var out = [UInt8](repeating: 0, count: dw * dh)

        switch fmt {
        case .yuv420:
            // Plane 0 is the luma plane directly. Validate the plane exists and its stride is sane before reading.
            guard CVPixelBufferGetPlaneCount(px) >= 1,
                  let base = CVPixelBufferGetBaseAddressOfPlane(px, 0) else { return nil }
            let stride = CVPixelBufferGetBytesPerRowOfPlane(px, 0)
            guard stride >= w else { return nil }   // R3 §1.2 — a stride smaller than the width is a bad buffer.
            let ptr = base.assumingMemoryBound(to: UInt8.self)
            areaAverage(dw: dw, dh: dh, srcW: w, srcH: h, into: &out) { sx, sy in ptr[sy * stride + sx] }
        case .bgra, .argb:
            guard let base = CVPixelBufferGetBaseAddress(px) else { return nil }
            let stride = CVPixelBufferGetBytesPerRow(px)
            guard stride >= w * 4 else { return nil }   // R3 §1.2 — 4 bytes/pixel; a short stride is a bad buffer.
            let ptr = base.assumingMemoryBound(to: UInt8.self)
            // BGRA byte order in memory: B,G,R,A. ARGB: A,R,G,B. Compute real BT.601 luminance per source pixel.
            if fmt == .bgra {
                areaAverage(dw: dw, dh: dh, srcW: w, srcH: h, into: &out) { sx, sy in
                    let o = sy * stride + sx * 4
                    return GuardianCanonicalSamplerV1.luma601(r: ptr[o + 2], g: ptr[o + 1], b: ptr[o + 0])
                }
            } else {
                areaAverage(dw: dw, dh: dh, srcW: w, srcH: h, into: &out) { sx, sy in
                    let o = sy * stride + sx * 4
                    return GuardianCanonicalSamplerV1.luma601(r: ptr[o + 1], g: ptr[o + 2], b: ptr[o + 3])
                }
            }
        case .unsupported:
            return nil
        }
        return (out, dw, dh)
    }

    /// Area-average helper: averages each source block mapping to an output cell via `sample(sx,sy) -> luma`. Keeps
    /// the per-format pixel read in one place (closure) while the box-filter loop is shared and bounds-safe.
    @inline(__always)
    private static func areaAverage(dw: Int, dh: Int, srcW: Int, srcH: Int,
                                    into out: inout [UInt8], sample: (Int, Int) -> UInt8) {
        for oy in 0..<dh {
            let by0 = (oy * srcH) / dh, by1 = max(by0 + 1, ((oy + 1) * srcH) / dh)
            for ox in 0..<dw {
                let bx0 = (ox * srcW) / dw, bx1 = max(bx0 + 1, ((ox + 1) * srcW) / dw)
                var sum = 0, n = 0
                var y = by0
                while y < by1 && y < srcH {
                    var x = bx0
                    while x < bx1 && x < srcW { sum += Int(sample(x, y)); n += 1; x += 1 }
                    y += 1
                }
                out[oy * dw + ox] = UInt8(truncatingIfNeeded: n > 0 ? sum / n : 0)
            }
        }
    }
    #endif
}
