//
//  ContributionEvidenceContractV1.swift — R11-D P1: the DIGITAL CONTRIBUTION INTELLIGENCE CONTRACT (pure types) +
//  the weekly/monthly report DATA CONTRACT + the LOCKED composite Contribution Score (mandate document-2 §5/§6).
//
//  WHAT IT IS: the long-term capability REGISTRATION — how observed consumption RELATES to knowledge/learning,
//  emotional experience, personal goals, and time use — expressed as THREE SEPARATE EVIDENCE CLASSES, plus the exact
//  report field contract (calendar week + calendar month recomputed from eligible days), plus a composite score TYPE
//  that is DISABLED (locked, like P009E) until validity + calibration. NO report UI this round (that is R12).
//
//  THE SEPARATION LAWS (mandate §5):
//    • CONTENT SIGNAL  — what OCTOPUS observes/infers about content (derived; uncertainty-bearing).
//    • USER OUTCOME    — what the user VOLUNTARILY reports/confirms (shown clearly as self-reported).
//    • UNKNOWN IMPACT  — what cannot be concluded (the honest default; never silently promoted).
//  Educational-looking ≠ learning. Negative emotion ≠ harm. Longer watching ≠ more benefit. Entertainment/rest ≠
//  wasted time. No inferred emotional states / mental-health conditions / speculative life claims as facts.
//
//  CONTRIBUTION SCORE ≠ P009E PERSONAL SUITABILITY: different constructs, labels, calibration, release gates. The
//  production composite Contribution Score is DISABLED until validity + calibration. `ContributionScoreV1.value` is
//  ALWAYS nil (locked) and `locked == true` — pinned by test, mirroring the P009E numeric lock. No leakage.
//
//  Pure value types + a pure aggregator. Lives in GuardianMedia (GuardianCore frozen). Calendar math uses the user's
//  locale/calendar/timezone for PERIOD boundaries; monthly is recomputed from eligible DAYS (never overlapping weekly
//  sums). Duration totals come from the ledger's MONOTONIC observed durations.
//
import Foundation

// MARK: - §5 the three evidence classes

public enum ContributionEvidenceClassV1: String, Sendable, Equatable, Codable, CaseIterable {
    case contentSignal = "CONTENT_SIGNAL"   // what OCTOPUS observed/inferred (derived; uncertainty-bearing)
    case userOutcome   = "USER_OUTCOME"     // what the user voluntarily reported/confirmed (self-reported)
    case unknownImpact = "UNKNOWN_IMPACT"   // what cannot be concluded (the honest default)
}

/// R11 §5 — a single contribution evidence item. An item ALWAYS declares its class, so a self-reported outcome can
/// never be read as a measured content signal (and vice-versa), and UNKNOWN is explicit. `confidence` is declared,
/// not calibrated; for USER_OUTCOME it is the user's own rating normalised, labelled self-reported.
public struct ContributionEvidenceItemV1: Sendable, Equatable, Codable {
    public let evidenceClass: ContributionEvidenceClassV1
    /// Which contribution DIMENSION this relates to (knowledge / emotion / goals / timeUse). Never a verdict.
    public let dimension: ContributionDimensionV1
    public let label: String
    public let declaredConfidence: Double
    public let provenance: String
    /// True ONLY for USER_OUTCOME items — the surface must render these explicitly as "self-reported".
    public let selfReported: Bool
    public init(evidenceClass: ContributionEvidenceClassV1, dimension: ContributionDimensionV1, label: String,
                declaredConfidence: Double, provenance: String, selfReported: Bool) {
        self.evidenceClass = evidenceClass; self.dimension = dimension; self.label = label
        self.declaredConfidence = declaredConfidence; self.provenance = provenance; self.selfReported = selfReported
    }
}

public enum ContributionDimensionV1: String, Sendable, Equatable, Codable, CaseIterable {
    case knowledgeLearning = "KNOWLEDGE_LEARNING"      // A
    case emotionalExperience = "EMOTIONAL_EXPERIENCE"  // B (+ self-reported mood)
    case personalGoals = "PERSONAL_GOALS"              // C (+ real-life usefulness)
    case timeUse = "TIME_USE"                          // D (time, rest, intentionality)
}

// MARK: - §5 the LOCKED composite Contribution Score (disabled, like P009E)

/// R11 §5 — the composite Contribution Score TYPE. It EXISTS to register the capability, but its numeric value is
/// LOCKED: `value` is ALWAYS nil and `locked` is ALWAYS true until validity + calibration (a separate release gate
/// from P009E). This mirrors the P009E numeric lock discipline — the type can be referenced, but it can NEVER emit a
/// number this round. Pinned by test. Contribution Score ≠ P009E Suitability (different constructs; no leakage).
public struct ContributionScoreV1: Sendable, Equatable, Codable {
    public static let lockReason = "CONTRIBUTION_SCORE_DISABLED_UNTIL_VALIDITY_AND_CALIBRATION (separate gate from P009E; different construct)"
    public let locked: Bool
    public let value: Double?
    public let reason: String
    /// The ONLY permitted construction this round: locked, no value. There is no initializer that accepts a value.
    public init() { self.locked = true; self.value = nil; self.reason = ContributionScoreV1.lockReason }
}

// MARK: - §6 the report period contract

public enum ContributionReportPeriodKindV1: String, Sendable, Equatable, Codable { case weekly = "WEEKLY", monthly = "MONTHLY" }

/// R11 §6 — report eligibility. A report must state when GEN8 observed only PART of a week/month (partial coverage),
/// and why it is unavailable when it is.
public enum ContributionReportEligibilityV1: String, Sendable, Equatable, Codable {
    case eligible = "ELIGIBLE"
    case partialCoverage = "PARTIAL_COVERAGE"            // observed only part of the period — must be declared
    case ineligibleLowCoverage = "INELIGIBLE_LOW_COVERAGE" // too little observed to report honestly
    case ineligibleEmpty = "INELIGIBLE_EMPTY"            // nothing observed in the period
    case ineligibleConsentOff = "INELIGIBLE_CONSENT_OFF" // the ledger was off / consent withdrawn
}

/// R11 §6 — the weekly/monthly report data contract. Every field is HONEST: observed content time (from monotonic
/// durations), unique + repeat observations (separated), analysis coverage + missing data, observed themes,
/// potentially-educational content WITH uncertainty, OPTIONAL user-reported learning/emotion/goals (self-reported),
/// user-defined time goals + observed progress, data completeness + provenance, eligibility + unavailable reasons.
/// The composite score is carried LOCKED.
public struct ContributionReportV1: Sendable, Equatable, Codable {
    public static let schemaVersion = 1
    public var schema: Int
    public let periodKind: ContributionReportPeriodKindV1
    /// Period boundaries as LOCAL calendar epochs (start inclusive, end exclusive).
    public let periodStartEpoch: Double
    public let periodEndEpoch: Double
    /// Observed content TIME in seconds (sum of monotonic observed durations in the period). Time exposed ≠ attention.
    public let observedContentSeconds: Double
    public let uniqueObservations: Int
    public let repeatObservations: Int
    /// Average analysis coverage across observations (0...1), and the modalities with MISSING data.
    public let averageCoverage: Double
    public let missingModalities: [String]
    public let observedThemes: [String]
    /// Content that LOOKED potentially educational, carried WITH its uncertainty (educational-looking ≠ learning).
    public let potentiallyEducationalCount: Int
    public let educationalUncertaintyNote: String
    /// OPTIONAL self-reported items (USER_OUTCOME class only; rendered as self-reported).
    public let userReported: [ContributionEvidenceItemV1]
    /// The evidence items (all three classes) feeding the report, for provenance.
    public let evidence: [ContributionEvidenceItemV1]
    public let dataCompletenessNote: String
    public let eligibility: ContributionReportEligibilityV1
    public let unavailableReason: String?
    /// The composite Contribution Score — ALWAYS LOCKED this round.
    public let score: ContributionScoreV1

    public init(periodKind: ContributionReportPeriodKindV1, periodStartEpoch: Double, periodEndEpoch: Double,
                observedContentSeconds: Double, uniqueObservations: Int, repeatObservations: Int,
                averageCoverage: Double, missingModalities: [String], observedThemes: [String],
                potentiallyEducationalCount: Int, educationalUncertaintyNote: String,
                userReported: [ContributionEvidenceItemV1], evidence: [ContributionEvidenceItemV1],
                dataCompletenessNote: String, eligibility: ContributionReportEligibilityV1,
                unavailableReason: String?, score: ContributionScoreV1 = ContributionScoreV1(),
                schema: Int = ContributionReportV1.schemaVersion) {
        self.schema = schema; self.periodKind = periodKind
        self.periodStartEpoch = periodStartEpoch; self.periodEndEpoch = periodEndEpoch
        self.observedContentSeconds = observedContentSeconds
        self.uniqueObservations = uniqueObservations; self.repeatObservations = repeatObservations
        self.averageCoverage = averageCoverage; self.missingModalities = missingModalities
        self.observedThemes = observedThemes
        self.potentiallyEducationalCount = potentiallyEducationalCount
        self.educationalUncertaintyNote = educationalUncertaintyNote
        self.userReported = userReported; self.evidence = evidence
        self.dataCompletenessNote = dataCompletenessNote; self.eligibility = eligibility
        self.unavailableReason = unavailableReason; self.score = score
    }
}

// MARK: - §6 the pure aggregator (calendar + timezone safe)

/// R11 §6 — the PURE report aggregator. Computes a weekly (calendar week) or monthly (calendar month recomputed from
/// eligible DAYS) report from ledger records, using the supplied calendar (user locale/tz). Weekly sums are NOT reused
/// for monthly — monthly is recomputed from the period's records directly. Honest eligibility: empty / low-coverage /
/// partial-coverage / consent-off are all declared. No invented full-device history; unobserved time never counted.
public enum ContributionReportAggregatorV1 {
    public static let version = "contribution-report-aggregator-v1"
    /// Minimum observed seconds in a period for an ELIGIBLE (not low-coverage) report.
    public static let minObservedSecondsForEligible: Double = 60.0

    /// Compute the LOCAL calendar period containing `nowEpoch`. Weekly = the calendar week; monthly = the calendar
    /// month. Returns [start, end) epochs. Uses the supplied calendar's timezone/firstWeekday (so a tz change moves
    /// the boundaries honestly, pinned by test).
    public static func period(kind: ContributionReportPeriodKindV1, containing nowEpoch: Double,
                              calendar: Calendar) -> (startEpoch: Double, endEpoch: Double) {
        let now = Date(timeIntervalSince1970: nowEpoch)
        let component: Calendar.Component = (kind == .weekly) ? .weekOfYear : .month
        guard let interval = calendar.dateInterval(of: component, for: now) else {
            return (nowEpoch, nowEpoch)   // degenerate; honest empty window
        }
        return (interval.start.timeIntervalSince1970, interval.end.timeIntervalSince1970)
    }

    /// Build a report for the period containing `nowEpoch`. `consentEnabled` false → INELIGIBLE_CONSENT_OFF with no
    /// counting. Records are filtered to the period by their LOCAL observation start stamp.
    public static func report(kind: ContributionReportPeriodKindV1,
                              records: [DigitalObservationRecordV1],
                              userReported: [ContributionEvidenceItemV1] = [],
                              consentEnabled: Bool, nowEpoch: Double, calendar: Calendar) -> ContributionReportV1 {
        let (start, end) = period(kind: kind, containing: nowEpoch, calendar: calendar)
        let emptyScore = ContributionScoreV1()

        guard consentEnabled else {
            return ContributionReportV1(periodKind: kind, periodStartEpoch: start, periodEndEpoch: end,
                                        observedContentSeconds: 0, uniqueObservations: 0, repeatObservations: 0,
                                        averageCoverage: 0, missingModalities: [], observedThemes: [],
                                        potentiallyEducationalCount: 0,
                                        educationalUncertaintyNote: "Eğitici görünüm öğrenme anlamına gelmez.",
                                        userReported: [], evidence: [],
                                        dataCompletenessNote: "Günlük kapalı/izin yok — kayıt tutulmadı.",
                                        eligibility: .ineligibleConsentOff,
                                        unavailableReason: "consent-off-or-withdrawn", score: emptyScore)
        }

        // Filter to the period by the LOCAL observation start stamp (unobserved time never counted).
        let inPeriod = records.filter { $0.observationStartEpoch >= start && $0.observationStartEpoch < end }
        let observedSeconds = inPeriod.reduce(0.0) { $0 + $1.observedDurationSeconds }
        let unique = inPeriod.filter { !$0.isRepeatView }.count
        let repeated = inPeriod.filter { $0.isRepeatView }.count

        // Average coverage across all modality fractions present (honest; absent modality = missing data).
        var coverSum = 0.0; var coverN = 0
        var missing = Set<String>(["VISION", "SPEECH", "MUSIC", "SYMBOL", "AUDIO_EVENT"])
        for r in inPeriod {
            for (mod, frac) in r.coverageByModality { coverSum += frac; coverN += 1; missing.remove(mod.uppercased()) }
        }
        let avgCoverage = coverN > 0 ? coverSum / Double(coverN) : 0

        let themes = Array(Set(inPeriod.flatMap { $0.derivedThemes })).sorted()
        // Potentially-educational = themes carrying an "educational"/"learning" marker — WITH uncertainty, never fact.
        let eduCount = inPeriod.filter { $0.derivedThemes.contains { $0.lowercased().contains("educ") || $0.lowercased().contains("learn") } }.count

        // Content-signal evidence items (derived) + the self-reported user items.
        var evidence: [ContributionEvidenceItemV1] = userReported.filter { $0.evidenceClass == .userOutcome }
        if eduCount > 0 {
            evidence.append(ContributionEvidenceItemV1(
                evidenceClass: .contentSignal, dimension: .knowledgeLearning,
                label: "potentially-educational-themes(\(eduCount))", declaredConfidence: 0.3,
                provenance: "\(version): derived theme marker; educational-looking ≠ learning", selfReported: false))
        }
        // Everything we cannot conclude is explicit UNKNOWN_IMPACT (never silently promoted).
        evidence.append(ContributionEvidenceItemV1(
            evidenceClass: .unknownImpact, dimension: .emotionalExperience,
            label: "emotional-impact-unknown", declaredConfidence: 0,
            provenance: "\(version): no inferred emotional state; mood only if self-reported", selfReported: false))

        // Eligibility.
        let eligibility: ContributionReportEligibilityV1
        var unavailable: String? = nil
        if inPeriod.isEmpty {
            eligibility = .ineligibleEmpty; unavailable = "no-observations-in-period"
        } else if observedSeconds < minObservedSecondsForEligible {
            eligibility = .ineligibleLowCoverage; unavailable = "below-min-observed-seconds(\(Int(observedSeconds))<\(Int(minObservedSecondsForEligible)))"
        } else {
            // Partial vs full: did the FIRST observation start after the period start, or did coverage obviously miss
            // modalities? We conservatively declare PARTIAL whenever any modality is missing or the period is ongoing.
            let periodOngoing = nowEpoch < end
            eligibility = (periodOngoing || !missing.isEmpty) ? .partialCoverage : .eligible
            if eligibility == .partialCoverage { unavailable = "partial-coverage(ongoing=\(periodOngoing),missing=\(missing.sorted().joined(separator: ",")))" }
        }

        let completenessNote = "GEN8 yalnızca gözlemlediği bölümü sayar; görülmeyen kullanım GEN8'e atfedilmez. Süre = gözlem süresi, dikkat/anlama değil."

        return ContributionReportV1(
            periodKind: kind, periodStartEpoch: start, periodEndEpoch: end,
            observedContentSeconds: observedSeconds, uniqueObservations: unique, repeatObservations: repeated,
            averageCoverage: avgCoverage, missingModalities: missing.sorted(), observedThemes: themes,
            potentiallyEducationalCount: eduCount,
            educationalUncertaintyNote: "Eğitici görünüm öğrenme anlamına gelmez; belirsizlikle sunulur.",
            userReported: userReported.filter { $0.evidenceClass == .userOutcome },
            evidence: evidence, dataCompletenessNote: completenessNote,
            eligibility: eligibility, unavailableReason: unavailable, score: emptyScore)
    }
}
