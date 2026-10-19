import Foundation

// MARK: - P009C-R1 §3/§5 — TYPED DURABLE SEMANTICS. The F-1 law: a provider/free-form label is
// EPHEMERAL ONLY; durable DNA may carry nothing but schema-controlled, versioned, non-reconstructive
// canonical atoms produced by an explicit closed-vocabulary mapper. The forbidden path
// `raw provider string → entity:<raw> → durable DNA` is structurally impossible: unmapped labels yield
// UNKNOWN/UNMAPPED and never a durable atom. This is a vocabulary law, NOT a token blacklist.

public enum DurableAtomKindV1: String, Sendable, Codable {
    case personPresent = "PERSON_PRESENT"
    case organization = "ORGANIZATION_CANONICAL_ID"
    case place = "PLACE_CANONICAL_ID"
    case product = "PRODUCT_CANONICAL_ID"
    case objectConcept = "OBJECT_CONCEPT_ID"
    case activityConcept = "ACTIVITY_CONCEPT_ID"
    case eventConcept = "EVENT_CONCEPT_ID"
    case abstractConcept = "ABSTRACT_CONCEPT_ID"
    case brandCandidate = "BRAND_CANDIDATE_CANONICAL"
}

public struct DurableSemanticAtomV1: Sendable, Hashable, Codable {
    public let atomID: String                      // canonical, from the closed vocabulary ONLY
    public let kind: DurableAtomKindV1
    public let vocabularyVersion: String
    public init(atomID: String, kind: DurableAtomKindV1, vocabularyVersion: String = DurableEntityVocabularyV1.version) {
        self.atomID = atomID; self.kind = kind; self.vocabularyVersion = vocabularyVersion
    }
}

/// §5 — the CLOSED, versioned provider-label → durable-atom vocabulary. Atom IDs reuse the established
/// canonical forms so prior evidence stays coherent — but the STRINGS are now producible only from this
/// table, never from provider text.
public enum DurableEntityVocabularyV1 {
    public static let version = "durable-entity-vocab-v1"
    static func entry(_ kind: EntityKindV1, _ atomKind: DurableAtomKindV1, _ id: String) -> (EntityKindV1, DurableSemanticAtomV1) {
        (kind, DurableSemanticAtomV1(atomID: id, kind: atomKind))
    }
    /// visual provider label → (entity kind, durable atom). Unlisted labels have NO durable form.
    public static let visualLabelAtoms: [String: (EntityKindV1, DurableSemanticAtomV1)] = [
        "forest": entry(.place, .place, "entity:place:forest"),
        "river": entry(.place, .place, "entity:place:river"),
        "mountain": entry(.place, .place, "entity:place:mountain"),
        "lake": entry(.place, .place, "entity:place:lake"),
        "spa": entry(.place, .place, "entity:place:spa"),
        "candles": entry(.object, .objectConcept, "entity:object:candles"),
        "whiteboard": entry(.object, .objectConcept, "entity:object:whiteboard"),
        "classroom": entry(.place, .place, "entity:place:classroom"),
        "laboratory": entry(.place, .place, "entity:place:laboratory"),
        "workshop": entry(.place, .place, "entity:place:workshop"),
        "workbench": entry(.object, .objectConcept, "entity:object:workbench"),
        "kitchen": entry(.place, .place, "entity:place:kitchen"),
        "cooking-pan": entry(.object, .objectConcept, "entity:object:cooking-pan"),
        "party": entry(.activity, .activityConcept, "entity:activity:party"),
        "balloons": entry(.object, .objectConcept, "entity:object:balloons"),
        "wedding": entry(.activity, .activityConcept, "entity:activity:wedding"),
        "warning-sign": entry(.object, .objectConcept, "entity:object:warning-sign"),
        "caution-tape": entry(.object, .objectConcept, "entity:object:caution-tape"),
        "person-speaking": entry(.personPresent, .personPresent, "entity:person-present:speaker"),
        "street": entry(.place, .place, "entity:place:street"),
        "smoke": entry(.object, .objectConcept, "entity:object:smoke"),
        "audience": entry(.activity, .activityConcept, "entity:activity:audience"),
        "foggy-scene": entry(.place, .place, "entity:place:foggy-scene"),
        "beach": entry(.place, .place, "entity:place:beach")
    ]
    public static var allAtomIDs: Set<String> { Set(visualLabelAtoms.values.map { $0.1.atomID }) }
    /// provider label → durable atom; nil = UNMAPPED (stays ephemeral/UNKNOWN; never durable)
    public static func atom(forProviderLabel label: String) -> (EntityKindV1, DurableSemanticAtomV1)? {
        visualLabelAtoms[label]
    }
}

// MARK: - §4 — PersistenceLawValidatorV2: field-schema classification. NO prefix-only acceptance —
// every durable string must be a member of a CLOSED registry or match a STRICT structured grammar
// whose free segments are numeric only. Unknown schema → fail closed.

public enum PersistenceFieldClassV1: String, Sendable {
    case allowedDurableCanonical = "ALLOWED_DURABLE_CANONICAL"
    case allowedDerivedNumeric = "ALLOWED_DERIVED_NUMERIC"
    case allowedVersionMetadata = "ALLOWED_VERSION_METADATA"
    case forbiddenRawOrReconstructive = "FORBIDDEN_RAW_OR_RECONSTRUCTIVE"
    case unknownSchema = "UNKNOWN_SCHEMA"          // → fail closed
}

public enum PersistenceLawValidatorV2 {
    public static let revision = "persistence-law-validator-v2"

    /// CLOSED sets assembled from the actual registries/enums — never from runtime strings.
    static let closedCanonical: Set<String> = {
        var s = Set<String>()
        s.formUnion(SemanticTaxonomyV1.conceptForLabel.values)
        s.formUnion(SemanticTaxonomyV1.sceneConcept.values)
        s.formUnion(DurableEntityVocabularyV1.allAtomIDs)
        s.formUnion(ContentIntentV1.allCases.map { $0.rawValue })
        s.formUnion(EmotionalDimensionV1.allCases.map { $0.rawValue })
        s.formUnion(["event:topic-shift", "event:risk-escalation", "event:risk-recovery", "event:scene-return",
                     "event:cta-appearance", "event:contradiction", "event:modality-change", "event:state-change"])
        for o in ["UNRESOLVED", "MODALITY_PRIORITY", "TEMPORAL_REINTERPRETATION", "CONTEXT_QUALIFIED",
                  "STRONG_RISK_DOMINANT", "INSUFFICIENT_EVIDENCE"] { s.insert("contradiction:\(o)") }
        // mesh label canon (fixed literals produced by the experts — never free text)
        s.formUnion(["safety:sensitive-death-disease-news", "safety:fear-threat-candidate",
                     "safety:H1-visual-dimensions:UNAVAILABLE", "safety:no-lexical-signal (NOT a safe verdict)",
                     "benefit:educational-candidate", "benefit:calm-nature-candidate", "benefit:music-presence",
                     "benefit:none-detected",
                     "attention:rapid-edit-density", "attention:urgency-language", "attention:cta-clickbait",
                     "attention:no-pressure-pattern", "pattern:manipulation-language", "pattern:emotional-language",
                     "narrative:risk-escalated", "narrative:recovery-observed (historical risk retained)",
                     "narrative:cta-near-end", "narrative:unresolved-ending"])
        return s
    }()
    /// strict structured grammars: fixed head + NUMERIC tail only (no free text segments)
    static let numericTailHeads = ["narrative:segments:", "narrative:reinterpretations:", "temporal:shots:",
                                   "temporal:narrative-shift:", "audio:unsupported-classes:",
                                   "symbol:warning-candidates:", "symbol:positive-candidates:"]
    static func matchesNumericGrammar(_ s: String) -> Bool {
        for head in numericTailHeads where s.hasPrefix(head) {
            let tail = s.dropFirst(head.count)
            return !tail.isEmpty && tail.allSatisfy { $0.isNumber }
        }
        return false
    }
    /// version-metadata grammar: known version-string shape ([a-z0-9./-] with a digit), no spaces
    static func matchesVersionGrammar(_ s: String) -> Bool {
        !s.isEmpty && s.count <= 64 && s.contains(where: { $0.isNumber })
            && s.allSatisfy { $0.isLowercase || $0.isNumber || "./-".contains($0) }
    }
    /// audit-trail grammar: "revision:<n>:<state>[:<trigger>]@<ms>ms[ by <version>]"
    static func matchesAuditTrailGrammar(_ s: String) -> Bool {
        guard s.hasPrefix("revision:") else { return false }
        let states = ["CANDIDATE", "candidate", "confirmed", "REVISED", "INVALIDATED", "SUPERSEDED"]
        return states.contains(where: { s.contains($0) }) && s.contains("@") && s.contains("ms")
            && !s.contains("  ") && s.count <= 120
    }

    public static func classify(_ value: String, field: String) -> PersistenceFieldClassV1 {
        switch field {
        case "topics":
            return closedCanonical.contains(value) ? .allowedDurableCanonical : .forbiddenRawOrReconstructive
        case "entities":
            return DurableEntityVocabularyV1.allAtomIDs.contains(value) ? .allowedDurableCanonical : .forbiddenRawOrReconstructive
        case "intents", "temporalStructure", "emotionalLoad", "contradictionOutcomes":
            return closedCanonical.contains(value) ? .allowedDurableCanonical : .forbiddenRawOrReconstructive
        case "narrativeSummary", "safetyEvidence", "benefitEvidence", "manipulationEvidence":
            if closedCanonical.contains(value) || matchesNumericGrammar(value) { return .allowedDurableCanonical }
            return .forbiddenRawOrReconstructive
        case "meshModelVersions", "worldModelVersion", "taxonomyVersion":
            return matchesVersionGrammar(value) ? .allowedVersionMetadata : .forbiddenRawOrReconstructive
        case "auditTrail":
            return matchesAuditTrailGrammar(value) ? .allowedVersionMetadata : .forbiddenRawOrReconstructive
        case "revisionState", "knowledgeState", "privacyClass":
            return .allowedVersionMetadata                       // enum raw values (typed at the source)
        default:
            return .unknownSchema                                // fail closed — future fields must be registered
        }
    }
}

// MARK: - §4 — ContentDNAPersistenceAuditorV1: recursive field-by-field inspection of the FINAL durable
// payload. Every string-like value classified; FORBIDDEN or UNKNOWN_SCHEMA anywhere → the DNA may not
// persist. Numeric/bool/enum fields are ALLOWED_DERIVED_NUMERIC by construction.

public enum ContentDNAPersistenceAuditorV1 {
    public static let revision = "content-dna-persistence-auditor-v1"
    public struct ViolationV1: Sendable { public let field: String; public let value: String; public let cls: PersistenceFieldClassV1 }

    /// Known string-array/string fields of FinalContentDNAV1 — the SCHEMA registry. A future field that
    /// appears in the type but not here is reported as UNKNOWN_SCHEMA (fail closed).
    static let stringFields: Set<String> = ["topics", "entities", "intents", "narrativeSummary",
                                            "temporalStructure", "safetyEvidence", "benefitEvidence",
                                            "manipulationEvidence", "emotionalLoad", "contradictionOutcomes",
                                            "meshModelVersions", "auditTrail", "worldModelVersion", "taxonomyVersion"]
    static let numericOrTypedFields: Set<String> = ["dnaID", "itemID", "identityRevision", "dnaRevision",
                                                    "revisionState", "intentAmbiguous", "modalityCoverage",
                                                    "maxRiskSeen", "uncertaintyOverall", "knowledgeState",
                                                    "oodFlags", "provenanceCount", "privacyClass", "freshnessExpiresAtMs"]

    public static func audit(_ dna: FinalContentDNAV1) -> [ViolationV1] {
        var violations: [ViolationV1] = []
        let mirror = Mirror(reflecting: dna)
        for child in mirror.children {
            guard let field = child.label else { continue }
            if numericOrTypedFields.contains(field) { continue }        // typed/numeric by construction
            guard stringFields.contains(field) else {
                violations.append(ViolationV1(field: field, value: "<unregistered-field>", cls: .unknownSchema))
                continue                                                 // fail closed on future fields
            }
            let values: [String]
            if let arr = child.value as? [String] { values = arr }
            else if let s = child.value as? String { values = [s] }
            else { violations.append(ViolationV1(field: field, value: "<non-string-shape>", cls: .unknownSchema)); continue }
            for v in values {
                let cls = PersistenceLawValidatorV2.classify(v, field: field)
                if cls == .forbiddenRawOrReconstructive || cls == .unknownSchema {
                    violations.append(ViolationV1(field: field, value: v, cls: cls))
                }
            }
        }
        return violations
    }
}
