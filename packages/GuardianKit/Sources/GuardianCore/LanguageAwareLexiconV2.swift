import Foundation

// MARK: - P009C-R1 §6 — F-2 fix: language-aware tokenization + exact token/phrase lexicon matching.
// LAWS: Unicode-aware exact token boundaries (NO substring matching); locale partitioning (a locale's
// terms match only text in that locale; unknown locale still uses exact-token rules on both); Turkish
// case handling (dotted/dotless I via tr locale lowercasing); deterministic multiword phrases;
// cross-language canonical bridging happens ONLY via the explicit taxonomy, never inside matching.
// `Lexicons` word lists (P003 lexicon-v1) are UNTOUCHED — this layer changes HOW they match, and a
// VERSIONED supplemental vocabulary adds explicit tokens that previously rode on substring accidents.

public enum LanguageAwareTokenizerV1 {
    public static let revision = "language-aware-tokenizer-v1"
    static func locale(for language: String?) -> Locale {
        Locale(identifier: (language == "tr") ? "tr_TR" : "en_US")
    }
    /// NFC-normalized, locale-lowercased, Unicode letter/number token stream. Apostrophes inside words
    /// (Turkish suffix apostrophes, English contractions) split — both halves are tokens.
    public static func tokens(_ text: String, language: String?) -> [String] {
        let normalized = text.precomposedStringWithCanonicalMapping
            .folding(options: [], locale: nil)
            .lowercased(with: locale(for: language))
        var tokens: [String] = []
        var current = ""
        for ch in normalized {
            if ch.isLetter || ch.isNumber {
                current.append(ch)
            } else if !current.isEmpty {
                tokens.append(current); current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}

public enum LexiconMatcherV2 {
    public static let revision = "lexicon-matcher-v2"
    /// VERSIONED supplemental vocabulary — explicit tokens that lexicon-v1 only matched via substring
    /// accidents ("deadly"⊃"dead", "ölümcül"⊃"ölüm", "kills"≠"killed"). Additive; lexicon-v1 untouched.
    public static let supplementVersion = "lexicon-v1-supplement-r1"
    public static let supplementalMortality: [String: [String]] = [
        "en": ["deadly", "kill", "kills", "deaths"], "tr": ["ölümcül", "ölümler"]
    ]
    /// base inflections of the existing "threat" stem — exact-token matching needs the explicit forms
    public static let supplementalFear: [String: [String]] = [
        "en": ["threaten", "threatens", "threatened"], "tr": ["tehlikeli"]
    ]

    /// Exact token/phrase hit count. Language known → ONLY that locale's terms are consulted
    /// (locale partitioning — the F-2 law). Language unknown → both locales, still exact-token rules.
    public static func hits(_ text: String, lexicon: [String: [String]], language: String?,
                            supplement: [String: [String]]? = nil) -> Int {
        let langs: [String] = language.map { l in ["tr", "en"].contains(l) ? [l] : [] } ?? ["en", "tr"]
        guard !langs.isEmpty else { return 0 }                  // unsupported locale → no lexical claims
        var count = 0
        for l in langs {
            let toks = LanguageAwareTokenizerV1.tokens(text, language: l)
            let tokenSet = Set(toks)
            var terms = lexicon[l] ?? []
            if let sup = supplement?[l] { terms += sup }
            for term in terms {
                let termTokens = LanguageAwareTokenizerV1.tokens(term, language: l)
                if termTokens.count == 1 {
                    if tokenSet.contains(termTokens[0]) { count += 1 }
                } else if !termTokens.isEmpty {
                    // deterministic multiword phrase: contiguous token subsequence
                    if containsPhrase(toks, termTokens) { count += 1 }
                }
            }
        }
        return count
    }
    static func containsPhrase(_ tokens: [String], _ phrase: [String]) -> Bool {
        guard tokens.count >= phrase.count, !phrase.isEmpty else { return false }
        for start in 0...(tokens.count - phrase.count) {
            var ok = true
            for (i, p) in phrase.enumerated() where tokens[start + i] != p { ok = false; break }
            if ok { return true }
        }
        return false
    }
    /// token presence helper for cue lists (context tags etc.)
    public static func containsToken(_ text: String, anyOf cues: [String], language: String?) -> Bool {
        let toks = LanguageAwareTokenizerV1.tokens(text, language: language)
        let set = Set(toks)
        for cue in cues {
            let cueTokens = LanguageAwareTokenizerV1.tokens(cue, language: language)
            if cueTokens.count == 1 { if set.contains(cueTokens[0]) { return true } }
            else if containsPhrase(toks, cueTokens) { return true }
        }
        return false
    }
}
