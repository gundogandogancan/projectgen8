//
//  GeneralContentCharacterV1.swift — R3 §1/§7: GENERAL CONTENT-CHARACTER CAUTION, end-to-end (the sibling's honest
//  deferral, now wired). The MAIN protection intelligence — NOT the personal shield (§3). It runs the REAL production
//  OCTOPUS language/OCR expert (GuardianCore `LanguageOCRExpertV1`, the SAME code the lab uses) over the OCR text the
//  broadcast extension already has in hand, and translates its honest lexicon evidence into a DISTINCT general-content
//  CAUTION surface — the first honestly-supported general category taken from "computed but collapsed to benign
//  GUARDIAN_ON" all the way to the Island.
//
//  WHY A SEPARATE PURE TYPE (not new intelligence): the extension's `ShieldEvaluatorV2.evaluate` is the PERSONAL
//  shield only (the user's own rules). The general content-character signals are produced by a DIFFERENT OCTOPUS arm,
//  `LanguageOCRExpertV1`, which is `realInProcessLabOnly` — real code, never before reachable on the cross-app path.
//  This type does NOT re-implement that intelligence: it INVOKES the frozen expert and interprets its `labels`/
//  `features` output. So there is no second detection engine (mandate: "Yeni bağımsız zekâ sistemi oluşturma") — the
//  lexicon lives in GuardianCore; we only route its honest output to a surface. Pure + headless + testable: the caller
//  (SampleHandler) hands us the ephemeral OCR text + detected language + the provenance facts, we return a verdict.
//
//  CONTEXT DISCIPLINE (mandate §1 — the hard honesty law):
//   • A lexicon hit is a RISK MARKER ("işaret"), NEVER a certainty of psychological harm. Educational disease content
//     and fear-exploiting disease content both trip the same mortality/disease markers today — the lexicon is
//     context-BLIND. The reason copy therefore says "hassas içerik işaretleri" (sensitive-content MARKERS), never a
//     definitive harm verdict. The §8 corpus MEASURES this limitation honestly; this type must never over-claim.
//   • UNKNOWN discipline (constitution rule 6/7): NO OCR text = NOT_ANALYZED (insufficient evidence), never "safe".
//     OCR text present + NO markers = EXAMINED_NO_MARKER (benign — evidence examined, honest, not a blanket "safe").
//     Only text + a marker above the expert's own supported bar = CAUTION.
//   • SUPPORTED-ONLY: only categories the expert reports with a real (implemented) calibration posture are allowed to
//     drive a CAUTION. Unsupported language → the expert abstains (UNSUPPORTED_LANGUAGE) → we return NOT_ANALYZED.
//   • PERSONAL vs WELLBEING kept STRICTLY SEPARATE (mandate §3/§5): this type NEVER touches the personal shield; the
//     caller keeps the personal-shield surface/reason as its own namespace. A general caution is a WELLBEING signal.
//
//  Lives in GuardianMedia (GuardianCore frozen); imports GuardianCore to call the real expert. Dual-compiled into the
//  app + extension. No numeric 0–100 score anywhere (calibration gate still closed, mandate §5).
//
import Foundation
import GuardianCore

/// R3 §1 — the honestly-supported general content-character categories, mapped 1:1 onto the REAL `LanguageOCRExpertV1`
/// label families. These are MARKERS, not verdicts. Ordering (for a single-category surface pick) is stable and
/// documented — it is NOT a severity calibration (mandate §5: no uncalibrated severity), only a deterministic
/// tie-break so the same evidence always yields the same primary label.
public enum GeneralContentCategoryV1: String, Sendable, Equatable, Codable, CaseIterable {
    case mortality      = "MORTALITY"        // ölüm/savaş — LanguageOCRExpertV1 "topic:mortality"
    case disaster       = "DISASTER"         // felaket/kaza — "topic:disaster"
    case disease        = "DISEASE"          // hastalık — "topic:disease"
    case manipulation   = "MANIPULATION"     // ilgi/manipülasyon dili — "pattern:manipulation-language"
    case emotional      = "EMOTIONAL"        // yoğun olumsuz duygu dili — "pattern:emotional-language"

    /// The expert evidence label this category is derived FROM (provenance: which lexicon family fired).
    public var expertLabel: String {
        switch self {
        case .mortality:    return "topic:mortality"
        case .disaster:     return "topic:disaster"
        case .disease:      return "topic:disease"
        case .manipulation: return "pattern:manipulation-language"
        case .emotional:    return "pattern:emotional-language"
        }
    }
    /// The `features` key carrying the raw hit COUNT for this category (evidence magnitude, not a score).
    public var hitsFeatureKey: String {
        switch self {
        case .mortality:    return "mortalityHits"
        case .disaster:     return "disasterHits"
        case .disease:      return "diseaseHits"
        case .manipulation: return "manipulationHits"
        case .emotional:    return "emotionalHits"
        }
    }
    /// A deterministic primary-pick order (NOT severity). Death/disaster markers are listed first only so the primary
    /// label is stable; every fired category is still carried in `allMarkers` so nothing is hidden.
    var pickOrder: Int {
        switch self {
        case .mortality: return 0; case .disaster: return 1; case .disease: return 2
        case .manipulation: return 3; case .emotional: return 4
        }
    }
}

/// R3 §1 — the honest OUTCOME state of a general content-character pass. Kept categorical (no number).
public enum GeneralContentOutcomeV1: String, Sendable, Equatable, Codable {
    /// A supported marker fired → a distinct general-content CAUTION surface (the first wired general category).
    case caution        = "CAUTION"
    /// OCR text was examined and NO supported marker fired → benign (evidence examined; NOT a blanket "safe" claim).
    case examinedNoMarker = "EXAMINED_NO_MARKER"
    /// Insufficient input to analyze general character: no OCR text, or the expert abstained (unsupported language /
    /// noisy OCR). UNKNOWN ≠ safe (constitution rule 7) — the caller must never upgrade this to a positive surface.
    case notAnalyzed    = "NOT_ANALYZED"
}

/// R3 §1 — the verdict + full provenance for a general content-character pass. Every field is a derived scalar /
/// categorical — NO raw OCR text leaves this struct (privacy); only the fired marker families + hit counts.
public struct GeneralContentCharacterVerdictV1: Sendable, Equatable, Codable {
    public let outcome: GeneralContentOutcomeV1
    /// The PRIMARY marker category that drove a CAUTION (nil unless outcome == .caution). Deterministic pick.
    public let primaryCategory: GeneralContentCategoryV1?
    /// EVERY supported marker family that fired this pass + its raw hit count (provenance: "which evidence").
    public let markers: [GeneralContentMarkerV1]
    /// The detected language the expert actually ran under (provenance). "und"/unsupported → notAnalyzed.
    public let languageRaw: String
    /// Whether the expert flagged the OCR as noisy/OOD (short/low-confidence text) — carried so the surface can be
    /// honest that a marker on noisy OCR is weaker evidence (never suppressed, never upgraded).
    public let ocrNoisy: Bool
    // --- Independent provenance facts (stamped by the caller; mirror the personal-shield match provenance) ---
    public let itemIdentityRevision: Int
    public let policyRevision: UInt64
    public let eventEpoch: Double
    /// The expert model version that produced this (audit: exactly which lexicon revision ran).
    public let expertModelVersion: String

    public init(outcome: GeneralContentOutcomeV1, primaryCategory: GeneralContentCategoryV1?,
                markers: [GeneralContentMarkerV1], languageRaw: String, ocrNoisy: Bool,
                itemIdentityRevision: Int, policyRevision: UInt64, eventEpoch: Double, expertModelVersion: String) {
        self.outcome = outcome; self.primaryCategory = primaryCategory; self.markers = markers
        self.languageRaw = languageRaw; self.ocrNoisy = ocrNoisy
        self.itemIdentityRevision = itemIdentityRevision; self.policyRevision = policyRevision
        self.eventEpoch = eventEpoch; self.expertModelVersion = expertModelVersion
    }

    /// Does this pass warrant a distinct general-content CAUTION surface? (Only the CAUTION outcome.)
    public var isCaution: Bool { outcome == .caution }
}

/// R3 §1 — one fired marker family + its raw hit count (evidence magnitude, never a calibrated score).
public struct GeneralContentMarkerV1: Sendable, Equatable, Codable {
    public let category: GeneralContentCategoryV1
    public let hits: Int
    public init(category: GeneralContentCategoryV1, hits: Int) { self.category = category; self.hits = hits }
}

public enum GeneralContentCharacterV1 {
    /// R3 §1 — the SUPPORTED set: only categories whose expert evidence has an HONEST implemented posture may drive a
    /// CAUTION. All five families the expert emits are lexicon-real (implemented-uncalibrated per §12); we keep the
    /// full set but document that this is a MARKER layer, not a severity-calibrated classifier. The §8 corpus proves
    /// these are context-blind today — which is the honest finding, surfaced as "işaret", never a harm verdict.
    public static let supportedCategories: Set<GeneralContentCategoryV1> =
        [.mortality, .disaster, .disease, .manipulation, .emotional]

    /// R3 §1 — run the REAL `LanguageOCRExpertV1` over the ephemeral OCR text and translate its honest output into a
    /// general content-character verdict. Pure: the same inputs always produce the same verdict (the expert is pure).
    ///
    /// - Parameters mirror what SampleHandler already has after its OCR + identity-resolution step. `ocrText` nil/empty
    ///   or an unsupported language ⇒ `.notAnalyzed` (never "safe"). A supported marker ⇒ `.caution`.
    public static func evaluate(ocrText: String?, detectedLanguage: String?,
                                itemIdentityRevision: Int, policyRevision: UInt64, nowEpoch: Double,
                                expert: LanguageOCRExpertV1 = LanguageOCRExpertV1()) -> GeneralContentCharacterVerdictV1 {
        // No text at all → we did NOT analyze general character. UNKNOWN ≠ safe.
        guard let text = ocrText, !text.isEmpty else {
            return .init(outcome: .notAnalyzed, primaryCategory: nil, markers: [], languageRaw: "none",
                         ocrNoisy: true, itemIdentityRevision: itemIdentityRevision, policyRevision: policyRevision,
                         eventEpoch: nowEpoch, expertModelVersion: expert.modelVersion)
        }
        // Run the SAME production expert the lab uses (sanitize first, exactly like the real runtime does).
        let (input, _) = ExpertInputSanitizerV2.sanitize(
            ExpertInputV2(ocrText: text, detectedLanguage: detectedLanguage))
        let ctx = ExpertTaskContextV2(observationID: ObservationID(0), shotID: nil, itemID: nil,
                                      itemProvisional: true, profile: .extensionFastTier0,
                                      requestedDomains: [.languageOCR], generation: 0)
        let ev = expert.evaluate(input, context: ctx)
        let langRaw = input.detectedLanguage ?? "und"

        // The expert abstains on unsupported language / no text (inputModalityAvailable false, or UNSUPPORTED label).
        // We treat any abstention as NOT_ANALYZED — never a benign/safe claim on content we could not read.
        let unsupported = ev.labels.contains("UNSUPPORTED_LANGUAGE") || !ev.inputModalityAvailable
        if unsupported {
            return .init(outcome: .notAnalyzed, primaryCategory: nil, markers: [], languageRaw: langRaw,
                         ocrNoisy: true, itemIdentityRevision: itemIdentityRevision, policyRevision: policyRevision,
                         eventEpoch: nowEpoch, expertModelVersion: ev.modelVersion)
        }

        // Harvest the SUPPORTED marker families the expert actually reported (its own threshold is "hits > 0").
        var markers: [GeneralContentMarkerV1] = []
        for cat in GeneralContentCategoryV1.allCases where supportedCategories.contains(cat) {
            if ev.labels.contains(cat.expertLabel) {
                let hits = Int(ev.features[cat.hitsFeatureKey] ?? 0)
                markers.append(GeneralContentMarkerV1(category: cat, hits: max(1, hits)))
            }
        }
        let noisy = ev.oodIndicator

        guard !markers.isEmpty else {
            // Text examined, no supported marker → benign (evidence examined; honest, not a blanket "safe").
            return .init(outcome: .examinedNoMarker, primaryCategory: nil, markers: [], languageRaw: langRaw,
                         ocrNoisy: noisy, itemIdentityRevision: itemIdentityRevision, policyRevision: policyRevision,
                         eventEpoch: nowEpoch, expertModelVersion: ev.modelVersion)
        }
        // Deterministic primary pick (stable tie-break, NOT severity). Every fired marker is still carried.
        let primary = markers.map(\.category).min(by: { $0.pickOrder < $1.pickOrder })
        return .init(outcome: .caution, primaryCategory: primary,
                     markers: markers.sorted(by: { $0.category.pickOrder < $1.category.pickOrder }),
                     languageRaw: langRaw, ocrNoisy: noisy,
                     itemIdentityRevision: itemIdentityRevision, policyRevision: policyRevision,
                     eventEpoch: nowEpoch, expertModelVersion: ev.modelVersion)
    }
}
