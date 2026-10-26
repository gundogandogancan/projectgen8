//
//  PressureAnnotationOntologyV1.swift — R8 §5/§6 (P1): the ANNOTATION ONTOLOGY for the manipulation-pressure corpus.
//
//  WHAT THIS IS (mandate §6.B): a VERSIONED, pure, Codable annotation schema for INDEPENDENT human annotation of a
//  rights-clear manipulation-pressure corpus. R7's adversarial self-probe proved the TargetedPressureHeuristicV1 is
//  HIGH-PRECISION / LOW-RECALL (Precision 1.00, Recall 0.22 on fresh phrasing — 7 FNs across 6 mechanism families).
//  The honest path forward is NOT more engineering-authored words (that overfits); it is a real, independently-labelled
//  corpus. This type is that corpus's READINESS: the label space + a JSON schema an annotator (NOT the model-building
//  agent) fills in, with explicit AMBIGUOUS / UNSUPPORTED options and inter-annotator disagreement captured.
//
//  WHAT THIS IS NOT (the honesty laws, mandate §6 / §8 / constitution 1-7):
//   • It is NOT a detector and NOT a model. It produces no verdict, no score, no risk. It is a data schema only.
//   • It does NOT bypass any RWC gate. No rights-clear corpus exists yet; this is corpus READINESS consistent with the
//     existing RWC rights/annotation/calibration gates — all of which remain OPEN. No threshold is fit to R7 cases.
//   • The R7 adversarial set is now REGRESSION-ONLY (mandate §5/§6): these labels are for FUTURE independent data, not
//     for re-scoring the heuristic on the authored sentences.
//   • A classifier/heuristic LABEL is never equated to psychological harm; the ontology captures the MECHANISM a human
//     reader observes, with explicit room for "ambiguous" and "legitimate emergency" — not a harm measurement.
//
//  Pure + headless + Codable + versioned. Lives in GuardianMedia (GuardianCore frozen). No I/O, no model dependency.
//
import Foundation

/// R8 §6.B — the MANIPULATION MECHANISM a human annotator observes. Drawn directly from the R7 failure families (the
/// mechanisms where recall is lost) PLUS the clean/benign classes needed to label a balanced corpus. `ambiguous` and
/// `none` are first-class: an annotator must be able to say "no own-voice pressure here" or "genuinely unclear".
public enum PressureMechanismV1: String, Sendable, Equatable, Codable, CaseIterable {
    case directedDemeaning   = "DIRECTED_DEMEANING"    // explicit 2nd-person insult/attack (R7's one caught family)
    case conditionalGuilt    = "CONDITIONAL_GUILT"     // "if you really cared…" — guilt/shame coercion (R7 FN)
    case shameCoercion       = "SHAME_COERCION"        // shaming to compel behaviour (R7 FN family)
    case deceptiveUrgency    = "DECEPTIVE_URGENCY"     // fake scarcity/urgency to force action (R7 FN)
    case provocationIncitement = "PROVOCATION_INCITEMENT" // incitement to act against a target (R7 FN)
    case fearToAction        = "FEAR_TO_ACTION"        // fear/threat → behaviour (register-level pressure)
    case implicitTargeting   = "IMPLICIT_TARGETING"    // directed pressure with an unnamed/implicit target (R7 gap)
    case legitimateEmergency = "LEGITIMATE_EMERGENCY"  // real warning/evacuation — NOT manipulation (must not FP)
    case criticismNotAttack  = "CRITICISM_NOT_ATTACK"  // institution/idea criticism — not a directed personal attack
    case quotedOrReported    = "QUOTED_OR_REPORTED"    // the pressure is quoted/attributed, not own-voice
    case satireIrony         = "SATIRE_IRONY"          // ironic/figurative — not literal pressure
    case supportive          = "SUPPORTIVE"            // supportive/consoling — the opposite of pressure
    case ambiguous           = "AMBIGUOUS"             // genuinely unclear (annotator records WHY in notes)
    case none                = "NONE"                  // no manipulation mechanism present
}

/// R8 §6.B — WHO the directed pressure is aimed at (the target-resolution dimension R7 got brittle on, esp. mixed TR/EN).
public enum PressureTargetV1: String, Sendable, Equatable, Codable, CaseIterable {
    case secondPersonViewer = "SECOND_PERSON_VIEWER"   // "you" — the person watching
    case namedPerson        = "NAMED_PERSON"
    case group              = "GROUP"
    case institution        = "INSTITUTION"
    case thirdParty         = "THIRD_PARTY"
    case implicit           = "IMPLICIT"               // target implied, not named (R7 implicit-target gap)
    case none               = "NONE"
    case unsupported        = "UNSUPPORTED"
}

/// R8 §6.B — the speaker's COMMUNICATIVE INTENT (separate from mechanism: a mechanism can appear in a reporting voice).
public enum CommunicativeIntentV1: String, Sendable, Equatable, Codable, CaseIterable {
    case coerce = "COERCE", persuade = "PERSUADE", inform = "INFORM", warn = "WARN"
    case criticize = "CRITICIZE", entertain = "ENTERTAIN", support = "SUPPORT", express = "EXPRESS"
    case ambiguous = "AMBIGUOUS", unsupported = "UNSUPPORTED"
}

/// R8 §6.B — the speaker's STANCE toward any harmful content mentioned (REPORTS ≠ ENDORSES — the R4 distinction).
public enum AnnotatedStanceV1: String, Sendable, Equatable, Codable, CaseIterable {
    case advocates = "ADVOCATES", reports = "REPORTS", criticizes = "CRITICIZES"
    case victimSupport = "VICTIM_SUPPORT", neutral = "NEUTRAL", ambiguous = "AMBIGUOUS", unsupported = "UNSUPPORTED"
}

/// R8 §6.B — the EMOTIONAL PRESSURE intensity the annotator reads (ordinal; NOT a calibrated score — a human label).
public enum EmotionalPressureLevelV1: String, Sendable, Equatable, Codable, CaseIterable {
    case none = "NONE", mild = "MILD", moderate = "MODERATE", strong = "STRONG", ambiguous = "AMBIGUOUS"
}

/// R8 §6.B — the language / code-switching of the item (R7's mixed TR/EN resolution was brittle; this is captured).
public enum AnnotatedLanguageV1: String, Sendable, Equatable, Codable, CaseIterable {
    case turkish = "TR", english = "EN", mixedTrEn = "MIXED_TR_EN", other = "OTHER", unknown = "UNKNOWN"
}

/// R8 §6.B — ONE annotation record for ONE corpus item, filled by an INDEPENDENT annotator. Carries the mechanism,
/// target, intent, stance, pressure level, the quote/attribution flag, the legitimate-emergency flag, the ambiguous
/// flag, language, the annotator id (for inter-annotator agreement), and free-text notes (WHY / disagreement). It is
/// PURE DATA — it produces no verdict. The `schemaVersion` makes the JSON forward/backward tolerant.
public struct PressureAnnotationRecordV1: Sendable, Equatable, Codable {
    public static let schemaVersion = "pressure-annotation-ontology-v1"
    public let schemaVersion_: String
    /// An opaque corpus-item id (rights-clear, de-identified — never raw user content keyed to a person).
    public let itemID: String
    /// The annotator id (pseudonymous) — so independent labels can be compared and disagreement measured.
    public let annotatorID: String
    public let mechanism: PressureMechanismV1
    public let target: PressureTargetV1
    public let intent: CommunicativeIntentV1
    public let stance: AnnotatedStanceV1
    public let emotionalPressure: EmotionalPressureLevelV1
    /// True when the pressure is QUOTED/ATTRIBUTED (not the speaker's own voice) — a hard safety law (never own-voice).
    public let quotedNotOwnVoice: Bool
    /// True when this is a REAL emergency (evacuation/official warning) — must NOT be labelled deceptive urgency.
    public let legitimateEmergency: Bool
    /// True when the annotator could not confidently assign a mechanism (also reflected in `mechanism == .ambiguous`).
    public let ambiguous: Bool
    public let language: AnnotatedLanguageV1
    /// Free-text rationale / disagreement note (WHY this label; never raw PII). Optional.
    public let notes: String?

    public init(itemID: String, annotatorID: String, mechanism: PressureMechanismV1, target: PressureTargetV1,
                intent: CommunicativeIntentV1, stance: AnnotatedStanceV1, emotionalPressure: EmotionalPressureLevelV1,
                quotedNotOwnVoice: Bool, legitimateEmergency: Bool, ambiguous: Bool, language: AnnotatedLanguageV1,
                notes: String? = nil) {
        self.schemaVersion_ = Self.schemaVersion
        self.itemID = itemID; self.annotatorID = annotatorID; self.mechanism = mechanism; self.target = target
        self.intent = intent; self.stance = stance; self.emotionalPressure = emotionalPressure
        self.quotedNotOwnVoice = quotedNotOwnVoice; self.legitimateEmergency = legitimateEmergency
        self.ambiguous = ambiguous; self.language = language; self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion_ = "schemaVersion"
        case itemID, annotatorID, mechanism, target, intent, stance, emotionalPressure
        case quotedNotOwnVoice, legitimateEmergency, ambiguous, language, notes
    }
}

/// R8 §6.B/§6.C — INTER-ANNOTATOR agreement over the SAME item: the distinct mechanism labels assigned by independent
/// annotators + whether they agreed. Disagreement is RECORDED, never silently resolved by the model-building agent
/// (mandate §6.C: labels must not come only from the engineering agent; disagreement/ambiguity is tracked).
public struct PressureAnnotationAgreementV1: Sendable, Equatable, Codable {
    public let itemID: String
    public let records: [PressureAnnotationRecordV1]
    public init(itemID: String, records: [PressureAnnotationRecordV1]) {
        self.itemID = itemID; self.records = records
    }
    /// The distinct mechanism labels across annotators (how much they diverged).
    public var distinctMechanisms: [PressureMechanismV1] {
        var seen: [PressureMechanismV1] = []
        for r in records where !seen.contains(r.mechanism) { seen.append(r.mechanism) }
        return seen
    }
    /// True when ≥2 annotators agree on the SAME mechanism (a usable gold label candidate).
    public var hasMajorityMechanism: Bool {
        guard records.count >= 2 else { return false }
        var counts: [PressureMechanismV1: Int] = [:]
        for r in records { counts[r.mechanism, default: 0] += 1 }
        return (counts.values.max() ?? 0) >= 2
    }
    /// The majority mechanism when one exists (≥2 agree); nil on a full split (recorded as unresolved disagreement).
    public var majorityMechanism: PressureMechanismV1? {
        guard records.count >= 2 else { return records.first?.mechanism }
        var counts: [PressureMechanismV1: Int] = [:]
        for r in records { counts[r.mechanism, default: 0] += 1 }
        guard let best = counts.max(by: { $0.value < $1.value }), best.value >= 2 else { return nil }
        return best.key
    }
    public var annotatorsDisagree: Bool { distinctMechanisms.count > 1 }
}

public enum PressureAnnotationOntologyV1 {
    public static let version = "pressure-annotation-ontology-v1"

    /// R8 §6.D — HONEST on-device model-candidate capability probe. We do NOT fabricate availability: these are real
    /// compile-time `canImport` facts for the installed SDK, cited by the root-cause doc. Apple NaturalLanguage is
    /// present (already used across GuardianIntelligence). Apple's Foundation Models framework is reported ONLY if the
    /// installed SDK actually exposes it (`canImport(FoundationModels)`); otherwise it is honestly reported absent —
    /// never assumed. A CoreML small-classifier path is importable but BLOCKED on a rights-clear annotated corpus.
    public static var naturalLanguageAvailable: Bool {
        #if canImport(NaturalLanguage)
        return true
        #else
        return false
        #endif
    }
    public static var foundationModelsAvailable: Bool {
        #if canImport(FoundationModels)
        return true
        #else
        return false
        #endif
    }
    public static var coreMLAvailable: Bool {
        #if canImport(CoreML)
        return true
        #else
        return false
        #endif
    }

    /// R8 §6.B — the R7 failure-family → ontology-mechanism mapping (traceability from the failure map to the schema).
    /// This is documentation-as-code: it proves every missed R7 mechanism family has an annotation label waiting for
    /// independent data. It is NOT a detector table — there is no text, no cue, no threshold here.
    public static let r7FailureFamilyToMechanism: [String: PressureMechanismV1] = [
        "fake-urgency":          .deceptiveUrgency,
        "guilt-coercion":        .conditionalGuilt,
        "multi-speaker":         .directedDemeaning,      // the directed line inside a dialogue (speaker segmentation gap)
        "mixed-directed":        .directedDemeaning,      // mixed TR/EN target resolution (target dimension captures it)
        "incitement":            .provocationIncitement,
        "implicit-target":       .implicitTargeting]

    /// R8 §6.B — emit the JSON SCHEMA (a Codable sample record) so an independent annotation tool can validate against
    /// a concrete example. Pure; deterministic; produces a canonical example record, NOT real data.
    public static func exampleRecordJSON() -> String? {
        let example = PressureAnnotationRecordV1(
            itemID: "corpus-item-0001", annotatorID: "annotator-A",
            mechanism: .conditionalGuilt, target: .secondPersonViewer, intent: .coerce,
            stance: .advocates, emotionalPressure: .moderate, quotedNotOwnVoice: false,
            legitimateEmergency: false, ambiguous: false, language: .mixedTrEn,
            notes: "Conditional-guilt structure ('if you really cared…') directed at the viewer.")
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? enc.encode(example)).flatMap { String(data: $0, encoding: .utf8) }
    }
}
