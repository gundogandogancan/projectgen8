import Foundation

// MARK: - Score & admission types
// Ref: Build Bible §49–§52, §501, §629; ADR-0007 precedence; PROMPT 001 §6, §7.
// An LLM NEVER emits a final numeric score. Scores here come from an explicit deterministic
// formula over fixture/HEURISTIC_V0 signals (D-0005). Insufficient evidence ⇒ `?` (no number).

public enum ScoreState: String, Sendable {
    case verifiedFast = "VERIFIED_FAST"
    case provisionalFast = "PROVISIONAL_FAST"
    case insufficientEvidence = "INSUFFICIENT_EVIDENCE"
    case conflicting = "CONFLICTING"
}

/// Personal Benefit Score result. `value` is nil whenever evidence is insufficient/conflicting → UI shows `?`.
public struct PBSResult: Sendable, Equatable {
    public let value: Double?          // 0...10, nil = `?`
    public let state: ScoreState
    public let provenance: SignalProvenance
    public let formulaVersion: String
    public init(value: Double?, state: ScoreState, provenance: SignalProvenance, formulaVersion: String) {
        self.value = value
        self.state = state
        self.provenance = provenance
        self.formulaVersion = formulaVersion
    }
    /// User-facing token: a number (1 decimal) only when present, else "?".
    public var display: String { value.map { String(format: "%.1f", $0) } ?? "?" }
}

/// Admission outcome (PROMPT 001 §6). UNKNOWN is truthful — never a stale green/safe state.
public enum AdmissionState: String, Sendable, Codable {
    case approve = "APPROVE"
    case approveWithCaution = "APPROVE_WITH_CAUTION"
    case notRecommended = "NOT_RECOMMENDED"
    case hideIfControlled = "HIDE_IF_CONTROLLED"
    case unknown = "UNKNOWN"
}

public enum AdmissionConfidence: String, Sendable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
    case none = "NONE"
}

/// Which precedence layer (ADR-0007) determined the decision — makes "why" traceable.
public enum DecisionReason: String, Sendable {
    case legalSecurity = "LEGAL_SECURITY"
    case childSafetyFloor = "CHILD_SAFETY_FLOOR"
    case maliciousSafetySignal = "MALICIOUS_SAFETY_SIGNAL"
    case userHardSemanticShield = "USER_HARD_SEMANTIC_SHIELD"
    case personalProtectionPolicy = "PERSONAL_PROTECTION_POLICY"  // incl. Positive Exposure
    case personalAlgorithmThreshold = "PERSONAL_ALGORITHM_THRESHOLD"
    case benefitRanking = "BENEFIT_RANKING"
    case exploration = "EXPLORATION"
    case insufficientEvidence = "INSUFFICIENT_EVIDENCE"
}

public struct AdmissionDecision: Sendable, Equatable {
    public let contentID: ContentID
    public let state: AdmissionState
    public let confidence: AdmissionConfidence
    public let reason: DecisionReason
    public let score: PBSResult
    /// Human-readable, provenance-labelled explanation (why/protection/evidence/matched rule).
    public let explanation: String
    /// Whether identity was strong enough for high-impact actions.
    public let identityState: ContentIdentityState
    public init(contentID: ContentID, state: AdmissionState, confidence: AdmissionConfidence,
                reason: DecisionReason, score: PBSResult, explanation: String,
                identityState: ContentIdentityState) {
        self.contentID = contentID
        self.state = state
        self.confidence = confidence
        self.reason = reason
        self.score = score
        self.explanation = explanation
        self.identityState = identityState
    }

    public static func == (l: AdmissionDecision, r: AdmissionDecision) -> Bool {
        l.contentID == r.contentID && l.state == r.state && l.confidence == r.confidence &&
        l.reason == r.reason && l.score == r.score && l.identityState == r.identityState
    }
}

/// Guardian coverage truth (never claim coverage we don't have).
public enum GuardianCoverageState: String, Sendable {
    case verified = "VERIFIED"
    case analyzing = "ANALYZING"
    case firstFrameOnly = "FIRST_FRAME_ONLY"
    case unknown = "UNKNOWN"
    case limitedOnSurface = "LIMITED_ON_SURFACE"
}

/// What the Pure Bar should render. Color is never the only signal (§603) → `label` always set.
public struct GuardianSurfaceState: Sendable, Equatable {
    public enum Tone: String, Sendable { case aligned, neutral, caution, strongCaution, unknown }
    public let tone: Tone
    public let label: String          // non-color accessible cue (e.g. "Beneficial", "Caution", "Unknown")
    public let scoreDisplay: String   // "7.5" or "?"
    public let coverage: GuardianCoverageState
    public init(tone: Tone, label: String, scoreDisplay: String, coverage: GuardianCoverageState) {
        self.tone = tone
        self.label = label
        self.scoreDisplay = scoreDisplay
        self.coverage = coverage
    }

    /// Map an admission decision to a truthful surface state.
    public static func from(_ d: AdmissionDecision, coverage: GuardianCoverageState) -> GuardianSurfaceState {
        switch d.state {
        case .approve:
            return .init(tone: .aligned, label: "Beneficial", scoreDisplay: d.score.display, coverage: coverage)
        case .approveWithCaution:
            return .init(tone: .caution, label: "Caution", scoreDisplay: d.score.display, coverage: coverage)
        case .notRecommended:
            return .init(tone: .strongCaution, label: "Not recommended", scoreDisplay: d.score.display, coverage: coverage)
        case .hideIfControlled:
            return .init(tone: .strongCaution, label: "Do not watch", scoreDisplay: d.score.display, coverage: coverage)
        case .unknown:
            return .init(tone: .unknown, label: "Unknown", scoreDisplay: "?", coverage: .unknown)
        }
    }
}
