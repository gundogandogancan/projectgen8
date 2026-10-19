import Foundation

// MARK: - Personal Projection Layer (PROMPT 004 §25) — cheap personal decision over reusable shared analysis.
// Does NOT re-run heavy content analysis per user. Shared (non-personal) CoarseTemporalMap + personal policy
// → personal admission. Deterministic; measured separately from analysis cost.

public struct PersonalProjectionLayer: Sendable {
    public static let version = "personal-projection-v1"
    private let fusion = ScoreAdmissionFusionV1()
    public init() {}

    /// Project a shared coarse map into a personal whole-video admission using only cheap policy logic.
    public func project(map: CoarseTemporalMapV1, profile: PersonalAlgorithmProfile,
                        positiveMode: PositiveExposureMode, childPolicy: SafetyPolicy,
                        shield: ShieldDecision = .noMatch, availableHeadCount: Int) -> FusionResultV1 {
        // Aggregate shared (non-personal) signals from the map into topic labels (reuse, no reanalysis).
        var labels: [MortalityDiseaseDisasterLabel] = []
        let cats = Set(map.flaggedWindows.flatMap { $0.categories })
        if cats.contains(.death) { labels.append(.mortality) }
        if cats.contains(.disease) { labels.append(.diseaseIllness) }
        if cats.contains(.disaster) { labels.append(.disaster) }
        if cats.contains(.severeAccident) { labels.append(.severeAccident) }
        if cats.contains(.violentConflict) { labels.append(.warConflict) }

        let inputs = FusionInputsV1(contentID: map.contentID, mddLabels: labels,
                                    shield: shield, profile: profile, positiveMode: positiveMode,
                                    childPolicy: childPolicy, availableHeadCount: availableHeadCount)
        return fusion.decide(inputs)
    }
}
