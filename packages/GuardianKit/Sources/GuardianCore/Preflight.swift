import Foundation

// MARK: - Fast preflight (HEURISTIC_V0) — deterministic, explicitly labelled, NOT production AI
// Ref: PROMPT 001 §3, §4; Build Bible §84, §629. Produces component signals + a score STATE.
// The final number is computed by the deterministic score formula (ScoreEngine), never by an LLM.

public struct PreflightResult: Sendable, Equatable {
    public let contentID: ContentID
    public let signals: FixtureSignals?
    public let provenance: SignalProvenance
    public init(contentID: ContentID, signals: FixtureSignals?, provenance: SignalProvenance) {
        self.contentID = contentID
        self.signals = signals
        self.provenance = provenance
    }
}

/// HEURISTIC_V0 preflight: reads deterministic fixture signals. Replaceable later by a real model
/// adapter WITHOUT changing the pipeline (dependency boundary).
public struct HeuristicV0Preflight: Sendable {
    public static let version = "heuristic-v0"
    public init() {}
    public func run(candidate: ContentCandidate) -> PreflightResult {
        PreflightResult(contentID: candidate.id, signals: candidate.fixture, provenance: .heuristicV0)
    }
}

/// Deterministic, versioned score formula. Same inputs + version ⇒ same output (reproducibility, App G.15).
public struct ScoreEngine: Sendable {
    public static let formulaVersion = "pbs-formula-v0.1"
    public init() {}

    /// Explicit deterministic formula over 0...1 components, mapped to 0...10.
    /// RawBenefit = (0.5*goalFit + 0.5*informationDensity) - 0.6*manipulationRisk  (clamped 0...1), ×10.
    public func score(_ signals: FixtureSignals?) -> PBSResult {
        guard let s = signals, s.hasSufficientEvidence else {
            return PBSResult(value: nil, state: .insufficientEvidence, provenance: .heuristicV0, formulaVersion: Self.formulaVersion)
        }
        if s.conflicting {
            return PBSResult(value: nil, state: .conflicting, provenance: .heuristicV0, formulaVersion: Self.formulaVersion)
        }
        let rawBenefit = (0.5 * s.goalFit + 0.5 * s.informationDensity) - 0.6 * s.manipulationRisk
        let clamped = min(max(rawBenefit, 0), 1)
        let value = (clamped * 10 * 10).rounded() / 10   // 1-decimal, deterministic
        // VERIFIED_FAST only when evidence is strong (low manipulation + real density); else provisional.
        let state: ScoreState = (s.informationDensity >= 0.5 && s.manipulationRisk <= 0.4) ? .verifiedFast : .provisionalFast
        return PBSResult(value: value, state: state, provenance: .heuristicV0, formulaVersion: Self.formulaVersion)
    }
}
