import Foundation

// MARK: - Deterministic GuardianLab fixtures (TEST_FIXTURE) — no network, no real media, no real AI
// Ref: PROMPT 001 §2.D, §10, §13, §31. Used by GuardianLab UI + tests + benchmark scenarios S1–S10.

public enum GuardianLabFixtures {

    /// Assemble a ready-to-use pipeline with injectable clock. Returns all parts for inspection/tests.
    public static func makePipeline(clock: MonotonicClock)
    -> (pipeline: PreExposurePipeline, cache: LocalAdmissionCache, diagnostics: Diagnostics,
        log: InMemoryGuardianLog, events: RecordingEventSink) {
        let cache = LocalAdmissionCache(clock: clock)
        let diagnostics = Diagnostics()
        let log = InMemoryGuardianLog()
        let events = RecordingEventSink()
        let pipeline = PreExposurePipeline(
            cache: cache, clock: clock,
            identityResolver: Self.identity(for:),
            diagnostics: diagnostics, log: log, events: events)
        return (pipeline, cache, diagnostics, log, events)
    }

    /// Fixture identity resolver: known ids resolve strong (I4) with a stable version; unknown → I0.
    public static func identity(for id: ContentID) -> ContentIdentityResult {
        switch id.raw {
        case "vid-1": return .init(contentID: id, state: .i4_verified, versionTag: "v1")
        case let r where r.hasPrefix("sf-"): return .init(contentID: id, state: .i4_verified, versionTag: "sf")
        default: return .init(contentID: id, state: .i0_unknown, versionTag: "unknown")
        }
    }

    public static let defaultProfile = PersonalAlgorithmProfile(minimumPersonalScore: 7.5)

    // MARK: Short-form candidates (scores computed by the explicit deterministic formula)

    /// Beneficial → score ~7.9 ≥ 7.5 → APPROVE, VERIFIED_FAST.
    public static func beneficial(_ id: String = "sf-beneficial", likelihood: Double = 0.9) -> ContentCandidate {
        .init(id: .init(id), source: .lookAhead1, nextExposureLikelihood: likelihood, decisionDeadlineNanos: nil,
              fixture: .init(topics: ["learning", "swift"], goalFit: 0.9, informationDensity: 0.8, manipulationRisk: 0.1))
    }
    /// Low value → score 0.0 < 7.5 → NOT_RECOMMENDED (threshold).
    public static func lowValue(_ id: String = "sf-lowvalue", likelihood: Double = 0.8) -> ContentCandidate {
        .init(id: .init(id), source: .lookAhead2, nextExposureLikelihood: likelihood, decisionDeadlineNanos: nil,
              fixture: .init(topics: ["doomscroll"], goalFit: 0.3, informationDensity: 0.3, manipulationRisk: 0.5))
    }
    /// Insufficient evidence → UNKNOWN / `?`.
    public static func unknown(_ id: String = "sf-unknown", likelihood: Double = 0.7) -> ContentCandidate {
        .init(id: .init(id), source: .lookAhead3, nextExposureLikelihood: likelihood, decisionDeadlineNanos: nil,
              fixture: .init(hasSufficientEvidence: false))
    }
    /// Conflicting signals → CONFLICTING → UNKNOWN.
    public static func conflicting(_ id: String = "sf-conflict", likelihood: Double = 0.6) -> ContentCandidate {
        .init(id: .init(id), source: .lookAhead3, nextExposureLikelihood: likelihood, decisionDeadlineNanos: nil,
              fixture: .init(goalFit: 0.8, informationDensity: 0.7, conflicting: true))
    }
    /// High score BUT matches a hard Semantic Shield entity → shield outranks threshold.
    public static func shieldedEntity(_ id: String = "sf-rival", likelihood: Double = 0.9) -> ContentCandidate {
        .init(id: .init(id), source: .lookAhead1, nextExposureLikelihood: likelihood, decisionDeadlineNanos: nil,
              fixture: .init(entities: ["RivalTeam"], goalFit: 0.95, informationDensity: 0.9, manipulationRisk: 0.05))
    }
    /// Factually-correct disease item → Truth/Evidence valid; Positive Exposure may still reject.
    public static func diseaseFactual(_ id: String = "sf-disease", likelihood: Double = 0.85) -> ContentCandidate {
        .init(id: .init(id), source: .lookAhead2, nextExposureLikelihood: likelihood, decisionDeadlineNanos: nil,
              fixture: .init(topics: ["health"], sensitiveCategories: [.disease], goalFit: 0.8,
                             informationDensity: 0.9, manipulationRisk: 0.1, factuallyCorrect: true))
    }
    /// Gore item for child-safety-floor proof.
    public static func goreItem(_ id: String = "sf-gore", likelihood: Double = 0.5) -> ContentCandidate {
        .init(id: .init(id), source: .lookAhead3, nextExposureLikelihood: likelihood, decisionDeadlineNanos: nil,
              fixture: .init(sensitiveCategories: [.gore], goalFit: 0.6, informationDensity: 0.6, manipulationRisk: 0.2))
    }

    // MARK: Profiles

    public static func profileWithHardEntityShield() -> PersonalAlgorithmProfile {
        var p = defaultProfile
        p.shieldRules = [SemanticShieldRule(kind: .entity, value: "RivalTeam", hard: true)]
        return p
    }
    public static func profileAvoidingDisease() -> PersonalAlgorithmProfile {
        var p = defaultProfile
        p.positiveExposure = PositiveExposurePolicy(avoid: [.disease])
        return p
    }
    public static func childSafety() -> SafetyPolicy {
        SafetyPolicy(childMode: true, blockedCategoriesForChild: [.gore])
    }

    // MARK: Long-form TemporalGraph fixtures

    public static let longFormContent = ContentID("vid-1")

    /// Correct graph: content vid-1, version v1 (matches identity). One flagged segment 120–150s.
    public static func correctTemporalGraph() -> TemporalGraphStub {
        TemporalGraphStub(contentID: longFormContent, versionTag: "v1", durationSeconds: 600, segments: [
            .init(index: 0, startSeconds: 0, endSeconds: 120),
            .init(index: 1, startSeconds: 120, endSeconds: 150, flaggedCategories: [.violentConflict]),
            .init(index: 2, startSeconds: 150, endSeconds: 600)
        ])
    }

    /// Wrong-version graph: same content id, DIFFERENT version (alternate cut / inserted ad).
    /// Skip-safety gate must refuse auto-skip against the v1 identity.
    public static func wrongVersionTemporalGraph() -> TemporalGraphStub {
        TemporalGraphStub(contentID: longFormContent, versionTag: "v2-altcut", durationSeconds: 640, segments: [
            .init(index: 0, startSeconds: 0, endSeconds: 130),
            .init(index: 1, startSeconds: 130, endSeconds: 165, flaggedCategories: [.violentConflict]),
            .init(index: 2, startSeconds: 165, endSeconds: 640)
        ])
    }

    public static func longFormIdentity() -> ContentIdentityResult { identity(for: longFormContent) }
}
