//
//  RecognitionSignatureV1.swift — R11-B P0(1): the VERSIONED MULTI-KEYFRAME RECOGNITION SIGNATURE and the PURE
//  VERIFICATION LADDER for "have I genuinely analyzed THIS content before?".
//
//  WHY THIS EXISTS (R11 mandate §2 / §9): GEN8 must recognize the SAME content when it appears again — as EARLY as
//  honestly possible — WITHOUT a second identity brain and WITHOUT ever claiming a false match. A false video match is
//  MORE dangerous than no match (mandate §2.1): a wrong match would attach another video's cached evidence to the
//  content the user is actually watching. So recognition is PRECISION-FIRST and structurally refuses the cheap
//  collisions: a single perceptual-hash agreement, a black/near-uniform frame, or a shared intro is NEVER a match.
//
//  NO SECOND BRAIN (mandate §2): this reuses the EXISTING canonical signature components ONLY —
//    • `VisualSignatureComponent` (aHash64 / dHash64 / normVector256) from GuardianCore (frozen), built from the
//      canonical AREA-AVERAGE sampler `GuardianCanonicalSamplerV1` (same bits the photo-shield + Tier-1 paths use).
//    • `VisualSignatureComparator` (frozen) for the per-keyframe Hamming/L2 distance tiers.
//    • OCR trigram Jaccard (`Tier1TextSimilarityV1`) as an OPTIONAL per-keyframe text corroboration.
//  A `RecognitionSignatureV1` is just an ORDERED, explicitly-versioned list of per-keyframe signatures + a RELATIVE
//  TEMPORAL LAYOUT + the coverage interval the keyframes were drawn from. It is a MULTI-KEYFRAME WRAPPER, not a new
//  perceptual engine.
//
//  COLLISION MODEL (mandate §2.1, documented): a 64-bit perceptual hash is cheap to collide on near-uniform frames
//  (black screens, fades, common app chrome, shared intros). Therefore a HIGH-confidence recognition requires:
//    (a) at least `minAgreeingKeyframes` keyframes agreeing at the HIGH perceptual tier,
//    (b) the relative temporal layout of the agreeing keyframes being CONSISTENT (same ordering + comparable spacing),
//    (c) at least one agreeing keyframe being NON-near-uniform (so black/intro frames alone can never carry a match).
//  Anything weaker is PARTIAL / AMBIGUOUS / NO_MATCH — never a match that reuses evidence.
//
//  PURE + headless + versioned. Lives in GuardianMedia (GuardianCore frozen). Codable so a built signature can be
//  persisted in the evidence memory and compared across sessions on-device, with no framework object at compare time.
//
import Foundation
import GuardianCore

// MARK: - A single keyframe's recognition descriptor (derived bytes only — NO raw frame)

/// One temporal keyframe's recognition descriptor: the canonical visual signature (aHash/dHash/normVector) plus a
/// NORMALIZED temporal offset within the observed coverage window, plus optional derived OCR trigram hashes and a
/// near-uniform flag. Everything here is a DERIVED feature; no raw frame / no raw text is retained.
public struct RecognitionKeyframeV1: Sendable, Equatable, Codable {
    /// The canonical per-keyframe signature (frozen component type; already Codable + checksummed).
    public let signature: PersistedVisualReferenceSignature
    /// 0...1 position of this keyframe within the signature's coverage window (relative temporal layout). Two
    /// signatures of the same content must agree in ORDER and comparable spacing, not just in bag-of-frames.
    public let normalizedOffset: Double
    /// Salted-none FNV-1a character-trigram hashes of this keyframe's on-screen OCR (optional corroboration). Empty
    /// when there was no text. These are DERIVED hashes; the raw OCR text is NEVER stored.
    public let ocrTrigramHashes: [UInt64]
    /// True when the sampled grid is near-uniform (black frame / flat fade / solid chrome) — a frame whose perceptual
    /// hash is CHEAP to collide on. A near-uniform keyframe can CORROBORATE but can NEVER by itself carry a match.
    public let nearUniform: Bool

    public init(signature: PersistedVisualReferenceSignature, normalizedOffset: Double,
                ocrTrigramHashes: [UInt64] = [], nearUniform: Bool = false) {
        self.signature = signature
        self.normalizedOffset = min(1, max(0, normalizedOffset))
        self.ocrTrigramHashes = ocrTrigramHashes
        self.nearUniform = nearUniform
    }

    /// R11 §2.1 — a keyframe grid is NEAR-UNIFORM when its luma spread is tiny (variance below a small bound). This is
    /// the anti-black-frame / anti-flat-intro guard, computed from the SAME canonical grid the signature was built
    /// from. Pure (operates on the derived grid bytes). `maxStdDev` is in 0...255 luma units.
    public static func isNearUniform(grid: [UInt8], maxStdDev: Double = 8.0) -> Bool {
        guard grid.count >= 2 else { return true }
        var sum = 0.0
        for p in grid { sum += Double(p) }
        let mean = sum / Double(grid.count)
        var varSum = 0.0
        for p in grid { let d = Double(p) - mean; varSum += d * d }
        let std = (varSum / Double(grid.count)).squareRoot()
        return std <= maxStdDev
    }
}

// MARK: - The versioned multi-keyframe signature

/// R11 §2 — the ONE recognition signature: a versioned, ordered list of keyframe descriptors + the coverage interval
/// they were drawn from. NOT a new identity engine — a wrapper over the canonical per-frame signature. The coverage
/// interval is a COVERAGE-HONESTY field: it records exactly which part of the content these keyframes represent (4s
/// analyzed → coverage 4s), so a recognized-later reuse can never claim more than was actually seen.
public struct RecognitionSignatureV1: Sendable, Equatable, Codable {
    /// Explicit schema version. A signature built under an incompatible schema/basis is NEVER compared (no reuse).
    public static let schemaVersion = 1
    /// The sampling-basis tag the keyframe signatures were built under (carried for the version-mismatch firewall).
    public static let basisTag = GuardianCanonicalSamplerV1.basisTag

    public let schema: Int
    public let basis: String
    /// Ordered keyframes (ascending normalizedOffset by contract; the builder sorts).
    public let keyframes: [RecognitionKeyframeV1]
    /// The observed-coverage interval (seconds) these keyframes represent, within the content's own timeline. This is
    /// the HONEST coverage: `[0, 4]` means "the first 4 seconds were analyzed", nothing more.
    public let coverageStartSeconds: Double
    public let coverageEndSeconds: Double

    public init(keyframes: [RecognitionKeyframeV1], coverageStartSeconds: Double, coverageEndSeconds: Double,
                schema: Int = RecognitionSignatureV1.schemaVersion, basis: String = RecognitionSignatureV1.basisTag) {
        self.keyframes = keyframes.sorted { $0.normalizedOffset < $1.normalizedOffset }
        self.coverageStartSeconds = min(coverageStartSeconds, coverageEndSeconds)
        self.coverageEndSeconds = max(coverageStartSeconds, coverageEndSeconds)
        self.schema = schema
        self.basis = basis
    }

    public var coverageDurationSeconds: Double { max(0, coverageEndSeconds - coverageStartSeconds) }
    public var keyframeCount: Int { keyframes.count }

    /// True when this signature is structurally comparable: current schema, current basis, at least one keyframe, and
    /// every keyframe component intact + compatible. An incompatible/corrupt signature is NEVER compared (→ UNAVAILABLE
    /// at the verifier) so a version drift can never produce a silent wrong reuse (mandate §9).
    public var isComparable: Bool {
        guard schema == RecognitionSignatureV1.schemaVersion, basis == RecognitionSignatureV1.basisTag,
              !keyframes.isEmpty else { return false }
        return keyframes.allSatisfy { $0.signature.isCompatible() }
    }
}

// MARK: - The recognition levels (mandate §2.1)

/// R11 §2.1 — the recognition levels. These do NOT carry automatic decision authority: ONLY
/// `highConfidenceMultiframeMatch` may contribute cached evidence, and even then only through current-policy
/// re-adjudication (never a republished old decision). `verifiedPlatformId` is reserved for the YouTube connector
/// (R11-C) — a lawful verified ID, never a visual match.
public enum RecognitionLevelV1: String, Sendable, Equatable, Codable, CaseIterable {
    case verifiedPlatformId            = "VERIFIED_PLATFORM_ID"
    case highConfidenceMultiframeMatch = "HIGH_CONFIDENCE_MULTIFRAME_MATCH"
    case partialVisualSimilarity       = "PARTIAL_VISUAL_SIMILARITY"
    case ambiguousCandidates           = "AMBIGUOUS_CANDIDATES"
    case noMatch                       = "NO_MATCH"
    case unavailable                   = "UNAVAILABLE"

    /// The only level permitted to pass cached evidence into the CURRENT world-model bridge.
    public var mayReuseCachedEvidence: Bool { self == .highConfidenceMultiframeMatch || self == .verifiedPlatformId }
}

/// R11 §2.1/§6 — the derived result of a verification pass against ONE candidate (proof-log safe scalars only).
public struct RecognitionMatchResultV1: Sendable, Equatable {
    public let level: RecognitionLevelV1
    public let agreeingKeyframes: Int
    public let comparedKeyframes: Int
    public let nonUniformAgreements: Int
    public let temporalConsistent: Bool
    /// A declared, documented confidence placeholder derived from the structural evidence (NOT a measured calibration;
    /// NOT a 0-100 suitability — P009E stays closed). Low for partial/ambiguous, high for a full multiframe match.
    public let declaredConfidence: Double
    public let reason: String
    public init(level: RecognitionLevelV1, agreeingKeyframes: Int, comparedKeyframes: Int,
                nonUniformAgreements: Int, temporalConsistent: Bool, declaredConfidence: Double, reason: String) {
        self.level = level; self.agreeingKeyframes = agreeingKeyframes; self.comparedKeyframes = comparedKeyframes
        self.nonUniformAgreements = nonUniformAgreements; self.temporalConsistent = temporalConsistent
        self.declaredConfidence = declaredConfidence; self.reason = reason
    }
}

// MARK: - The pure verification ladder

/// R11 §2.1 — the PURE recognition verifier. Given a PROBE signature (built from what is on screen now) and a stored
/// CANDIDATE signature (from the evidence memory), decide the recognition level. PRECISION-FIRST by construction:
/// the HIGH tier is gated on multiple non-uniform keyframe agreements AND temporal-layout consistency. Pure + headless
/// + exhaustively testable against the §9 adversarial corpus (same video / crop / subtitle / common intro / black
/// frame / same person different video / trimmed video / version mismatch).
public enum RecognitionVerifierV1 {

    public struct PolicyV1: Sendable, Equatable {
        /// Minimum NON-UNIFORM keyframes that must agree at the HIGH perceptual tier for a multiframe match.
        public let minAgreeingKeyframes: Int
        /// aHash Hamming ceiling for a per-keyframe HIGH agreement (matches the frozen comparator's matchHigh band).
        public let aHashHighMax: Int
        public let dHashHighMax: Int
        /// Max difference in normalized offset for two keyframes to be considered the "same temporal slot".
        public let temporalSlotTolerance: Double
        /// Optional: minimum OCR trigram Jaccard for a text corroboration to count (0 disables the requirement).
        public let ocrCorroborationMin: Double
        public init(minAgreeingKeyframes: Int = 3, aHashHighMax: Int = 6, dHashHighMax: Int = 8,
                    temporalSlotTolerance: Double = 0.12, ocrCorroborationMin: Double = 0.0) {
            self.minAgreeingKeyframes = max(2, minAgreeingKeyframes)
            self.aHashHighMax = max(0, aHashHighMax); self.dHashHighMax = max(0, dHashHighMax)
            self.temporalSlotTolerance = max(0, temporalSlotTolerance)
            self.ocrCorroborationMin = min(1, max(0, ocrCorroborationMin))
        }
        public static let v1 = PolicyV1()
    }

    private static let comparator = VisualSignatureComparator()

    /// Verify ONE probe against ONE candidate. The caller runs this across the candidate set; the aggregator
    /// (`verifyAgainstCandidates`) decides AMBIGUOUS when two candidates both reach the high bar.
    public static func verify(probe: RecognitionSignatureV1, candidate: RecognitionSignatureV1,
                              policy: PolicyV1 = .v1) -> RecognitionMatchResultV1 {
        // VERSION / COMPATIBILITY FIREWALL — incompatible or corrupt → UNAVAILABLE (never a silent wrong reuse).
        guard probe.isComparable, candidate.isComparable else {
            return RecognitionMatchResultV1(level: .unavailable, agreeingKeyframes: 0, comparedKeyframes: 0,
                                            nonUniformAgreements: 0, temporalConsistent: false,
                                            declaredConfidence: 0, reason: "signature-incompatible-or-corrupt")
        }

        // Greedily pair each probe keyframe to the nearest-in-time candidate keyframe within the temporal slot
        // tolerance, then test a HIGH perceptual agreement. A pairing is only counted once (no double-use).
        var usedCandidate = Set<Int>()
        var agreements = 0
        var nonUniformAgreements = 0
        var temporalOrderPairs: [(Double, Double)] = []
        var compared = 0

        for pk in probe.keyframes {
            // nearest unused candidate keyframe in the same temporal slot
            var bestIdx: Int? = nil
            var bestDelta = Double.greatestFiniteMagnitude
            for (ci, ck) in candidate.keyframes.enumerated() where !usedCandidate.contains(ci) {
                let delta = abs(pk.normalizedOffset - ck.normalizedOffset)
                if delta <= policy.temporalSlotTolerance, delta < bestDelta { bestDelta = delta; bestIdx = ci }
            }
            guard let ci = bestIdx else { continue }
            let ck = candidate.keyframes[ci]
            compared += 1
            let (state, distances) = comparator.compare(pk.signature, ck.signature)
            // HIGH perceptual agreement = the frozen comparator's HIGH band (or tighter).
            let highVisual: Bool
            if let d = distances { highVisual = (d.aHashHamming <= policy.aHashHighMax && d.dHashHamming <= policy.dHashHighMax) }
            else { highVisual = (state == .matchHigh || state == .matchExact) }
            // OCR corroboration (optional): when both sides carry trigrams and a minimum is required, enforce it.
            var ocrOK = true
            if policy.ocrCorroborationMin > 0, !pk.ocrTrigramHashes.isEmpty, !ck.ocrTrigramHashes.isEmpty {
                let j = Tier1TextSimilarityV1.jaccard(Set(pk.ocrTrigramHashes), Set(ck.ocrTrigramHashes))
                ocrOK = j >= policy.ocrCorroborationMin
            }
            if highVisual && ocrOK {
                usedCandidate.insert(ci)
                agreements += 1
                temporalOrderPairs.append((pk.normalizedOffset, ck.normalizedOffset))
                // A near-uniform keyframe (black / flat intro) CORROBORATES but can NEVER by itself carry a match.
                if !pk.nearUniform && !ck.nearUniform { nonUniformAgreements += 1 }
            }
        }

        // Temporal-layout consistency: the agreeing pairs must be MONOTONIC in both probe and candidate order (same
        // relative ordering — a shuffled set of agreements is NOT the same video, it is a shared-asset coincidence).
        let temporalConsistent = isMonotonic(temporalOrderPairs)

        // LADDER.
        if nonUniformAgreements >= policy.minAgreeingKeyframes && temporalConsistent {
            // HIGH: enough distinct non-uniform keyframes agree AND their temporal layout lines up.
            let conf = min(0.95, 0.6 + 0.1 * Double(nonUniformAgreements))
            return RecognitionMatchResultV1(level: .highConfidenceMultiframeMatch, agreeingKeyframes: agreements,
                                            comparedKeyframes: compared, nonUniformAgreements: nonUniformAgreements,
                                            temporalConsistent: true, declaredConfidence: conf,
                                            reason: "multiframe-match(nonUniform=\(nonUniformAgreements),temporal-consistent)")
        }
        if agreements >= 1 {
            // Some agreement but below the multiframe/temporal bar → PARTIAL (surfaced, never reused).
            let why = !temporalConsistent ? "temporal-inconsistent"
                : (nonUniformAgreements == 0 ? "only-near-uniform-agreements"
                   : "insufficient-nonuniform-agreements(\(nonUniformAgreements)<\(policy.minAgreeingKeyframes))")
            return RecognitionMatchResultV1(level: .partialVisualSimilarity, agreeingKeyframes: agreements,
                                            comparedKeyframes: compared, nonUniformAgreements: nonUniformAgreements,
                                            temporalConsistent: temporalConsistent,
                                            declaredConfidence: 0.3, reason: "partial(\(why))")
        }
        return RecognitionMatchResultV1(level: .noMatch, agreeingKeyframes: 0, comparedKeyframes: compared,
                                        nonUniformAgreements: 0, temporalConsistent: false,
                                        declaredConfidence: 0, reason: "no-agreement")
    }

    /// R11 §2.1 — aggregate a probe against MANY candidates. Returns the winning candidate index + result, or an
    /// AMBIGUOUS result when two or more candidates independently reach the HIGH bar (no clear identity → UNKNOWN,
    /// no reuse). An empty candidate set → NO_MATCH.
    public static func verifyAgainstCandidates(probe: RecognitionSignatureV1,
                                               candidates: [RecognitionSignatureV1],
                                               policy: PolicyV1 = .v1) -> (index: Int?, result: RecognitionMatchResultV1) {
        guard !candidates.isEmpty else {
            return (nil, RecognitionMatchResultV1(level: .noMatch, agreeingKeyframes: 0, comparedKeyframes: 0,
                                                  nonUniformAgreements: 0, temporalConsistent: false,
                                                  declaredConfidence: 0, reason: "no-candidates"))
        }
        var highHits: [(Int, RecognitionMatchResultV1)] = []
        var bestPartial: (Int, RecognitionMatchResultV1)? = nil
        for (i, c) in candidates.enumerated() {
            let r = verify(probe: probe, candidate: c, policy: policy)
            if r.level == .highConfidenceMultiframeMatch { highHits.append((i, r)) }
            else if r.level == .partialVisualSimilarity {
                if bestPartial == nil || r.agreeingKeyframes > bestPartial!.1.agreeingKeyframes { bestPartial = (i, r) }
            }
        }
        if highHits.count == 1 { return (highHits[0].0, highHits[0].1) }
        if highHits.count > 1 {
            // Two different stored items both reach HIGH against this probe → genuinely AMBIGUOUS; never pick one.
            return (nil, RecognitionMatchResultV1(level: .ambiguousCandidates, agreeingKeyframes: highHits[0].1.agreeingKeyframes,
                                                  comparedKeyframes: highHits[0].1.comparedKeyframes,
                                                  nonUniformAgreements: highHits[0].1.nonUniformAgreements,
                                                  temporalConsistent: highHits[0].1.temporalConsistent,
                                                  declaredConfidence: 0,
                                                  reason: "ambiguous(\(highHits.count)-high-candidates)"))
        }
        if let bp = bestPartial { return (bp.0, bp.1) }
        return (nil, RecognitionMatchResultV1(level: .noMatch, agreeingKeyframes: 0, comparedKeyframes: 0,
                                              nonUniformAgreements: 0, temporalConsistent: false,
                                              declaredConfidence: 0, reason: "no-agreement-any-candidate"))
    }

    /// Both sequences must be non-decreasing in lockstep (same relative ordering of agreeing keyframes).
    private static func isMonotonic(_ pairs: [(Double, Double)]) -> Bool {
        guard pairs.count >= 2 else { return pairs.count == 1 }
        let sorted = pairs.sorted { $0.0 < $1.0 }
        for i in 1..<sorted.count { if sorted[i].1 < sorted[i - 1].1 { return false } }
        return true
    }
}
