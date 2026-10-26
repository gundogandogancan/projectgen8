//
//  ContextEvidenceAdapterV1.swift — R4 §3/§4: the FIRST REAL CONTEXTUAL SEPARATION (stance, not just words).
//
//  WHY THIS EXISTS (mandate §1 — the binding engineering rule): R3 proved that catching a WORD ("ölüm", "savaş",
//  "death") is NOT the same as understanding the CONTENT. A death-NEWS text and a violence-GLORIFYING text both trip
//  the same mortality lexicon marker; "we are AGAINST violence" and "do violence" both contain the violence word.
//  The R3 §8 corpus measured 5 inseparable context families. A NEW WORD LIST does not fix this (§1). Real context
//  inference must read linguistic STRUCTURE: negation scope, quotation / reported speech, and subject-action-object
//  roles (first-person advocacy vs third-person reporting).
//
//  WHAT THIS DOES (V1 scope — ONE capability, done REAL): given a marker-bearing text in a SUPPORTED language
//  (Turkish or English) it infers the SPEAKER'S STANCE toward the violence/harm the marker flagged, as EVIDENCE-
//  SOURCED fields — each class comes with the exact linguistic evidence cues that produced it. The output classes:
//    • ADVOCATES        — the speaker promotes/endorses the harm (first-person advocacy: imperative/optative
//                         "yapın/yapalım/öldürün/hak etti", EN "we should/let's/they deserve/kill them"). KEEP/RAISE.
//    • REPORTS          — the content merely reports an event (reporting verbs "yaşandı/bildirildi/açıklandı/oldu",
//                         EN "reported/was killed/happened/police said"). May SOFTEN to an examined-with-context note.
//    • CRITICIZES       — the speaker opposes/condemns the harm (explicit anti-stance "karşıyız/kınıyoruz/condemn/
//                         against", or NEGATION over the harm clause "şiddet değil/no violence"). May SOFTEN.
//    • SUPPORTS_VICTIMS — the content stands with victims ("mağdurların yanındayız", EN "support the victims").
//    • UNKNOWN          — structure does not disambiguate (sarcasm/irony, mixed signals) → the plain marker is KEPT.
//
//  HARD HONESTY LAWS (mandate §1/§3/§4):
//    • A QUOTED statement is NOT the speaker's stance. "O 'şiddet iyidir' dedi" quotes advocacy but the SPEAKER is
//      reporting — the adapter returns REPORTS with quotation evidence, never ADVOCATES.
//    • NEGATION operates on CLAUSE SCOPE, not bag-of-words: "şiddete karşıyız" (we are against violence) is CRITICIZES
//      even though it contains "şiddet".
//    • Sarcasm / irony is NOT detectable from structure → UNKNOWN BY DESIGN (we never guess intent we cannot read).
//    • UNKNOWN never softens a real risk signal: an UNKNOWN stance KEEPS the plain CAUTION marker (R3 fallback intact).
//    • Unsupported dimension stays UNKNOWN. An unsupported language → notApplicable (the R3 marker path is unchanged).
//    • This is NOT sentiment analysis. A negative SENTIMENT ("this is horrible") is not an advocacy/criticism STANCE.
//    • NO numeric 0–100 score — the output is categorical + evidence cues (calibration gate closed, §9).
//
//  THE LINGUISTIC BACKBONE: Apple NaturalLanguage (NLTagger `.lexicalClass` for POS — on-device, public API, tiny
//  budget — the SAME framework GuardianIntelligence.NLTextSignalProvider already uses). POS tags help the role check
//  (verb detection for imperative/reporting). Everything else (negation scope, quotation, anti-stance) is explicit
//  structural rule logic over sentence-split clauses + token streams. We NEVER claim POS = stance.
//
//  TOKENIZATION: mirrors GuardianCore `LanguageAwareTokenizerV1` (letter/number tokens, Turkish-locale lowercasing,
//  NFC fold) so cue matching behaves identically to the lexicon layer. Kept LOCAL (GuardianMedia) so this type stays
//  self-contained and testable; it calls no frozen mutable state.
//
//  PURE + headless + versioned + testable. Lives in GuardianMedia (GuardianCore frozen). Dual-compiled app+extension.
//
import Foundation
import NaturalLanguage

/// R4 §4 — the inferred SPEAKER STANCE toward the flagged harm. Categorical; UNKNOWN is a first-class, honest state.
public enum GuardianStanceV1: String, Sendable, Equatable, Codable, CaseIterable {
    case advocates       = "ADVOCATES"        // first-person promotion/endorsement of the harm → keep/raise caution
    case reports         = "REPORTS"          // third-person reporting of an event → may soften to examined-with-context
    case criticizes      = "CRITICIZES"       // explicit opposition / negation over the harm clause → may soften
    case supportsVictims = "SUPPORTS_VICTIMS" // stands with victims → may soften
    case unknown         = "UNKNOWN"          // structure does not disambiguate (incl. sarcasm) → keep the plain marker
}

/// R4 §3 — whether the adapter actually RAN for this content (supported-class flag, mandate §3 contract). A stance of
/// `.unknown` with `support == .supported` is a REAL "we looked and could not tell"; `.notApplicable` means we never
/// had the capability (unsupported language / no text) — a different, honest state that must NOT soften anything.
public enum GuardianContextSupportV1: String, Sendable, Equatable, Codable {
    case supported        = "SUPPORTED"          // language supported + text present → the stance inference ran
    case notApplicable    = "NOT_APPLICABLE"     // unsupported language / empty text → adapter did not run
}

/// R4 §4 — the effect the stance evidence has on the general caution surface. Explicit so the wiring is auditable and
/// the "never silently drop a real risk" law (§4) is a VALUE, not a comment.
public enum GuardianStanceEffectV1: String, Sendable, Equatable, Codable {
    case keepOrRaise   = "KEEP_OR_RAISE"   // ADVOCATES → the plain caution is kept (and conceptually raised)
    case softenToNote  = "SOFTEN_TO_NOTE"  // REPORTS / CRITICIZES / SUPPORTS_VICTIMS → examined-WITH-context note
    case keepPlain     = "KEEP_PLAIN"      // UNKNOWN / notApplicable → the R3 plain marker is kept unchanged
}

/// R4 §3 — the evidence-sourced context verdict. Every field is bound to content identity + the evidence that
/// produced it + a supported-class flag. NO raw text leaves this struct (privacy): only derived STRUCTURAL cues the
/// adapter itself matched (short, lower-cased — never the full OCR line).
public struct ContextEvidenceVerdictV1: Sendable, Equatable, Codable {
    /// The STANCE dimension (the ONE capability this V1 supports). UNKNOWN when structure does not disambiguate.
    public let stance: GuardianStanceV1
    /// Did the adapter have the capability to run (supported language + text)? A stance only applies when SUPPORTED.
    public let support: GuardianContextSupportV1
    /// The effect on the caution surface (keep/raise vs soften vs keep-plain). Derived ONCE, here.
    public let effect: GuardianStanceEffectV1
    /// The exact structural evidence cues that drove the stance (e.g. "negation:karşı", "quote:dedi", "role:imperative").
    /// Privacy-safe: the adapter's OWN matched cues, never the raw OCR content. Empty for notApplicable.
    public let evidence: [String]
    /// The detected language the stance ran under (provenance). "und"/unsupported → notApplicable.
    public let languageRaw: String
    // --- Independent provenance (stamped by the caller; mirrors the general-character verdict) ---
    public let itemIdentityRevision: Int
    public let policyRevision: UInt64
    public let eventEpoch: Double
    /// The adapter version that produced this (audit).
    public let adapterVersion: String

    public init(stance: GuardianStanceV1, support: GuardianContextSupportV1, effect: GuardianStanceEffectV1,
                evidence: [String], languageRaw: String, itemIdentityRevision: Int, policyRevision: UInt64,
                eventEpoch: Double, adapterVersion: String) {
        self.stance = stance; self.support = support; self.effect = effect; self.evidence = evidence
        self.languageRaw = languageRaw; self.itemIdentityRevision = itemIdentityRevision
        self.policyRevision = policyRevision; self.eventEpoch = eventEpoch; self.adapterVersion = adapterVersion
    }

    /// True iff the adapter ran AND produced a stance that justifies softening the plain caution to a with-context note.
    public var softens: Bool { support == .supported && effect == .softenToNote }
}

public enum ContextEvidenceAdapterV1 {
    public static let version = "context-evidence-adapter-v1"

    /// R4 §3 — the SUPPORTED languages for the V1 stance capability. Anything else → notApplicable (UNKNOWN never
    /// becomes a stance; the R3 marker path is unchanged). We check the language PREFIX so "en-US" etc. still match.
    public static let supportedLanguagePrefixes: Set<String> = ["tr", "en"]

    public static func isSupported(language: String?) -> Bool {
        guard let l = language?.lowercased(), let head = l.split(whereSeparator: { $0 == "-" || $0 == "_" }).first else {
            return false
        }
        return supportedLanguagePrefixes.contains(String(head))
    }

    // MARK: - Public entry

    /// R4 §4 — infer the SPEAKER STANCE toward the flagged harm from the text's LINGUISTIC STRUCTURE. Pure: the same
    /// inputs always produce the same verdict. Intended to be called ONLY when the general-character pass already
    /// found a marker AND the language is supported — so a stance is only produced for content with a real risk signal.
    public static func assessStance(text: String?, language: String?,
                                    itemIdentityRevision: Int, policyRevision: UInt64,
                                    nowEpoch: Double) -> ContextEvidenceVerdictV1 {
        // A single construction point so provenance is stamped once (no globals, no fatalError placeholder).
        func make(_ s: GuardianStanceV1, _ e: GuardianStanceEffectV1, _ support: GuardianContextSupportV1,
                  _ evidence: [String], _ langRaw: String) -> ContextEvidenceVerdictV1 {
            ContextEvidenceVerdictV1(stance: s, support: support, effect: e, evidence: evidence, languageRaw: langRaw,
                                     itemIdentityRevision: itemIdentityRevision, policyRevision: policyRevision,
                                     eventEpoch: nowEpoch, adapterVersion: version)
        }

        let langRaw = (language?.isEmpty == false ? language! : "und")
        guard isSupported(language: language) else { return make(.unknown, .keepPlain, .notApplicable, [], langRaw) }
        guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), raw.count >= 3 else {
            return make(.unknown, .keepPlain, .notApplicable, [], langRaw)
        }
        let isTR = String(langRaw.lowercased().prefix(2)) == "tr"

        // Structural detectors (each returns a hit flag + the exact evidence cues it matched).
        let quotation = detectQuotation(raw, isTR: isTR)       // reported-speech frame / quote marks
        let antiStance = detectAntiStance(raw, isTR: isTR)     // speaker-level opposition ("kınıyoruz/condemn")
        let victim = detectVictimSupport(raw, isTR: isTR)      // standing WITH victims
        let negation = detectHarmNegation(raw, isTR: isTR)     // clause-scoped negation over the harm ("değil/no/not")
        let role = detectAdvocacyVsReporting(raw, isTR: isTR)  // first-person advocacy vs third-person reporting (POS)

        // --- COMBINE (explicit precedence; each branch records the exact evidence) --------------------------------
        // An EXPLICIT speaker anti-stance / victim support is the strongest, OWN-voice stance signal even when a
        // harmful quote is present. Advocacy (first-person promotion) outranks a bare reporting frame. A reporting
        // frame / quotation with no advocacy and no opposition → REPORTS. Anything genuinely ambiguous → UNKNOWN.

        // Mixed hard signals (both advocacy AND opposition present in the SAME text) → cannot tell → UNKNOWN by design.
        if role.advocacy && (antiStance.hit || negation.hit) {
            return make(.unknown, .keepPlain, .supported,
                        role.evidence + antiStance.evidence + negation.evidence + ["ambiguous:advocacy+opposition"], langRaw)
        }
        if antiStance.hit {
            return make(.criticizes, .softenToNote, .supported, antiStance.evidence + quotation.evidence, langRaw)
        }
        if victim.hit {
            return make(.supportsVictims, .softenToNote, .supported, victim.evidence, langRaw)
        }
        if negation.hit {
            return make(.criticizes, .softenToNote, .supported, negation.evidence + quotation.evidence, langRaw)
        }
        if role.advocacy {
            // First-person advocacy is the speaker's OWN voice — UNLESS the advocacy sits inside a quote WITH a
            // reporting frame (then the speaker is reporting someone else's advocacy). Mixed signals handled above.
            if role.advocacyInsideQuote && quotation.hit {
                return make(.reports, .softenToNote, .supported, quotation.evidence + role.evidence + ["advocacy-quoted"], langRaw)
            }
            return make(.advocates, .keepOrRaise, .supported, role.evidence, langRaw)
        }
        if role.reporting || quotation.hit {
            return make(.reports, .softenToNote, .supported, role.evidence + quotation.evidence, langRaw)
        }
        // Supported, but structure does not disambiguate (bare topic mention, possible sarcasm) → UNKNOWN, keep the
        // plain marker. The HONEST "we looked and cannot tell" — never a softening.
        return make(.unknown, .keepPlain, .supported, ["no-decisive-structure"], langRaw)
    }

    // MARK: - Tokenization (mirrors GuardianCore LanguageAwareTokenizerV1)

    static func tokens(_ text: String, isTR: Bool) -> [String] {
        let locale = Locale(identifier: isTR ? "tr_TR" : "en_US")
        let normalized = text.precomposedStringWithCanonicalMapping.folding(options: [], locale: nil)
            .lowercased(with: locale)
        var toks: [String] = []; var cur = ""
        for ch in normalized {
            if ch.isLetter || ch.isNumber { cur.append(ch) }
            else if !cur.isEmpty { toks.append(cur); cur = "" }
        }
        if !cur.isEmpty { toks.append(cur) }
        return toks
    }

    /// Does the token stream contain this contiguous phrase (1+ tokens, exact order)?
    private static func containsPhrase(_ toks: [String], _ phrase: [String]) -> Bool {
        guard !phrase.isEmpty, toks.count >= phrase.count else { return false }
        for start in 0...(toks.count - phrase.count) {
            var ok = true
            for (i, p) in phrase.enumerated() where toks[start + i] != p { ok = false; break }
            if ok { return true }
        }
        return false
    }

    /// Match any cue (single token or contiguous phrase) against the token stream; return the FIRST matched cue.
    private static func firstCue(in toks: [String], anyOf cues: [String], isTR: Bool) -> String? {
        for cue in cues {
            let ct = tokens(cue, isTR: isTR)
            if ct.count == 1 ? toks.contains(ct[0]) : containsPhrase(toks, ct) { return cue }
        }
        return nil
    }

    private struct Detection { let hit: Bool; let evidence: [String] }

    // MARK: - (a) Quotation / reported speech

    /// Quote marks OR a reporting frame ("dedi/said/açıkladı/claims/according to"). Returns the cues matched. Quote
    /// marks are character-based (language-neutral); reporting frames are token/phrase-based.
    private static func detectQuotation(_ raw: String, isTR: Bool) -> Detection {
        var ev: [String] = []
        let quoteChars: Set<Character> = ["\"", "“", "”", "«", "»", "'", "‘", "’"]
        if raw.contains(where: { quoteChars.contains($0) }) { ev.append("quote:marks") }
        let toks = tokens(raw, isTR: isTR)
        let frames = isTR
            ? ["dedi", "dedi ki", "söyledi", "açıkladı", "bildirdi", "iddia etti", "göre", "ifade etti", "aktardı"]
            : ["said", "says", "claimed", "claims", "according to", "reported", "told reporters", "stated"]
        if let c = firstCue(in: toks, anyOf: frames, isTR: isTR) { ev.append("quote:\(tokens(c, isTR: isTR).joined(separator: "_"))") }
        return Detection(hit: !ev.isEmpty, evidence: ev)
    }

    // MARK: - (b) Explicit anti-stance (speaker-level opposition / condemnation)

    private static func detectAntiStance(_ raw: String, isTR: Bool) -> Detection {
        let toks = tokens(raw, isTR: isTR)
        // These are STANCE cues (the speaker opposes), not topic words. "karşı/karşıyız/karşıyım" = against;
        // "kınıyoruz/kınıyorum/kınarım" = condemn; "durdurun/durduralım/son verin" = stop it; "hayır" to it.
        let tr = ["karşı", "karşıyız", "karşıyım", "karşıdır", "kınıyoruz", "kınıyorum", "kınarız", "kınarım",
                  "kınadı", "lanetliyoruz", "reddediyoruz", "durdurun", "durduralım", "son verin", "son verelim",
                  "kabul edilemez", "yanlıştır", "utanç", "protesto"]
        let en = ["against", "oppose", "opposed", "condemn", "condemned", "condemns", "denounce", "denounced",
                  "reject", "rejected", "stop the", "no to", "unacceptable", "must end", "shameful", "protest"]
        if let c = firstCue(in: toks, anyOf: isTR ? tr : en, isTR: isTR) {
            return Detection(hit: true, evidence: ["antistance:\(tokens(c, isTR: isTR).joined(separator: "_"))"])
        }
        return Detection(hit: false, evidence: [])
    }

    // MARK: - (c) Victim support (standing WITH victims)

    private static func detectVictimSupport(_ raw: String, isTR: Bool) -> Detection {
        let toks = tokens(raw, isTR: isTR)
        let tr = ["mağdurların yanındayız", "yanındayız", "destek olalım", "dayanışma", "başınız sağolsun",
                  "taziye", "geçmiş olsun", "yaraları saralım", "mağdurlara destek"]
        let en = ["support the victims", "stand with", "solidarity", "our thoughts are with", "condolences",
                  "we support survivors", "support survivors", "help the victims"]
        if let c = firstCue(in: toks, anyOf: isTR ? tr : en, isTR: isTR) {
            return Detection(hit: true, evidence: ["victimsupport:\(tokens(c, isTR: isTR).joined(separator: "_"))"])
        }
        return Detection(hit: false, evidence: [])
    }

    // MARK: - (d) Clause-scoped negation over the harm

    /// NEGATION is evaluated per CLAUSE (split on sentence + clause punctuation and a few conjunctions), so a negator
    /// only counts when it shares a clause with a harm/advocacy term — "şiddet değil sevgi" (not violence, love) is a
    /// rejection; "şiddet oldu, polis geldi" is NOT (no negator in the harm clause). This is the clause-scope law.
    private static func detectHarmNegation(_ raw: String, isTR: Bool) -> Detection {
        let negatorsTR = ["değil", "yok", "asla", "hayır", "istemiyoruz", "istemem", "olmaz", "hiçbir"]
        let negatorsEN = ["not", "never", "no", "don't", "do not", "doesn't", "won't", "shouldn't", "stop"]
        // Harm/advocacy anchors — the thing a negation would be rejecting. Kept small + structural (topic words come
        // from the lexicon layer; here we just need an anchor to test clause co-occurrence).
        let harmTR = ["şiddet", "şiddete", "nefret", "zarar", "öldür", "saldırı", "zorbalık", "istismar", "savaş"]
        let harmEN = ["violence", "violent", "hate", "harm", "kill", "attack", "abuse", "bully", "war"]
        let negators = isTR ? negatorsTR : negatorsEN
        let harm = isTR ? harmTR : harmEN
        for clause in clauses(raw) {
            let toks = tokens(clause, isTR: isTR)
            let neg = firstCue(in: toks, anyOf: negators, isTR: isTR)
            let hrm = firstCue(in: toks, anyOf: harm, isTR: isTR)
            if let n = neg, let h = hrm {
                return Detection(hit: true, evidence: ["negation:\(tokens(n, isTR: isTR).joined(separator: "_"))",
                                                       "harm:\(tokens(h, isTR: isTR).joined(separator: "_"))"])
            }
        }
        return Detection(hit: false, evidence: [])
    }

    /// Split into rough CLAUSES on sentence + clause punctuation and a few coordinating conjunctions. Not a full
    /// parser — just enough to keep negation scope from leaking across unrelated clauses (the §1 clause-scope law).
    private static func clauses(_ raw: String) -> [String] {
        let separators: Set<Character> = [".", "!", "?", ";", ",", ":", "\n", "—", "…"]
        var parts: [String] = []; var cur = ""
        for ch in raw {
            if separators.contains(ch) { if !cur.isEmpty { parts.append(cur); cur = "" } }
            else { cur.append(ch) }
        }
        if !cur.isEmpty { parts.append(cur) }
        // Further split on the strongest coordinating conjunctions ("ama/fakat" / "but") so a contrast flips scope.
        var out: [String] = []
        for p in parts {
            let lowered = p.lowercased()
            if let r = lowered.range(of: " ama ") ?? lowered.range(of: " fakat ") ?? lowered.range(of: " but ") {
                let i = p.index(p.startIndex, offsetBy: p.distance(from: lowered.startIndex, to: r.lowerBound))
                out.append(String(p[p.startIndex..<i])); out.append(String(p[i...]))
            } else { out.append(p) }
        }
        return out.isEmpty ? [raw] : out
    }

    // MARK: - (e) First-person advocacy vs third-person reporting (POS via NLTagger)

    private struct RoleResult { let advocacy: Bool; let reporting: Bool; let advocacyInsideQuote: Bool; let evidence: [String] }

    /// Distinguish FIRST-PERSON ADVOCACY (the speaker promoting the harm) from THIRD-PERSON REPORTING (narrating that
    /// it happened). Uses NLTagger `.lexicalClass` (POS) to confirm a verb is present, plus structural markers:
    ///   • Advocacy: imperative/optative calls ("yapın/yapalım/öldürün/vurun", EN "kill them/let's/we should/do it"),
    ///     desert/justification markers ("hak etti/hak ettiler", EN "deserve/deserved it").
    ///   • Reporting: reporting/past-event verbs ("yaşandı/oldu/bildirildi/açıklandı/öldü", EN "was killed/happened/
    ///     reported/were injured"). These are events narrated, not endorsed.
    private static func detectAdvocacyVsReporting(_ raw: String, isTR: Bool) -> RoleResult {
        let toks = tokens(raw, isTR: isTR)
        let advocacyTR = ["yapın", "yapalım", "yapmalıyız", "öldürün", "öldürelim", "vurun", "vuralım", "yakın",
                          "yakalım", "hak etti", "hak ettiler", "oh olsun", "destekliyoruz şiddeti", "gebertin",
                          "ezin", "yok edin", "yaşasın savaş"]
        let advocacyEN = ["let's", "we should", "we must", "kill them", "do it", "they deserve", "deserved it",
                          "beat them", "destroy them", "long live war", "attack them", "burn it"]
        let reportingTR = ["yaşandı", "oldu", "meydana geldi", "bildirildi", "açıklandı", "öldü", "öldürüldü",
                          "yaralandı", "gerçekleşti", "kaydedildi", "duyuruldu", "rapor edildi"]
        // NOTE: deliberately EXCLUDES weak/ambiguous cues like "broke out" / "happened" that a SARCASTIC sentence can
        // carry — a sarcastic "another war broke out, I love it" must abstain (UNKNOWN), not be read as a REPORT.
        let reportingEN = ["was killed", "were killed", "reported", "was injured", "were injured",
                          "took place", "announced", "was found", "according to the police"]

        let advocacyCue = firstCue(in: toks, anyOf: isTR ? advocacyTR : advocacyEN, isTR: isTR)
        let reportingCue = firstCue(in: toks, anyOf: isTR ? reportingTR : reportingEN, isTR: isTR)

        // POS confirmation: NLTagger VERB presence is used ONLY to upgrade a single WEAK reporting hint — it is NOT
        // required for ADVOCACY. An advocacy cue is already an imperative/optative CALL ("gebertin/vurun/kill them"),
        // which IS the verb; gating it behind a separate POS verb (Turkish POS is imperfect) would DROP a real
        // missed-risk signal — the dangerous direction. So an advocacy cue match asserts advocacy directly.
        var ev: [String] = []
        var advocacy = false, reporting = false, advocacyInsideQuote = false
        if let a = advocacyCue {
            advocacy = true
            ev.append("role:advocacy:\(tokens(a, isTR: isTR).joined(separator: "_"))")
            advocacyInsideQuote = advocacyCueInsideQuote(raw, cue: a, isTR: isTR)
        }
        // A VERB signal is recorded as weak provenance only (never a stance on its own).
        let hasVerb = posHasVerb(raw, isTR: isTR)
        if let r = reportingCue {
            reporting = true
            ev.append("role:reporting:\(tokens(r, isTR: isTR).joined(separator: "_"))")
        }
        if hasVerb && ev.isEmpty { ev.append("pos:verb") }
        return RoleResult(advocacy: advocacy, reporting: reporting, advocacyInsideQuote: advocacyInsideQuote, evidence: ev)
    }

    /// NLTagger POS: is there at least one VERB? On-device, public API. Returns false on empty/failed tagging (honest).
    private static func posHasVerb(_ raw: String, isTR: Bool) -> Bool {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = raw
        if isTR { tagger.setLanguage(.turkish, range: raw.startIndex..<raw.endIndex) }
        var found = false
        tagger.enumerateTags(in: raw.startIndex..<raw.endIndex, unit: .word, scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, _ in
            if tag == .verb { found = true; return false }
            return true
        }
        return found
    }

    /// Is the advocacy cue located INSIDE a quoted span? (If so, and a reporting frame is present, the speaker is
    /// reporting someone else's advocacy — not advocating.) We find quote spans by paired quote marks and test
    /// whether the first cue token falls within one.
    private static func advocacyCueInsideQuote(_ raw: String, cue: String, isTR: Bool) -> Bool {
        let openClose: [(Character, Character)] = [("\"", "\""), ("“", "”"), ("«", "»"), ("‘", "’"), ("'", "'")]
        guard let cueFirst = tokens(cue, isTR: isTR).first else { return false }
        let lowered = raw.precomposedStringWithCanonicalMapping.folding(options: [], locale: nil)
            .lowercased(with: Locale(identifier: isTR ? "tr_TR" : "en_US"))
        // Build quoted spans as (startOffset, endOffset) over `lowered`.
        var spans: [(Int, Int)] = []
        let chars = Array(lowered)
        for (open, close) in openClose {
            var i = 0
            while i < chars.count {
                if chars[i] == open {
                    var j = i + 1
                    while j < chars.count && chars[j] != close { j += 1 }
                    if j < chars.count { spans.append((i, j)) ; i = j + 1; continue }
                }
                i += 1
            }
        }
        guard !spans.isEmpty else { return false }
        // Does the cue's first token appear within any quoted span?
        let cueChars = Array(cueFirst)
        guard !cueChars.isEmpty else { return false }
        var k = 0
        while k + cueChars.count <= chars.count {
            if Array(chars[k..<k+cueChars.count]) == cueChars {
                for (s, e) in spans where k >= s && (k + cueChars.count - 1) <= e { return true }
            }
            k += 1
        }
        return false
    }
}
