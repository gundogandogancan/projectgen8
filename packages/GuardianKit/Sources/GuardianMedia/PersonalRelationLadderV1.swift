//
//  PersonalRelationLadderV1.swift — R3 §3: PERSONAL SEMANTIC RELATION LADDER V1 (honest classification of what a
//  personal-shield match REALLY is today). The extra personalization layer (§3 "EKSTRA"), kept STRICTLY SEPARATE from
//  the general wellbeing intelligence (§1) — a personal match is a user AVOIDANCE PREFERENCE signal, never a wellbeing
//  harm verdict (mandate §3/§5), and never a general harmfulness claim about a person, team, brand, or view.
//
//  WHY THIS EXISTS (mandate §3): the mandate names a relation vocabulary — DIRECT_REFERENCE / VERIFIED_ENTITY_RELATION
//  / VISUAL_SIMILARITY / TOPICAL_RELATION / CONTEXTUAL_ASSOCIATION / WEAK_ASSOCIATION / UNKNOWN — so the user can see
//  WHY a match fired and so "rastgele çağrışım gerçek eşleşme sayılmayacak" (a random association is never a real
//  match). TODAY GEN8 has NO running entity/symbol/semantic-relation model on the cross-app path; the honest thing is
//  to classify each EXISTING match path as exactly the rung it truly is, and to declare the higher rungs UNAVAILABLE.
//
//  THE HONEST MAPPING (what each path REALLY is today — nothing aspirational):
//   • A word/phrase RULE OCR text hit (ShieldEvaluatorV2 exact/alias text match)      → DIRECT_REFERENCE (text)
//   • A photo EXACT/HIGH perceptual match (PhotoShieldLumaMatcherV1 actionable)        → DIRECT_REFERENCE (visual)
//   • A photo MEDIUM perceptual match (any-match but not actionable)                   → VISUAL_SIMILARITY
//   • Anything else (LOW, non-determinable, co-occurrence, topical guess)              → UNKNOWN
//
//  THE V1 ACTIONABILITY LAW: ONLY `DIRECT_REFERENCE` is actionable in V1. VISUAL_SIMILARITY is a declared-but-NOT-
//  actionable rung (a MEDIUM photo match is surfaced as evidence, never a decision). The rungs above DIRECT_REFERENCE
//  (VERIFIED_ENTITY_RELATION / TOPICAL_RELATION / CONTEXTUAL_ASSOCIATION / WEAK_ASSOCIATION) are UNAVAILABLE because no
//  verified entity/symbol/topic model runs on this path yet — honest, not faked. Co-occurrence ALONE can never produce
//  a match (there is no path that mints one), and UNKNOWN never actions.
//
//  Pure + headless + Codable. Lives in GuardianMedia (GuardianCore frozen). The relation type is carried into the
//  timeline / İçerik Kanıtı provenance so the user sees the rung behind every personal match.
//
import Foundation
import GuardianCore

/// R3 §3 — the personal semantic relation ladder. Higher rungs mean a STRONGER, more-verified link to the user's
/// avoidance preference. Only `directReference` is actionable in V1; `visualSimilarity` is declared but not actionable;
/// the middle rungs are UNAVAILABLE (no running model); `unknown` is the honest floor.
public enum PersonalRelationTypeV1: String, Sendable, Equatable, Codable, CaseIterable {
    case directReference        = "DIRECT_REFERENCE"          // the exact term / the exact-or-near-exact image
    case verifiedEntityRelation = "VERIFIED_ENTITY_RELATION"  // UNAVAILABLE V1 — no verified entity model on this path
    case visualSimilarity       = "VISUAL_SIMILARITY"         // a MEDIUM perceptual match — evidence, NOT actionable
    case topicalRelation        = "TOPICAL_RELATION"          // UNAVAILABLE V1 — no topic-relation model
    case contextualAssociation  = "CONTEXTUAL_ASSOCIATION"    // UNAVAILABLE V1 — co-occurrence is NOT a match
    case weakAssociation        = "WEAK_ASSOCIATION"          // UNAVAILABLE V1
    case unknown                = "UNKNOWN"                   // honest floor — never actions

    /// R3 §3 — V1 actionability. ONLY a DIRECT_REFERENCE may drive a personal-shield decision. Everything else is
    /// evidence-only or declared unavailable; UNKNOWN and VISUAL_SIMILARITY never action (mandate §3 tests).
    public var isActionableV1: Bool { self == .directReference }

    /// R3 §3 — whether the rung EXISTS on the cross-app path today. The middle rungs have no running model → they are
    /// honestly UNAVAILABLE (the ladder is declared in full so the vocabulary is stable, but V1 cannot produce them).
    public var isAvailableV1: Bool {
        switch self {
        case .directReference, .visualSimilarity, .unknown: return true
        case .verifiedEntityRelation, .topicalRelation, .contextualAssociation, .weakAssociation: return false
        }
    }

    /// Short Turkish provenance phrase for İçerik Kanıtı — says exactly WHY, never a harm claim about the subject.
    public var turkishProvenance: String {
        switch self {
        case .directReference:        return "Doğrudan referans: tam ifade ya da (neredeyse) aynı görsel eşleşti."
        case .visualSimilarity:       return "Görsel benzerlik: yalnızca benziyor; bu bir karar değil, kanıt işareti."
        case .verifiedEntityRelation: return "Doğrulanmış varlık ilişkisi: bu sürümde mevcut değil."
        case .topicalRelation:        return "Konusal ilişki: bu sürümde mevcut değil."
        case .contextualAssociation:  return "Bağlamsal çağrışım: bu sürümde mevcut değil (birlikte geçme eşleşme değildir)."
        case .weakAssociation:        return "Zayıf çağrışım: bu sürümde mevcut değil."
        case .unknown:                return "İlişki türü belirlenemedi."
        }
    }
}

/// R3 §3 — the classified relation for ONE personal-match signal, carried into provenance. Personal ONLY — this struct
/// carries no wellbeing-harm field by design (the two families never mix; mandate §3/§5).
public struct PersonalRelationClassificationV1: Sendable, Equatable, Codable {
    public let relation: PersonalRelationTypeV1
    /// Is this classification ACTIONABLE under the V1 law (true only for an available DIRECT_REFERENCE)?
    public let actionable: Bool
    /// The evidence modality the rung came from (TEXT / VISUAL / NONE) — provenance, never a content claim.
    public let modalityRaw: String

    public init(relation: PersonalRelationTypeV1, modalityRaw: String) {
        self.relation = relation
        self.actionable = relation.isActionableV1 && relation.isAvailableV1
        self.modalityRaw = modalityRaw
    }
}

public enum PersonalRelationLadderV1 {
    /// R3 §3 — classify a TEXT personal-shield outcome (ShieldEvaluatorV2). An exact/alias/source text match against
    /// the user's OWN rule is a DIRECT_REFERENCE (the exact term the user named). A non-determinable or no-match state
    /// is UNKNOWN. Semantic/low-confidence matches are NOT promoted above DIRECT_REFERENCE — there is no verified
    /// entity model, so a "semantic" hit is still just a lexical reference and is classified DIRECT_REFERENCE only
    /// when the evaluator itself resolved it to an actionable match; otherwise UNKNOWN (never a faked higher rung).
    public static func classifyText(matchState: ShieldMatchState, isActionableShieldHit: Bool)
        -> PersonalRelationClassificationV1 {
        // Only a real, determinable shield hit the evaluator ACTED on is a DIRECT_REFERENCE. Everything else
        // (non-determinable, no-match, or a match the layer decided not to act on) is UNKNOWN — never an upper rung.
        if isActionableShieldHit && matchState.isMatch {
            return PersonalRelationClassificationV1(relation: .directReference, modalityRaw: "TEXT")
        }
        return PersonalRelationClassificationV1(relation: .unknown, modalityRaw: matchState.isMatch ? "TEXT" : "NONE")
    }

    /// R3 §3 — classify a VISUAL personal-shield match (PhotoShieldLumaMatcherV1 live match). EXACT/HIGH (actionable)
    /// = DIRECT_REFERENCE (visual): the user's exact-or-near-exact image. MEDIUM (any-match, not actionable) =
    /// VISUAL_SIMILARITY: declared, evidence-only, NEVER actioned. LOW / non-determinable = UNKNOWN. Perceptual
    /// similarity is explicitly NOT a VERIFIED_ENTITY_RELATION — a look-alike is not a confirmed same entity (§4).
    public static func classifyPhoto(_ state: ShieldMatchState) -> PersonalRelationClassificationV1 {
        switch state {
        case .matchExact, .matchHigh:
            return PersonalRelationClassificationV1(relation: .directReference, modalityRaw: "VISUAL")
        case .matchMedium:
            return PersonalRelationClassificationV1(relation: .visualSimilarity, modalityRaw: "VISUAL")
        case .matchLow:
            return PersonalRelationClassificationV1(relation: .unknown, modalityRaw: "VISUAL")
        case .noMatch, .matchabilityUnknown, .matcherUnavailable, .evidenceConflict:
            return PersonalRelationClassificationV1(relation: .unknown, modalityRaw: "NONE")
        }
    }

    /// R3 §3 — classify a live photo match value (convenience over `classifyPhoto`).
    public static func classify(_ match: PhotoShieldLiveMatchV1) -> PersonalRelationClassificationV1 {
        classifyPhoto(match.state)
    }
}
