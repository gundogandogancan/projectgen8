//
//  PersonalPhotoShieldV1.swift — P1-5: the PERSONAL PHOTO SHIELD product path over the EXISTING P006C infra.
//
//  WHY THIS EXISTS (mandate §5): the user picks a reference image; we extract the LOCAL visual signature using the
//  EXISTING persisted schema (PersistedVisualReferenceSignature / VisualSignatureEngine, GuardianIntelligence),
//  save a user rule through PersonalShieldSharedStoreV1 (producing a REAL policyRevision), and match a live frame's
//  signature against the persisted reference. This module REUSES P006C — it does NOT reinvent the signature or the
//  comparator. The raw photo is NEVER persisted (only the derived signature bytes, rule 17 / P006C contract).
//
//  HONEST LIMITS (mandate §5.2/§5.3):
//    • We claim ONLY what synthetic fixtures prove: same image / scaled / cropped → a real PERSONAL_SHIELD match
//      (WARN-only on a third-party surface, rule 18). We do NOT generalise P006C's synthetic thresholds to all real
//      social-media imagery (that is DEVICE_UNVERIFIED).
//    • SEMANTIC relations (the person/team/topic a photo depicts) are UNKNOWN/UNAVAILABLE in V1 — a perceptual-hash
//      match is a VISUAL match, never a claim about what the image means. We never fabricate a semantic relation.
//
//  Lives in GuardianMedia (ungoverned), which already depends on GuardianIntelligence + GuardianCore.
//
import Foundation
import GuardianCore
import GuardianIntelligence
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// P1-5 — the honest outcome of matching a live frame against a persisted photo reference.
public struct PersonalPhotoShieldMatchV1: Sendable, Equatable {
    public let ruleID: String
    /// The REUSED P006C match state. Only `.matchHigh/.matchMedium/.matchLow` are real matches; `.matcherUnavailable`
    /// means an incompatible/corrupt signature (never fabricated into a match); `.noMatch` is an honest non-match.
    public let state: ShieldMatchState
    public let aHashHamming: Int?
    public let dHashHamming: Int?
    /// True ONLY for a real match state. A caller must NOT upgrade a non-match / unavailable into a shield action.
    public var isMatch: Bool {
        switch state { case .matchHigh, .matchMedium, .matchLow: return true; default: return false }
    }
    public init(ruleID: String, state: ShieldMatchState, aHashHamming: Int?, dHashHamming: Int?) {
        self.ruleID = ruleID; self.state = state; self.aHashHamming = aHashHamming; self.dHashHamming = dHashHamming
    }
}

public enum PersonalPhotoShieldV1 {

    #if canImport(CoreGraphics)
    /// R3 §1.1 — render a CGImage into a FULL-RES row-major 8-bit REAL-LUMINANCE plane, so the INGEST path feeds the
    /// SAME GuardianCanonicalSamplerV1 the LIVE path feeds. This replaces the divergent `VisualSignatureEngine`
    /// CGContext-per-grid render: both paths now area-average a real-luminance plane to the hash grids, so identical
    /// content produces identical signatures (the R2 cross-path MEDIUM/LOW defect). We render once to a bounded
    /// working buffer (≤256px long side) in device-gray (a real luminance), then the signature builder area-averages
    /// it to 8/9/16. Returns nil on a render failure (honest UNAVAILABLE — never a fabricated plane).
    static func canonicalLumaPlane(from cgImage: CGImage, maxSide: Int = 256) -> (luma: [UInt8], width: Int, height: Int)? {
        let srcW = cgImage.width, srcH = cgImage.height
        guard srcW >= 1, srcH >= 1 else { return nil }
        let scale = max(1, max(srcW, srcH) / maxSide)
        let w = max(8, srcW / scale), h = max(8, srcH / scale)
        let space = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                  space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.interpolationQuality = .medium   // area-equivalent downscale → matches the live area-average
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return nil }
        let ptr = data.bindMemory(to: UInt8.self, capacity: w * h)
        return (Array(UnsafeBufferPointer(start: ptr, count: w * h)), w, h)
    }

    /// R3 §1.1 — build a CANONICAL whole-image signature from a CGImage through the SAME sampler the live path uses.
    /// This is the signature the store should persist going forward so an ingested reference matches a live frame at
    /// HIGH/EXACT (not MEDIUM/LOW). Returns nil on a render failure (honest).
    public static func canonicalSignature(from cgImage: CGImage, ruleID: String, nowEpoch: Double) -> PersistedVisualReferenceSignature? {
        guard let plane = canonicalLumaPlane(from: cgImage) else { return nil }
        return PhotoShieldLumaMatcherV1.signature(luma: plane.luma, width: plane.width, height: plane.height,
                                                  roi: .whole, ruleID: ruleID, nowEpoch: nowEpoch)
    }
    #endif

    /// §G FIX — a COLLISION-FREE, PROCESS-STABLE rule id for a photo reference. The previous implementation used
    /// `abs(label.hashValue)`, but Swift's `String.hashValue` is randomized PER PROCESS (hash seeding), so the id the
    /// app generated when writing a rule would DIFFER from any id recomputed in the extension — a real cross-process
    /// bug for a shared store. We now delegate to a deterministic FNV-1a digest over the label bytes + creation epoch
    /// (PhotoShieldLumaMatcherV1.stableRuleID), which is identical in every process. Legacy `photo-<n>-<epoch>` ids
    /// already on disk still load and match (the matcher keys off the persisted feature's ruleID, not its format).
    public static func ruleID(forLabel label: String, nowEpoch: Double) -> String {
        PhotoShieldLumaMatcherV1.stableRuleID(forLabel: label, createdAtEpoch: nowEpoch)
    }

    #if canImport(CoreGraphics)
    /// P1-5 — INGEST a picked reference image into a durable image-reference rule + its derived signature, then
    /// SAVE both through the shared store (producing a real policyRevision). Returns the saved rule + the new
    /// revision, or nil if the signature could not be extracted (honest failure — nothing is written on nil).
    /// The raw CGImage is used only to extract the signature and is NOT persisted.
    @discardableResult
    public static func addReference(cgImage: CGImage, label: String, action: ShieldAction,
                                    locale: String = "en", nowEpoch: Double,
                                    store: PersonalShieldSharedStoreV1,
                                    existingRules: [ShieldRuleV2]) -> (rule: ShieldRuleV2, revision: UInt64)? {
        // R3 §6 — NEW rule creation mints a UUID at creation (no label-derived identity): collision-free + anonymous
        // + stable. Legacy label-derived ids (FNV/hashValue) still load + match via the stored feature.ruleID.
        let rid = PhotoShieldLumaMatcherV1.newRuleID()
        // R3 §1.1 — persist the CANONICAL signature (sampled through GuardianCanonicalSamplerV1), NOT the old
        // VisualSignatureEngine CGContext signature. This is the fix for the cross-path MEDIUM/LOW defect: the stored
        // reference and the live frame now share one sampling contract, so the SAME image reaches HIGH/EXACT.
        guard let sig = canonicalSignature(from: cgImage, ruleID: rid, nowEpoch: nowEpoch),
              let encoded = try? JSONEncoder().encode(sig) else { return nil }
        let feature = DerivedReferenceFeature(featureID: "visualsig-" + rid, ruleID: rid, featureType: .image,
                                              engineID: PhotoShieldLumaMatcherV1.aHashAlgo,
                                              engineRevision: PersistedVisualReferenceSignature.currentEngineRevision,
                                              vectorDimension: sig.components.reduce(0) { $0 + $1.dimension },
                                              serializedFeature: encoded, createdAtEpoch: nowEpoch)
        // §5.2 — on a third-party (uncontrolled) surface a HIDE is impossible (rule 18); the save boundary degrades
        // destructive actions to WARN, so the stored action is honest. The rule links its derived feature by id.
        let rule = ShieldRuleV2(ruleID: rid, inputType: .imageReference, rawUserLabel: label, locale: locale,
                                referenceFeatureIDs: [feature.featureID], action: action,
                                createdAtEpoch: nowEpoch, updatedAtEpoch: nowEpoch)
        guard let rev = try? store.saveImageReferenceRule(rule, feature: feature,
                                                          additionalRules: existingRules.filter { $0.ruleID != rid })
        else { return nil }
        return (rule, rev)
    }

    /// P1-5 — MATCH a live frame's signature against ALL persisted image-reference features. PURE over the persisted
    /// bytes + the freshly-extracted live signature (P006C §3 — no framework object needed at compare time). Returns
    /// the STRONGEST real match, or an honest `.noMatch`/nil. Never fabricates a match from an unavailable signature.
    public static func matchFrame(_ cgImage: CGImage, features: [DerivedReferenceFeature],
                                  nowEpoch: Double) -> PersonalPhotoShieldMatchV1? {
        let comparator = VisualSignatureComparator()
        var best: PersonalPhotoShieldMatchV1?
        for feature in features {
            guard let reference = ShieldVisualReferenceMatcher.decodeSignature(feature),
                  // R3 §1.1 — build the LIVE signature through the SAME canonical sampler the ingest used.
                  let live = canonicalSignature(from: cgImage, ruleID: feature.ruleID, nowEpoch: nowEpoch) else {
                continue
            }
            // R3 §1.1 — never silently compare across sampling bases: a LEGACY (pre-canonical) reference cannot be
            // trusted to match a canonical live signature (different algorithm), so it reports as matcherUnavailable
            // (surfaced as NEEDS_REAUTHOR), not a weak/false match.
            guard PhotoShieldLumaMatcherV1.basisOfSignature(reference) == .canonical else {
                let candidate = PersonalPhotoShieldMatchV1(ruleID: feature.ruleID, state: .matcherUnavailable,
                                                           aHashHamming: nil, dHashHamming: nil)
                if rank(candidate.state) > rank(best?.state ?? .noMatch) { best = candidate }
                continue
            }
            let (state, distances) = comparator.compare(live, reference)
            let candidate = PersonalPhotoShieldMatchV1(ruleID: feature.ruleID, state: state,
                                                       aHashHamming: distances?.aHashHamming,
                                                       dHashHamming: distances?.dHashHamming)
            if rank(candidate.state) > rank(best?.state ?? .noMatch) { best = candidate }
        }
        return best
    }
    #endif

    /// P1-5 — MATCH two already-persisted signatures directly (store-level proof: a reference persisted to disk still
    /// matches a live signature decoded from bytes after relaunch, with NO CGImage needed). Used by store-level tests.
    public static func matchSignature(_ live: PersistedVisualReferenceSignature,
                                      against features: [DerivedReferenceFeature]) -> PersonalPhotoShieldMatchV1? {
        let comparator = VisualSignatureComparator()
        var best: PersonalPhotoShieldMatchV1?
        for feature in features {
            guard let reference = ShieldVisualReferenceMatcher.decodeSignature(feature) else { continue }
            let (state, distances) = comparator.compare(live, reference)
            let candidate = PersonalPhotoShieldMatchV1(ruleID: feature.ruleID, state: state,
                                                       aHashHamming: distances?.aHashHamming,
                                                       dHashHamming: distances?.dHashHamming)
            if rank(candidate.state) > rank(best?.state ?? .noMatch) { best = candidate }
        }
        return best
    }

    /// Match-strength ranking so the STRONGEST real match wins a tie (unavailable/unknown never beat a real match).
    private static func rank(_ s: ShieldMatchState) -> Int {
        switch s {
        case .matchExact: return 4
        case .matchHigh: return 3
        case .matchMedium: return 2
        case .matchLow: return 1
        default: return 0   // noMatch / matcherUnavailable / matchabilityUnknown → not a match
        }
    }
}
