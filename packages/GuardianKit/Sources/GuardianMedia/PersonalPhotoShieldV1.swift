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
    /// A stable rule id for a photo reference (so re-adding the same image replaces its prior signature).
    public static func ruleID(forLabel label: String, nowEpoch: Double) -> String {
        "photo-\(abs(label.hashValue))-\(Int(nowEpoch))"
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
        let rid = ruleID(forLabel: label, nowEpoch: nowEpoch)
        let ingestor = ShieldImageReferenceIngestor(engine: VisualSignatureEngine())
        guard let ingested = ingestor.ingest(cgImage: cgImage, ruleID: rid, nowEpoch: nowEpoch) else { return nil }
        // §5.2 — on a third-party (uncontrolled) surface a HIDE is impossible (rule 18); the save boundary degrades
        // destructive actions to WARN, so the stored action is honest. The rule links its derived feature by id.
        let rule = ShieldRuleV2(ruleID: rid, inputType: .imageReference, rawUserLabel: label, locale: locale,
                                referenceFeatureIDs: [ingested.feature.featureID], action: action,
                                createdAtEpoch: nowEpoch, updatedAtEpoch: nowEpoch)
        guard let rev = try? store.saveImageReferenceRule(rule, feature: ingested.feature,
                                                          additionalRules: existingRules.filter { $0.ruleID != rid })
        else { return nil }
        return (rule, rev)
    }

    /// P1-5 — MATCH a live frame's signature against ALL persisted image-reference features. PURE over the persisted
    /// bytes + the freshly-extracted live signature (P006C §3 — no framework object needed at compare time). Returns
    /// the STRONGEST real match, or an honest `.noMatch`/nil. Never fabricates a match from an unavailable signature.
    public static func matchFrame(_ cgImage: CGImage, features: [DerivedReferenceFeature],
                                  nowEpoch: Double) -> PersonalPhotoShieldMatchV1? {
        let engine = VisualSignatureEngine()
        let comparator = VisualSignatureComparator()
        var best: PersonalPhotoShieldMatchV1?
        for feature in features {
            guard let reference = ShieldVisualReferenceMatcher.decodeSignature(feature),
                  let live = engine.signature(from: cgImage, ruleID: feature.ruleID, nowEpoch: nowEpoch) else {
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
