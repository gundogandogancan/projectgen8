import Foundation

// MARK: - P009E §2/§3/§10/§11/§14/§17/§19/§24 — the internal Personal Suitability score.
// SEMANTICS: Personal Suitability / Admission Alignment ONLY — not goodness/morality/truth/safety-
// probability/confidence/coverage. Internal 0–100; nil is valid; UNKNOWN is valid; production display OFF.

public struct ScoreCandidateV1: Sendable {
    public let score: Double?                      // nil = abstained (success under insufficient evidence)
    public let scoreConfidence: String             // categorical: none/low/medium/high (≠ score)
    public let evidenceCoverage: Double            // 0…1 trusted modality coverage (≠ score)
    public let calibrationStatus: String           // ENGINEERING_CALIBRATION_ONLY | UNCALIBRATED_SLICE
    public let oodStatus: String
    public let policyState: AdmissionStateV1
    public let reasonCodes: [PolicyReasonCodeV1]
    public let abstentionReason: String?
    public let interpretation: String              // PROTECTED/CAUTION/UNKNOWN/ALIGNED-CANDIDATE — never positive under veto
    public let profileVersion: String
    public let modelVersion: String
    public let calibrationVersion: String
    public let explanation: ScoreExplanationV1
}

public struct ScoreExplanationV1: Sendable {
    public let topDimensions: [String]             // "risk→0.82(cal tr)" structured strings — no free prose
    public let policyVetoes: [String]
    public let uncertaintyNotes: [String]
    public let coverageNote: String
    public let oodNote: String
    public let versionProvenance: [String]
}

/// §14 — selective prediction: abstain (nil score) under any insufficiency condition.
public enum SelectivePredictionGateV1 {
    public static let version = "selective-prediction-gate-v1"
    public static func abstentionReason(worldModel m: ContentWorldModelV1, decision: AdmissionStateCandidateV1,
                                        registry: CalibrationRegistryV2, locale: String) -> String? {
        if m.identityStatus != "confirmed" { return "identity-unstable" }
        if m.knowledgeState == .unknown || m.knowledgeState == .unavailable { return "knowledge-\(m.knowledgeState.rawValue)" }
        if m.uncertainty.overall >= 0.8 { return "low-confidence" }
        if m.oodFlags > 0 && m.uncertainty.ood >= 0.5 { return "ood" }
        if !["tr", "en"].contains(locale) { return "language-slice-unsupported" }
        if !registry.isEngineeringCalibrated(name: "risk", slice: locale) { return "calibrator-missing-\(locale)" }
        if decision.state == .unknown || decision.state == .review { return "policy-\(decision.state.rawValue)" }
        if !decision.unresolvedConflicts.isEmpty { return "unresolved-conflict" }
        let trusted = m.modalityCoverage.values.filter { $0 > 0 }.count
        if trusted < 1 { return "low-coverage" }
        return nil
    }
}

/// §10 — learned, constrained MONOTONIC fusion (sign-constrained linear on calibrated inputs → rubric
/// 0–4 → ×25). No hand-picked truth weights: fitted on TRAIN_TUNE by deterministic projected gradient;
/// signs are semantic constraints (risk/manip/shield/childRestrict ≤ 0; benefit ≥ 0).
public struct SuitabilityFusionModelV1: Sendable {
    public static let version = "suitability-fusion-v1"
    public let wRisk: Double, wBenefit: Double, wManip: Double, wShield: Double, wChild: Double, bias: Double
    public let fitted: Bool
    public let trainMAE: Double
    public func predictRubric(risk: Double, benefit: Double, manip: Double, shieldHard: Bool, childRestrictive: Bool) -> Double {
        let y = bias + wRisk * risk + wBenefit * benefit + wManip * manip
              + wShield * (shieldHard ? 1 : 0) + wChild * (childRestrictive ? 1 : 0)
        return min(4, max(0, y))
    }
    public static func fit(features: [[Double]], targets: [Double]) -> SuitabilityFusionModelV1 {
        // features: [risk, benefit, manip, shield01, child01]; signs: [-,+,-,-,-]
        guard features.count >= 10, features.count == targets.count else {
            return SuitabilityFusionModelV1(wRisk: 0, wBenefit: 0, wManip: 0, wShield: 0, wChild: 0,
                                            bias: 2, fitted: false, trainMAE: .nan)
        }
        var w = [-1.0, 1.0, -0.5, -1.0, -1.0], b = 2.0
        let lr = 0.05
        for _ in 0..<400 {
            var gw = [0.0, 0.0, 0.0, 0.0, 0.0], gb = 0.0
            for (x, t) in zip(features, targets) {
                var y = b; for i in 0..<5 { y += w[i] * x[i] }
                y = min(4, max(0, y))
                let e = y - t
                for i in 0..<5 { gw[i] += e * x[i] }
                gb += e
            }
            let n = Double(features.count)
            for i in 0..<5 { w[i] -= lr * gw[i] / n }
            b -= lr * gb / n
            // projected sign constraints (monotonic semantics)
            w[0] = min(0, w[0]); w[1] = max(0, w[1]); w[2] = min(0, w[2]); w[3] = min(0, w[3]); w[4] = min(0, w[4])
        }
        var absErr = 0.0
        for (x, t) in zip(features, targets) {
            var y = b; for i in 0..<5 { y += w[i] * x[i] }
            absErr += abs(min(4, max(0, y)) - t)
        }
        return SuitabilityFusionModelV1(wRisk: w[0], wBenefit: w[1], wManip: w[2], wShield: w[3], wChild: w[4],
                                        bias: b, fitted: true, trainMAE: absErr / Double(features.count))
    }
}

public enum PersonalSuitabilityScoreV2 {
    public static let version = "personal-suitability-score-v2"

    public struct EngineV1 {
        public let registry: CalibrationRegistryV2
        public let fusion: SuitabilityFusionModelV1
        public init(registry: CalibrationRegistryV2, fusion: SuitabilityFusionModelV1) {
            self.registry = registry; self.fusion = fusion
        }
        /// dimension strengths from the world model (same derivations used at fit time — no leakage of labels)
        public static func features(worldModel m: ContentWorldModelV1, decision: AdmissionStateCandidateV1) -> (risk: Double, benefit: Double, manip: Double) {
            let risk = m.maxRiskSeen
            let benefit = min(1, Double(m.benefitEvidence.count) * 0.4)
            let manip = min(1, Double(m.manipulationEvidence.count) * 0.4)
            _ = decision
            return (risk, benefit, manip)
        }
        public func evaluate(worldModel m: ContentWorldModelV1, decision: AdmissionStateCandidateV1,
                             profile: ProfileFixtureV1, locale: String) -> ScoreCandidateV1 {
            let coverage = m.modalityCoverage.isEmpty ? 0
                : Double(m.modalityCoverage.values.filter { $0 > 0 }.count) / Double(ExpertDomainV2.allCases.count)
            let versions = ["wm:\(ContentWorldModelV1.modelVersion)", "fusion:\(SuitabilityFusionModelV1.version)",
                            "cal:\(CalibrationRegistryV2.version)", "profile:\(profile.profileID)"]
            func explain(_ top: [String], vetoes: [String], note: String) -> ScoreExplanationV1 {
                ScoreExplanationV1(topDimensions: top, policyVetoes: vetoes,
                                   uncertaintyNotes: ["overall=\(String(format: "%.2f", m.uncertainty.overall))"],
                                   coverageNote: "coverage=\(String(format: "%.2f", coverage))",
                                   oodNote: "oodFlags=\(m.oodFlags)", versionProvenance: versions)
            }
            // §14 selective abstention FIRST
            if let reason = SelectivePredictionGateV1.abstentionReason(worldModel: m, decision: decision,
                                                                       registry: registry, locale: locale) {
                return ScoreCandidateV1(score: nil, scoreConfidence: "none", evidenceCoverage: coverage,
                                        calibrationStatus: registry.isEngineeringCalibrated(name: "risk", slice: locale)
                                            ? registry.calibrationClass.rawValue : "UNCALIBRATED_SLICE",
                                        oodStatus: m.oodFlags > 0 ? "OOD" : "in-distribution",
                                        policyState: decision.state,
                                        reasonCodes: ([decision.dominantReason] + decision.secondaryReasons).map { $0.code },
                                        abstentionReason: reason, interpretation: "UNKNOWN",
                                        profileVersion: profile.profileID, modelVersion: ContentWorldModelV1.modelVersion,
                                        calibrationVersion: CalibrationRegistryV2.version,
                                        explanation: explain([], vetoes: [], note: reason))
            }
            let f = Self.features(worldModel: m, decision: decision)
            let riskCal = registry.calibrator(name: "risk", slice: locale)?.probability(f.risk) ?? f.risk
            let benefitCal = registry.calibrator(name: "benefit", slice: locale)?.probability(f.benefit) ?? f.benefit
            let manipCal = registry.calibrator(name: "manip", slice: locale)?.probability(f.manip) ?? f.manip
            let shieldHard = decision.shieldOutcome?.hardMatch ?? false
            let childRestrictive = decision.childOutcome == .restricted || decision.childOutcome == .caution
            let rubric = fusion.predictRubric(risk: riskCal, benefit: benefitCal, manip: manipCal,
                                              shieldHard: shieldHard, childRestrictive: childRestrictive)
            var score = rubric * 25.0
            var interpretation = score >= 62.5 ? "ALIGNED-CANDIDATE" : (score >= 37.5 ? "MIXED" : "CAUTION")
            var vetoes: [String] = []
            // §4 — POLICY VETO LAW: categorical state dominates; numeric can never be positive under veto
            if decision.state == .strongProtection || decision.state == .ageRestricted {
                score = min(score, 10)
                interpretation = "PROTECTED"
                vetoes.append("veto:\(decision.state.rawValue) caps score ≤10; interpretation PROTECTED")
            } else if decision.state == .shieldMatch {
                score = min(score, 25)
                interpretation = "SHIELD-PROTECTED"
                vetoes.append("veto:SHIELD_MATCH caps score ≤25")
            }
            let confidence: String = m.uncertainty.overall < 0.3 && coverage >= 0.3 ? "high"
                : (m.uncertainty.overall < 0.5 ? "medium" : "low")
            let top = [String(format: "risk→%.2f(cal %@)", riskCal, locale),
                       String(format: "benefit→%.2f", benefitCal),
                       String(format: "manip→%.2f", manipCal)]
            return ScoreCandidateV1(score: score, scoreConfidence: confidence, evidenceCoverage: coverage,
                                    calibrationStatus: registry.calibrationClass.rawValue,
                                    oodStatus: "in-distribution", policyState: decision.state,
                                    reasonCodes: ([decision.dominantReason] + decision.secondaryReasons).map { $0.code },
                                    abstentionReason: nil, interpretation: interpretation,
                                    profileVersion: profile.profileID, modelVersion: ContentWorldModelV1.modelVersion,
                                    calibrationVersion: CalibrationRegistryV2.version,
                                    explanation: explain(top, vetoes: vetoes, note: "ok"))
        }
    }
}

// MARK: - §19 score cache (full version binding; profile-keyed; cross-user impossible).

public final class ScoreCacheV1: @unchecked Sendable {
    public struct Key: Hashable { let profileID: String; let itemRaw: UInt64; let versionsFingerprint: String }
    private var store: [Key: ScoreCandidateV1] = [:]
    private let lock = NSLock(); public let maxEntries = 128
    private var order: [Key] = []
    public init() {}
    public static func fingerprint(calibrationVersion: String, fusionVersion: String, profileID: String,
                                   shieldVersion: String, ageRegistry: String, wmVersion: String) -> String {
        var h: UInt64 = 1469598103934665603
        for b in [calibrationVersion, fusionVersion, profileID, shieldVersion, ageRegistry, wmVersion]
            .joined(separator: ";").utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return String(format: "%016llx", h)
    }
    public func lookup(profileID: String, item: ContentItemID, fp: String) -> ScoreCandidateV1? {
        lock.lock(); defer { lock.unlock() }
        return store[Key(profileID: profileID, itemRaw: item.raw, versionsFingerprint: fp)]
    }
    public func insert(profileID: String, item: ContentItemID, fp: String, candidate: ScoreCandidateV1) {
        lock.lock(); defer { lock.unlock() }
        let k = Key(profileID: profileID, itemRaw: item.raw, versionsFingerprint: fp)
        if store[k] == nil { order.append(k) }
        store[k] = candidate
        while order.count > maxEntries { store.removeValue(forKey: order.removeFirst()) }
    }
}

// MARK: - §24 — ProductionScoreReleaseGateV1: CLOSED unless EVERY condition is truly met.

public enum ProductionScoreReleaseGateV1 {
    public static let version = "production-score-release-gate-v1"
    public struct ConditionV1: Sendable { public let name: String; public let met: Bool; public let truth: String }
    public static func evaluate() -> (open: Bool, conditions: [ConditionV1]) {
        let conditions = [
            ConditionV1(name: "rights-clear calibration corpus", met: false,
                        truth: "corpus is SYNTHETIC_DERIVED/STRUCTURAL_ONLY — supportsRealWorldClaims=false"),
            ConditionV1(name: "held-out metrics pass on real data", met: false, truth: "no real-data held-out exists"),
            ConditionV1(name: "TR/EN required slices (real)", met: false, truth: "engineering slices only"),
            ConditionV1(name: "age slices pass", met: false, truth: "engineering-only; teen fail-closed by policy"),
            ConditionV1(name: "sentinel false-safe = 0", met: true, truth: "sentinel split: 0 false-safe (engineering set)"),
            ConditionV1(name: "H1 satisfied or fail-closed blocks score", met: true,
                        truth: "H1 UNAVAILABLE + under-13/teen fail-closed laws block positive states"),
            ConditionV1(name: "no unresolved critical audit finding", met: true, truth: "F-5 closed at entry"),
            ConditionV1(name: "physical device/in-app proof", met: false, truth: "user-gated; not claimed"),
            ConditionV1(name: "privacy/resource gates", met: true, truth: "lab-verified; device cost NOT_MEASURED"),
            ConditionV1(name: "independent P009E audit PASS", met: false, truth: "audit not yet run")
        ]
        return (conditions.allSatisfy { $0.met }, conditions)   // structurally CLOSED today
    }
}
