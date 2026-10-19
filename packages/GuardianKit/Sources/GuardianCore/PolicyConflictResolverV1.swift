import Foundation

// MARK: - P009D §8/§9/§10/§12/§15/§18 — precedence law, conflict resolution, admission pipeline,
// sentinels, isolated personal policy cache. NO majority vote; positive/benefit never overrides
// strong protection, age restriction, or unresolved high-risk conflict; fail-closed to UNKNOWN/REVIEW.

public enum PolicyConflictResolverV1 {
    public static let revision = "policy-conflict-resolver-v1"

    public struct InputV1 {
        public let worldModel: ContentWorldModelV1
        public let safety: SafetyPolicyResultV1
        public let child: ChildAgeDecisionV1?
        public let shield: ShieldOutcomeV1?
        public let versions: PolicyVersionRegistryV1
        public init(worldModel: ContentWorldModelV1, safety: SafetyPolicyResultV1,
                    child: ChildAgeDecisionV1?, shield: ShieldOutcomeV1?, versions: PolicyVersionRegistryV1) {
            self.worldModel = worldModel; self.safety = safety; self.child = child
            self.shield = shield; self.versions = versions
        }
    }

    /// §8/§9 — the canonical precedence walk. Each step may only STRENGTHEN (lower rank); benefit
    /// evidence is recorded but can never move the state toward NEUTRAL past a protection rank.
    public static func resolve(_ input: InputV1) -> AdmissionStateCandidateV1 {
        let m = input.worldModel
        var secondary: [PolicyProvenanceV1] = input.safety.reasons
        var unresolved: [String] = []
        var state: AdmissionStateV1 = .neutral
        var dominant = PolicyProvenanceV1(code: .evidenceInsufficient, producer: revision, basis: "default")

        func strengthen(_ s: AdmissionStateV1, _ reason: PolicyProvenanceV1) {
            if s.precedenceRank < state.precedenceRank || state == .neutral {
                if state != .neutral { secondary.append(dominant) }
                state = s; dominant = reason
            } else {
                secondary.append(reason)
            }
        }
        // 1 — STRONG_PROTECTION
        if input.safety.strongProtectionSupported {
            strengthen(.strongProtection, PolicyProvenanceV1(code: .strongRiskEscalation, producer: revision,
                                                             basis: input.safety.strongProtectionBasis.prefix(3).joined(separator: " · ")))
        }
        // 2 — AGE_RESTRICTED
        if let child = input.child, child.outcome == .restricted {
            strengthen(.ageRestricted, child.reasons.first ?? PolicyProvenanceV1(code: .childAgeRestrictedSensitive, producer: revision, basis: "age-restricted"))
            secondary.append(contentsOf: child.reasons.dropFirst())
        }
        // 3 — SHIELD_MATCH (exact canonical only — advisory guesses can never reach here)
        if let shield = input.shield, shield.hardMatch {
            strengthen(.shieldMatch, shield.reasons.first ?? PolicyProvenanceV1(code: .shieldTopicMatch, producer: revision, basis: "shield"))
            secondary.append(contentsOf: shield.reasons.dropFirst())
        } else if let shield = input.shield {
            secondary.append(contentsOf: shield.reasons)       // advisory notes recorded, never blocking
        }
        // 4 — CAUTION family
        if let child = input.child, child.outcome == .caution {
            strengthen(.ageCaution, child.reasons.first ?? PolicyProvenanceV1(code: .childAgeCautionSensitiveNews, producer: revision, basis: "age-caution"))
            secondary.append(contentsOf: child.reasons.dropFirst())
        }
        if input.safety.cautionSupported && state.precedenceRank > AdmissionStateV1.caution.precedenceRank {
            strengthen(.caution, PolicyProvenanceV1(code: .contextQualifiedRisk, producer: revision,
                                                    basis: "evidence-bearing safety dimension present"))
        }
        // unresolved contradictions → CONFLICT class (caution-rank) + recorded
        let unresolvedContradictions = m.contradictionResolutions.filter { $0.outcome == .unresolved }
        if !unresolvedContradictions.isEmpty {
            unresolved.append(contentsOf: unresolvedContradictions.map { "contradiction:\($0.outcome.rawValue)" })
            if state.precedenceRank > AdmissionStateV1.caution.precedenceRank {
                strengthen(.caution, PolicyProvenanceV1(code: .policyConflictUnresolved, producer: revision,
                                                        basis: "unresolved risk-vs-positive contradiction"))
            } else {
                secondary.append(PolicyProvenanceV1(code: .policyConflictUnresolved, producer: revision,
                                                    basis: "recorded under stronger state"))
            }
        }
        // 5 — UNKNOWN/REVIEW (fail-closed §12)
        if state == .neutral {
            if m.identityStatus != "confirmed" {
                state = .unknown
                dominant = PolicyProvenanceV1(code: .identityProvisional, producer: revision, basis: "identity unresolved")
            } else if m.knowledgeState == .unknown || m.knowledgeState == .unavailable {
                state = .unknown
                dominant = PolicyProvenanceV1(code: .oodUnknown, producer: revision, basis: "knowledge=\(m.knowledgeState.rawValue)")
            } else if let child = input.child, child.outcome == .unknownReview {
                state = .review
                dominant = child.reasons.first ?? PolicyProvenanceV1(code: .evidenceInsufficient, producer: revision, basis: "child review")
                secondary.append(contentsOf: child.reasons.dropFirst())
            }
            // P009E F-4: when OOD/identity won the UNKNOWN dominant slot, the child fail-closed reasons
            // (jurisdiction/attestation/teen-law…) are still semantically true — preserve them as secondary.
            if state == .unknown, let child = input.child, child.outcome == .unknownReview {
                secondary.append(contentsOf: child.reasons)
            }
        } else if let child = input.child, child.outcome == .unknownReview {
            secondary.append(contentsOf: child.reasons)        // review need recorded under stronger state
        }
        // 6 — NEUTRAL + benefit bookkeeping: benefit NEVER upgrades past protection ranks (§8 law)
        if !m.benefitEvidence.isEmpty && state.precedenceRank <= AdmissionStateV1.caution.precedenceRank {
            secondary.append(PolicyProvenanceV1(code: .benefitPresentNotOverriding, producer: revision,
                                                basis: m.benefitEvidence.prefix(2).joined(separator: " · ")))
        }
        if state == .neutral {
            dominant = PolicyProvenanceV1(code: .evidenceInsufficient, producer: revision,
                                          basis: "no protection/caution evidence; content-character only")
        }
        return AdmissionStateCandidateV1(state: state, dominantReason: dominant, secondaryReasons: secondary,
                                         unresolvedConflicts: unresolved, confidenceClass: m.knowledgeState,
                                         versions: input.versions, childOutcome: input.child?.outcome,
                                         childSourceClass: input.child?.sourceClass,   // P009E F-6: carried truth
                                         shieldOutcome: input.shield)
    }
}

// MARK: - the full §1 canonical path in one call (world model → admission candidate).

public enum AdmissionPolicyPipelineV1 {
    public static let revision = "admission-policy-pipeline-v1"
    public static func evaluate(worldModel m: ContentWorldModelV1,
                                childProfile: GuardianEnteredChildProfileV1? = nil,
                                parentPreference: ParentPreferencePolicyV1 = ParentPreferencePolicyV1(),
                                shieldConfig: ShieldConfigV2? = nil,
                                nowMs: Double) -> AdmissionStateCandidateV1 {
        let safety = SafetyPolicyEngineV1.evaluate(worldModel: m)
        let child = childProfile.map { ChildAgePolicyEngineV1.evaluate(profile: $0, safety: safety, worldModel: m, parentPreference: parentPreference) }
        let shield = shieldConfig.map { PersonalShieldPolicyV2.evaluate(worldModel: m, config: $0) }
        let versions = PolicyVersionRegistryV1(ageRegistry: JurisdictionAgeBandRegistryV1.version,
                                               jurisdiction: childProfile?.jurisdictionCode ?? "none",
                                               shield: ShieldConfigV2.version,
                                               meshModelVersions: m.meshModelVersions, atMs: nowMs)
        return PolicyConflictResolverV1.resolve(.init(worldModel: m, safety: safety, child: child,
                                                      shield: shield, versions: versions))
    }
}

// MARK: - §15 — safety sentinel registry: curated classes on which FUTURE calibration may never produce
// a false-safe before any user-facing score/glyph release. With the underlying dimensions UNAVAILABLE
// today, the standing law is: a sentinel-class input may never yield NEUTRAL.

public struct SafetySentinelV1: Sendable {
    public let sentinelID: String
    public let dimension: SafetyDimensionV1
    public let law: String
}

public enum SafetySentinelRegistryV1 {
    public static let version = "safety-sentinel-registry-v1"
    public static let sentinels: [SafetySentinelV1] = [
        SafetySentinelV1(sentinelID: "sentinel.explicit", dimension: .explicitSexual, law: "never NEUTRAL; never false-safe post-calibration"),
        SafetySentinelV1(sentinelID: "sentinel.severe-violence", dimension: .violenceGore, law: "never NEUTRAL; never false-safe post-calibration"),
        SafetySentinelV1(sentinelID: "sentinel.self-harm-encouragement", dimension: .selfHarm, law: "never NEUTRAL; never false-safe post-calibration"),
        SafetySentinelV1(sentinelID: "sentinel.dangerous-behavior", dimension: .dangerousBehavior, law: "never NEUTRAL; never false-safe post-calibration"),
        SafetySentinelV1(sentinelID: "sentinel.age-critical-sexual", dimension: .sexualThemes, law: "never NEUTRAL for child profiles"),
        SafetySentinelV1(sentinelID: "sentinel.child-targeted-manipulation", dimension: .manipulationAttention, law: "never NEUTRAL for child profiles")
    ]
    /// Standing gate: every sentinel's dimension is either implemented (evidence can fire) or
    /// UNAVAILABLE — and UNAVAILABLE dimensions fail closed for child profiles (H1/REVIEW laws). A
    /// calibration phase must prove zero false-safe on this registry before any score/glyph ships.
    public static var allDimensionsAccounted: Bool {
        sentinels.allSatisfy { SafetyDimensionTruthV1.status[$0.dimension] != nil }
    }
}

// MARK: - §18 — personal policy decision cache: ISOLATED from ContentDNA/world-model caches, keyed by
// user profile; cross-user leakage structurally impossible; policy changes recompute cheaply from the
// SAME world model (no re-understanding).

public final class PolicyDecisionCacheV1: @unchecked Sendable {
    public static let revision = "policy-decision-cache-v1"
    public struct Key: Hashable {
        public let profileID: String               // personal scope — part of the key, never shared
        public let itemRaw: UInt64
        public let policyFingerprint: String       // engine+taxonomy+age+jurisdiction+shield versions + config hash
    }
    private var store: [Key: AdmissionStateCandidateV1] = [:]
    private var order: [Key] = []
    public let maxEntries: Int
    public private(set) var hits = 0, misses = 0
    private let lock = NSLock()
    public init(maxEntries: Int = 128) { self.maxEntries = maxEntries }

    public static func fingerprint(versions: PolicyVersionRegistryV1, shieldConfig: ShieldConfigV2?,
                                   childAge: Int?, parent: ParentPreferencePolicyV1) -> String {
        var parts = [versions.policyEngine, versions.taxonomy, versions.ageRegistry, versions.jurisdiction,
                     versions.shield, versions.worldModel, versions.safetyDimensionTruth]
        parts.append("age:\(childAge.map(String.init) ?? "none")")
        parts.append("parentCaution:\(parent.extraCautionDimensions.map { $0.rawValue }.sorted().joined(separator: ","))")
        parts.append("parentBlockNews:\(parent.blockSensitiveNews)")
        if let c = shieldConfig {
            parts.append("blocked:" + c.blockedConcepts.sorted().joined(separator: ","))
            parts.append("entities:" + c.blockedEntities.sorted().joined(separator: ","))
            parts.append("sensitive:" + c.sensitiveConcepts.sorted().joined(separator: ","))
            // P009E F-3: advisory inputs are part of the decision payload (advisory notes/codes) —
            // they MUST invalidate the cache like every other shield field.
            parts.append("preferred:" + c.preferredConcepts.sorted().joined(separator: ","))
            parts.append("guesses:" + c.freeformGuesses.sorted().joined(separator: ","))
        }
        var h: UInt64 = 1469598103934665603
        for b in parts.joined(separator: ";").utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return String(format: "%016llx", h)
    }
    public func lookup(profileID: String, item: ContentItemID, policyFingerprint: String) -> AdmissionStateCandidateV1? {
        lock.lock(); defer { lock.unlock() }
        let k = Key(profileID: profileID, itemRaw: item.raw, policyFingerprint: policyFingerprint)
        if let v = store[k] { hits += 1; return v }
        misses += 1; return nil
    }
    public func insert(profileID: String, item: ContentItemID, policyFingerprint: String, decision: AdmissionStateCandidateV1) {
        lock.lock(); defer { lock.unlock() }
        let k = Key(profileID: profileID, itemRaw: item.raw, policyFingerprint: policyFingerprint)
        if store[k] == nil { order.append(k) }
        store[k] = decision
        while order.count > maxEntries { store.removeValue(forKey: order.removeFirst()) }
    }
    public func clearProfile(_ profileID: String) {
        lock.lock(); defer { lock.unlock() }
        for k in store.keys where k.profileID == profileID { store.removeValue(forKey: k) }
        order.removeAll { $0.profileID == profileID }
    }
    public var count: Int { lock.lock(); defer { lock.unlock() }; return store.count }
}
