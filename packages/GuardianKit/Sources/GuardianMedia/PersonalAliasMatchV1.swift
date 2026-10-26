//
//  PersonalAliasMatchV1.swift — R7 §5: SEMANTIC ENTITY & ALIAS V1 (narrow, honest).
//
//  WHAT THIS IS (mandate §5.3 — the first real applicable slice): a user-defined text reference that carries
//  USER-PROVIDED aliases (alternative names the USER typed — e.g. a public figure's name + a nickname the user
//  entered). A match is an EXPLICIT DIRECT MENTION of the canonical name OR one of the user-provided aliases, by
//  WORD BOUNDARY, case/locale-insensitive for TR+EN. The match carries provenance showing WHICH alias fired, and is
//  classified as a DIRECT_REFERENCE (the ladder's actionable rung — the exact term the USER named). This is the
//  user's AVOIDANCE PREFERENCE, never a harm verdict about the referenced person/entity.
//
//  WHAT THIS IS NOT (the honesty laws, mandate §5.1/§5.2):
//   • NO automatic alias discovery — only aliases the user explicitly typed are matched.
//   • NO different-photo person recognition — a look-alike is NOT a match (that stays UNAVAILABLE on this path).
//   • NO co-occurrence / topical matching — "same meeting", "same country", "same topic" are NOT a match.
//   • NO hidden identity/intent inference from political/religious/ethnic association.
//   • Semantic similarity ≠ verified identity; co-occurrence ≠ relevance; personal avoidance ≠ universal harm.
//
//  WHY A WORD-BOUNDARY MATCHER HERE (field side): the FROZEN AliasEntityMatcher uses raw `contains` (substring), so
//  a short alias could falsely match inside an unrelated word ("ali" inside "kalitesi"). This pure GuardianMedia
//  type is the HONEST narrow capability: word-boundary matching (so a direct mention is a real mention), locale-
//  insensitive for TR+EN, with explicit AMBIGUITY handling — a too-short or common-word alias is WARNED at entry
//  (and never silently actioned). Delete/revoke is handled by the store (orphan features/aliases pruned on save);
//  this type exposes a pure `revoked` helper so a revoked reference matches NOTHING.
//
//  Pure + headless + Codable. Lives in GuardianMedia (GuardianCore frozen). The match result feeds the
//  PersonalRelationLadderV1 DIRECT_REFERENCE classification with the matched-alias provenance.
//
import Foundation

/// R7 §5 — a user-defined reference: a canonical name + the user's explicitly-typed aliases. NO auto-discovery.
public struct PersonalAliasReferenceV1: Sendable, Equatable, Codable {
    /// The rule this reference belongs to (provenance; deleting the rule revokes all its aliases).
    public let ruleID: String
    /// The canonical name the user named (e.g. the full name). Matched by word boundary like the aliases.
    public let canonicalName: String
    /// The user-provided alternative names (nicknames, short forms the USER typed). NO auto-discovery.
    public let aliases: [String]
    /// True when the reference has been revoked (rule deleted) — it then matches NOTHING (fail-safe).
    public let revoked: Bool

    public init(ruleID: String, canonicalName: String, aliases: [String], revoked: Bool = false) {
        self.ruleID = ruleID; self.canonicalName = canonicalName; self.aliases = aliases; self.revoked = revoked
    }

    /// All match terms (canonical + aliases), non-empty, trimmed.
    public var allTerms: [String] {
        ([canonicalName] + aliases).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

/// R7 §5 — the honest outcome of an alias match. `matchedTerm` is WHICH canonical/alias string fired (provenance);
/// `isCanonical` distinguishes a canonical-name hit from an alias hit. A non-match carries no term.
public struct PersonalAliasMatchResultV1: Sendable, Equatable, Codable {
    public let ruleID: String
    public let matched: Bool
    /// The exact user-provided string that matched (canonical or alias) — provenance, never content outside it.
    public let matchedTerm: String?
    public let isCanonical: Bool
    public init(ruleID: String, matched: Bool, matchedTerm: String?, isCanonical: Bool) {
        self.ruleID = ruleID; self.matched = matched; self.matchedTerm = matchedTerm; self.isCanonical = isCanonical
    }
    public static func noMatch(_ ruleID: String) -> PersonalAliasMatchResultV1 {
        PersonalAliasMatchResultV1(ruleID: ruleID, matched: false, matchedTerm: nil, isCanonical: false)
    }
}

/// R7 §5 — an ambiguity warning raised at ENTRY time (never silently actioned). The user can keep the term anyway,
/// but the UI must show the warning so a common/short alias does not produce false mentions.
public enum PersonalAliasAmbiguityV1: String, Sendable, Equatable, Codable {
    case ok               = "OK"               // safe to use as a direct-mention term
    case tooShort         = "TOO_SHORT"        // below the minimum length → high false-mention risk
    case commonWord       = "COMMON_WORD"      // a common TR/EN word → high false-mention risk
}

public enum PersonalAliasMatchV1 {
    public static let version = "personal-alias-match-v1"
    /// R7 §5 — minimum alias length to be safe without a warning (shorter → TOO_SHORT ambiguity). A name like "AKP"
    /// (3) is allowed; a 2-char token is too collision-prone to be a reliable direct mention.
    public static let minSafeAliasLength = 3

    /// A tiny, explicit list of common TR/EN function words that make terrible direct-mention aliases (collision
    /// risk). NOT a political/ideological list — purely high-frequency function words. Extended only with evidence.
    static let commonWords: Set<String> = [
        // TR
        "ve", "ile", "bir", "bu", "şu", "o", "için", "ama", "çok", "daha", "en", "gibi", "de", "da", "ki", "mi",
        // EN
        "the", "and", "a", "an", "is", "of", "to", "in", "on", "for", "but", "or", "as", "at", "by", "it", "he", "she"]

    /// R7 §5 — ENTRY-TIME ambiguity check for a single alias/term. Locale-insensitive. Returns OK / TOO_SHORT /
    /// COMMON_WORD so the UI can WARN (mandate: ambiguity handled honestly, warn at entry or require min length).
    public static func ambiguity(of term: String) -> PersonalAliasAmbiguityV1 {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let folded = fold(t)
        // A common function word is a COMMON_WORD warning regardless of length (checked first so "ve"/"the" report
        // the more specific collision reason rather than merely TOO_SHORT).
        if commonWords.contains(folded) { return .commonWord }
        if folded.count < minSafeAliasLength { return .tooShort }
        return .ok
    }

    /// R7 §5 — the WORD-BOUNDARY alias match. Finds the FIRST canonical/alias term that appears in `text` as a
    /// whole word (locale-insensitive, TR+EN). A revoked reference matches NOTHING. Multi-word terms match as a
    /// contiguous word sequence. NO substring-inside-a-word match (that is the frozen matcher's weakness this fixes).
    public static func match(reference ref: PersonalAliasReferenceV1, in text: String?) -> PersonalAliasMatchResultV1 {
        guard !ref.revoked, let raw = text, !raw.isEmpty else { return .noMatch(ref.ruleID) }
        let hayTokens = tokens(raw)
        guard !hayTokens.isEmpty else { return .noMatch(ref.ruleID) }
        let canonicalFolded = fold(ref.canonicalName)
        for term in ref.allTerms {
            let termTokens = tokens(term)
            guard !termTokens.isEmpty else { continue }
            if containsSequence(hayTokens, termTokens) {
                return PersonalAliasMatchResultV1(ruleID: ref.ruleID, matched: true, matchedTerm: term,
                                                  isCanonical: fold(term) == canonicalFolded)
            }
        }
        return .noMatch(ref.ruleID)
    }

    // MARK: - internals

    /// Diacritic+case folding with TR awareness. Turkish has a dotted/dotless i distinction ("ı" vs "i", "İ" vs "I")
    /// that plain diacritic-folding does NOT collapse; users type names both ways (OCR also varies), so we normalize
    /// the dotless/dotted i pair to a single canonical "i" FIRST, then diacritic+case fold. This keeps a direct
    /// mention a reliable match across the two spellings without widening into unrelated letters.
    static func fold(_ s: String) -> String {
        let iNormalized = s
            .replacingOccurrences(of: "ı", with: "i").replacingOccurrences(of: "İ", with: "i")
            .replacingOccurrences(of: "I", with: "i")
        return iNormalized.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Word tokens (alphanumeric runs), folded. Word-boundary matching = token-sequence containment, so a term can
    /// never match inside a longer word.
    static func tokens(_ s: String) -> [String] {
        fold(s).components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    /// Does `hay` contain `needle` as a contiguous subsequence of whole tokens?
    static func containsSequence(_ hay: [String], _ needle: [String]) -> Bool {
        guard needle.count <= hay.count, !needle.isEmpty else { return false }
        for start in 0...(hay.count - needle.count) {
            var ok = true
            for i in 0..<needle.count where hay[start + i] != needle[i] { ok = false; break }
            if ok { return true }
        }
        return false
    }
}

// MARK: - R7 §5 — ladder bridge: an alias/canonical direct mention is a DIRECT_REFERENCE with alias provenance.

extension PersonalRelationLadderV1 {
    /// R7 §5 — classify a user-provided alias/canonical DIRECT MENTION. A real word-boundary mention of a term the
    /// USER named is a DIRECT_REFERENCE (text) — the actionable rung. A non-match is UNKNOWN. The matched term is
    /// carried as provenance by the caller (the ladder classification itself stays content-free per §3/§5).
    public static func classifyAliasMatch(_ result: PersonalAliasMatchResultV1) -> PersonalRelationClassificationV1 {
        if result.matched {
            return PersonalRelationClassificationV1(relation: .directReference, modalityRaw: "TEXT")
        }
        return PersonalRelationClassificationV1(relation: .unknown, modalityRaw: "NONE")
    }
}
