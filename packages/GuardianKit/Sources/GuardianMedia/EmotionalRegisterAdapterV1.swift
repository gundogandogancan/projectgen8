//
//  EmotionalRegisterAdapterV1.swift — R5 §5 (P1-5): EMOTIONAL REGISTER — a SEPARATE dimension from stance.
//
//  WHY: R4's stance says WHAT the speaker's relation to a flagged harm is (advocates / reports / criticizes /
//  supports victims). It says NOTHING about HOW the content delivers emotionally. A news report about a disaster
//  can be calm information or fear-selling panic — same stance, different register. The mandate's law:
//  "Birinin şiddete karşı olması veya bir felaketi haber vermesi, kullandığı anlatımın duygusal olarak nötr
//  olduğunu göstermez." STANCE and REGISTER are therefore SEPARATE fields, and a REPORTS stance can NEVER
//  auto-clear an emotional-risk register signal (pinned by test).
//
//  NOT A FEAR-WORD LIST: the classifier is STRUCTURAL. Fear/urgency lexemes come from the CANONICAL frozen
//  GuardianCore `Lexicons` (no duplicate brains); the new intelligence is the RELATIONS between them:
//   • ADDRESSEE: 2nd person ("sen/siz/you") + imperative/CTA = pressure directed AT the viewer, vs 3rd-person
//     description of events.
//   • THREAT-CLAIM STRUCTURE: conditional frame ("yoksa/unless/if you don't") + a consequence.
//   • FEAR→ACTION COUPLING: a fear lexeme AND an urgency/CTA cue in the same text = fear channeled into action.
//   • REPETITION PRESSURE: repeated urgency cues / exclamation density.
//   • QUOTATION → UNKNOWN: a quoted/reported threat is NOT the speaker's own register (same law as R4 quotation).
//   • EDUCATIONAL COUNTER-EVIDENCE: source citation + measured/hedged language + no viewer-directed pressure
//     supports INFORMATIONAL.
//  Sarcasm/irony is NOT structurally detectable → UNKNOWN BY DESIGN (we never guess intent we cannot read).
//
//  TR + EN only; any other language → notApplicable (honest abstention, never a guess).
//  Pure + versioned + headless. No numeric 0–100 anywhere (calibration gate closed).
//
import Foundation
import NaturalLanguage
import GuardianCore

// MARK: - §5 — the register classes (categorical; never a severity score).

public enum EmotionalRegisterV1: String, Sendable, Equatable, Codable, CaseIterable {
    case informational   = "INFORMATIONAL"      // measured delivery; descriptive/educational framing
    case supportive      = "SUPPORTIVE"         // comfort/solidarity directed at the viewer or victims
    case fearPressure    = "FEAR_PRESSURE"      // fear-laden delivery directed AT the viewer
    case coerciveThreat  = "COERCIVE_THREAT"    // conditional threat structure aimed at the viewer ("yoksa…")
    case sensationalPanic = "SENSATIONAL_PANIC" // repetition/exclamation panic pressure without sourcing
    case urgencyViaFear  = "URGENCY_VIA_FEAR"   // fear coupled to an immediate action demand (CTA)
    case unknown         = "UNKNOWN"            // insufficient/ambiguous structure (incl. quotation/irony)

    /// The pressure family — these KEEP or RAISE caution and BLOCK context softening (never auto-cleared by stance).
    public var isPressure: Bool {
        self == .fearPressure || self == .coerciveThreat || self == .sensationalPanic || self == .urgencyViaFear
    }
}

// MARK: - §5 — the verdict (full provenance; privacy-safe structural cues only, never raw OCR).

public struct EmotionalRegisterVerdictV1: Sendable, Equatable, Codable {
    public let register: EmotionalRegisterV1
    /// supported = the language was TR/EN and the adapter actually ran; notApplicable = honest abstention.
    public let support: GuardianContextSupportV1
    /// Structural evidence cues (e.g. "addressee:2nd-person", "threat:conditional", "couple:fear+cta") — derived only.
    public let evidence: [String]
    public let languageRaw: String
    public let itemIdentityRevision: Int
    public let policyRevision: UInt64
    public let eventEpoch: Double
    public let adapterVersion: String

    public init(register: EmotionalRegisterV1, support: GuardianContextSupportV1, evidence: [String],
                languageRaw: String, itemIdentityRevision: Int, policyRevision: UInt64, eventEpoch: Double,
                adapterVersion: String) {
        self.register = register; self.support = support; self.evidence = evidence
        self.languageRaw = languageRaw; self.itemIdentityRevision = itemIdentityRevision
        self.policyRevision = policyRevision; self.eventEpoch = eventEpoch; self.adapterVersion = adapterVersion
    }
}

// MARK: - §5 — the adapter.

public enum EmotionalRegisterAdapterV1 {
    public static let version = "emotional-register-adapter-v1"
    public static let supportedLanguagePrefixes: Set<String> = ["tr", "en"]

    public static func isSupported(language: String?) -> Bool {
        guard let l = language?.lowercased(), !l.isEmpty else { return false }
        return supportedLanguagePrefixes.contains(String(l.prefix(2)))
    }

    public static func assessRegister(text: String?, language: String?,
                                      itemIdentityRevision: Int, policyRevision: UInt64,
                                      nowEpoch: Double) -> EmotionalRegisterVerdictV1 {
        func verdict(_ r: EmotionalRegisterV1, _ support: GuardianContextSupportV1, _ ev: [String],
                     _ langRaw: String) -> EmotionalRegisterVerdictV1 {
            EmotionalRegisterVerdictV1(register: r, support: support, evidence: ev, languageRaw: langRaw,
                                       itemIdentityRevision: itemIdentityRevision, policyRevision: policyRevision,
                                       eventEpoch: nowEpoch, adapterVersion: version)
        }
        let langRaw = language?.lowercased() ?? "und"
        guard isSupported(language: language) else {
            return verdict(.unknown, .notApplicable, ["unsupported-language"], langRaw)
        }
        guard let raw = text, raw.count >= 6 else {
            return verdict(.unknown, .supported, ["insufficient-text"], langRaw)
        }
        let isTR = langRaw.hasPrefix("tr")
        let lang = isTR ? "tr" : "en"
        let lowered = isTR ? raw.lowercased(with: Locale(identifier: "tr_TR")) : raw.lowercased()
        let toks = tokenize(lowered)

        // ── structural detections ───────────────────────────────────────────────────────────────────────
        var ev: [String] = []

        // Canonical lexeme anchors (frozen GuardianCore lexicons via the public LexiconMatcherV2 — no duplicate lists).
        let fearHits = LexiconMatcherV2.hits(raw, lexicon: Lexicons.fear, language: lang,
                                             supplement: LexiconMatcherV2.supplementalFear)
        let urgencyHits = LexiconMatcherV2.hits(raw, lexicon: Lexicons.urgency, language: lang)
                        + LexiconMatcherV2.hits(raw, lexicon: Lexicons.scarcity, language: lang)
        let ctaHits = LexiconMatcherV2.hits(raw, lexicon: Lexicons.repeatedCTA, language: lang)
                    + LexiconMatcherV2.hits(raw, lexicon: Lexicons.clickbait, language: lang)

        // (1) ADDRESSEE — is the viewer addressed directly (2nd person)?
        let secondPerson = isTR
            ? ["sen", "siz", "sana", "size", "seni", "sizi", "senin", "sizin", "kendini", "kendinizi"]
            : ["you", "your", "yours", "yourself", "yourselves"]
        let addressed = toks.contains(where: { secondPerson.contains($0) })
            // TR verb morphology: 2nd-person suffixes on common stems ("...mazsan", "...mezsen", "...ırsın").
            || (isTR && toks.contains(where: { $0.hasSuffix("mazsan") || $0.hasSuffix("mezsen")
                                            || $0.hasSuffix("mazsanız") || $0.hasSuffix("mezseniz") }))
        if addressed { ev.append("addressee:2nd-person") }

        // (2) THREAT-CLAIM STRUCTURE — conditional frame + consequence space.
        let conditionalFrames = isTR
            ? ["yoksa", "aksi halde", "aksi takdirde", "yapmazsan", "almazsan", "izlemezsen", "paylaşmazsan",
               "kırarsan", "yapmazsanız", "almazsanız", "eğer yapmazsan"]
            : ["unless", "or else", "otherwise", "if you don't", "if you do not", "if you fail to"]
        let conditional = conditionalFrames.first(where: { f in
            f.contains(" ") ? lowered.contains(f) : toks.contains(f)   // token-boundary for single words
        })
        if conditional != nil { ev.append("threat:conditional") }

        // (3) IMPERATIVE / ACTION DEMAND — CTA verbs the viewer is told to perform NOW.
        let imperativeCues = isTR
            ? ["hemen", "şimdi", "derhal", "acele et", "tıkla", "paylaş", "izle", "satın al", "kaydol",
               "abone ol", "kaç", "hazırlan", "harekete geç"]
            : ["now", "immediately", "right now", "hurry", "click", "share", "watch", "buy", "sign up",
               "subscribe", "act now", "don't wait", "run"]
        func cuePresent(_ cues: [String]) -> Bool {
            cues.contains { cue in
                cue.contains(" ") ? lowered.contains(cue) : toks.contains(cue)   // phrases by containment, words by token
            }
        }
        let actionDemand = cuePresent(imperativeCues) || ctaHits > 0
        if actionDemand { ev.append("action:imperative-or-cta") }

        // (4) REPETITION PRESSURE — exclamation density + repeated urgency cues.
        let exclamations = raw.filter { $0 == "!" }.count
        let repetition = exclamations >= 2 || urgencyHits >= 2
        if repetition { ev.append("pressure:repetition(excl=\(exclamations),urgency=\(urgencyHits))") }

        // (5) QUOTATION / REPORTED SPEECH — same law as R4: a quoted threat is not the speaker's own register.
        // NOTE: "göre"/"according to" are deliberately NOT here — they are SOURCING cues (educational counter-
        // evidence, detection (6)), not quotation. Only say-verb frames + quote marks attribute speech to another.
        // Straight apostrophe is EXCLUDED (English contractions: "don't" ≠ a quotation); smart quotes + say-verbs
        // carry quotation detection.
        let quoteChars: Set<Character> = ["\"", "\u{201C}", "\u{201D}", "«", "»", "\u{2018}", "\u{2019}"]
        let reportFrames = isTR
            ? ["dedi", "dedi ki", "söyledi", "dediğini", "açıkladı", "bildirdi", "iddia etti", "ifade etti", "aktardı"]
            : ["said", "says", "claimed", "claims", "reported", "stated", "told reporters"]
        // Say-verb frames match on TOKEN boundaries (substring would cross-match e.g. "dediğimi yapmazsan" — a
        // DIRECT threat — into reported speech); multiword frames use phrase containment.
        let quoted = raw.contains(where: { quoteChars.contains($0) })
            || reportFrames.contains(where: { f in f.contains(" ") ? lowered.contains(f) : toks.contains(f) })
        if quoted { ev.append("quote:reported-speech") }

        // (6) EDUCATIONAL / MEASURED counter-evidence — sourcing + hedged language.
        let sourcing = isTR
            ? ["kaynak", "araştırma", "araştırmaya göre", "uzmanlar", "veriler", "çalışma", "rapor"]
            : ["source", "research", "study", "studies", "experts", "data", "report", "evidence"]
        let hedged = isTR
            ? ["olabilir", "önerilir", "öneriyor", "tavsiye", "genellikle", "riskini azaltır", "bilgi"]
            : ["may", "might", "can help", "recommended", "recommends", "generally", "reduces the risk", "information"]
        let educationalFraming = sourcing.contains(where: { lowered.contains($0) })
            || hedged.contains(where: { lowered.contains($0) })
        if educationalFraming { ev.append("counter:educational-framing") }

        // (7) SUPPORTIVE cues — comfort/solidarity, viewer-directed, non-threatening.
        let supportiveCues = isTR
            ? ["yalnız değilsin", "yanındayız", "destek", "yardım hattı", "geçecek", "güvendesin", "buradayız"]
            : ["you are not alone", "you're not alone", "we are with you", "support is available", "help is available",
               "it gets better", "you are safe", "we're here for you"]
        let supportive = supportiveCues.contains(where: { lowered.contains($0) })
        if supportive { ev.append("supportive:solidarity") }

        let fearPresent = fearHits > 0
        if fearPresent { ev.append("anchor:fear-lexeme(\(fearHits))") }

        // ── classification (ordered; abstention-first where structure is ambiguous) ───────────────────
        // Quoted/reported fear-or-threat → UNKNOWN: the register belongs to the quoted party, not this speaker.
        if quoted && (fearPresent || conditional != nil) && !supportive {
            return verdict(.unknown, .supported, ev + ["abstain:quoted-threat-not-own-register"], langRaw)
        }
        // COERCIVE THREAT: conditional structure + (viewer addressed OR action demanded) + a consequence anchor.
        if conditional != nil && (addressed || actionDemand) {
            return verdict(.coerciveThreat, .supported, ev, langRaw)
        }
        // URGENCY VIA FEAR: fear anchor COUPLED to an immediate action demand (fear → action).
        if fearPresent && actionDemand && (urgencyHits > 0 || ctaHits > 0 || cuePresent(imperativeCues)) {
            return verdict(.urgencyViaFear, .supported, ev + ["couple:fear+cta"], langRaw)
        }
        // FEAR PRESSURE: fear anchor DIRECTED at the viewer (2nd person), with pressure structure.
        if fearPresent && addressed && !educationalFraming && !supportive {
            return verdict(.fearPressure, .supported, ev, langRaw)
        }
        // SENSATIONAL PANIC: fear anchor + repetition pressure, WITHOUT sourcing/measured framing.
        if fearPresent && repetition && !educationalFraming {
            return verdict(.sensationalPanic, .supported, ev, langRaw)
        }
        // SUPPORTIVE: solidarity cues without threat structure.
        if supportive && conditional == nil {
            return verdict(.supportive, .supported, ev, langRaw)
        }
        // INFORMATIONAL: measured/sourced framing without viewer-directed pressure or action demands.
        if educationalFraming && !addressedPressure(addressed: addressed, actionDemand: actionDemand) {
            return verdict(.informational, .supported, ev, langRaw)
        }
        // Fear topic mentioned purely in 3rd person without pressure structure → still only INFORMATIONAL when
        // there is a declarative verb and no pressure; otherwise UNKNOWN (bare mention — possible irony/sarcasm).
        if fearPresent && !addressed && !actionDemand && !repetition {
            if posHasVerb(raw, isTR: isTR) && educationalFraming {
                return verdict(.informational, .supported, ev + ["pos:verb"], langRaw)
            }
            return verdict(.unknown, .supported, ev + ["abstain:no-decisive-structure"], langRaw)
        }
        return verdict(.unknown, .supported, ev + ["abstain:no-decisive-structure"], langRaw)
    }

    private static func addressedPressure(addressed: Bool, actionDemand: Bool) -> Bool {
        addressed && actionDemand
    }

    private static func tokenize(_ lowered: String) -> [String] {
        lowered.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    /// NLTagger POS backbone (same approach as R4's adapter): on-device, public API, used only as weak confirmation.
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
}

// MARK: - R5 §3/§5 — the PURE surface adjudicator: composes the base wellbeing surface with the register and the
// child/family outcome under the CANONICAL precedence (ADR-0007: CHILD SAFETY FLOOR above personal softening).
// Pure + testable: SampleHandler computes its base surface exactly as before, then calls this ONE function — the
// precedence laws live here, pinned by tests, not scattered in the extension.

public enum GuardianFamilySurfaceAdjudicatorV1 {
    public static let version = "guardian-family-surface-adjudicator-v1"

    public struct AdjudicationV1: Sendable, Equatable {
        public let surfaceRaw: String
        public let reasonCodeRaw: String
        /// Derived provenance of what changed the base (for the proof log; never raw content).
        public let adjustments: [String]
    }

    /// LAWS enforced here (each pinned by a test):
    ///  1. A PRESSURE register (fear/coercion/panic/urgency-via-fear) BLOCKS context softening: REPORTS stance +
    ///     FEAR_PRESSURE → BOTH surfaced (caution with the register reason), never a softened note. Reporting style
    ///     does not clear emotional risk.
    ///  2. A PRESSURE register on an already-cautioned marker keeps the caution (reason upgraded to the register
    ///     reason so the user sees the emotional-pressure finding distinctly).
    ///  3. INFORMATIONAL/SUPPORTIVE registers NEVER soften anything by themselves — softening remains exclusively
    ///     the stance adapter's call (non-advocacy stance), unchanged from R4.
    ///  4. CHILD FLOOR: an active child/teen decision outranks personal softening and benign surfaces:
    ///     RESTRICTED/CAUTION → CAUTION surface with the child reason; UNKNOWN_REVIEW → UNKNOWN surface with the
    ///     distinct review reason. A child outcome NEVER weakens a stronger base (SHIELD_MATCH stays).
    ///  5. DEGRADED family profile (STALE/CORRUPT) with a non-adult last-known mode → fail closed to UNKNOWN with
    ///     the distinct family reason (old child policy is never shown as current).
    ///  6. ALIGNED child outcome / adult mode / no profile → base unchanged (adult behavior untouched).
    public static func adjudicate(baseSurfaceRaw: String, baseReasonRaw: String,
                                  character: GeneralContentCharacterVerdictV1?,
                                  register: EmotionalRegisterVerdictV1?,
                                  childOutcome: ChildAgeOutcomeV1?,
                                  familyDegradedNonAdult: Bool) -> AdjudicationV1 {
        var surface = baseSurfaceRaw
        var reason = baseReasonRaw
        var adjustments: [String] = []

        // (1)/(2) — register pressure keeps-or-raises; never softened by stance. Personal SHIELD_MATCH is already a
        // warn surface — the register never weakens it (we only annotate wellbeing surfaces).
        if let reg = register, reg.support == .supported, reg.register.isPressure, surface != "SHIELD_MATCH" {
            let baseWasSoftened = (character?.isContextSoftened == true)
                && reason == GuardianReasonCodeV1.generalContentContextSoftened.rawValue
            let baseIsCaution = surface == "CAUTION"
            let markerPresent = (character?.markers.isEmpty == false)
            if baseWasSoftened || baseIsCaution || markerPresent {
                surface = "CAUTION"
                reason = GuardianReasonCodeV1.emotionalRegisterPressureCaution.rawValue
                    adjustments.append("register:\(reg.register.rawValue):keep-or-raise\(baseWasSoftened ? ":blocked-softening" : "")")
            }
        }
        // (3) — informational/supportive: NO adjustment (softening stays the stance adapter's exclusive call).

        // (5) — degraded family profile fails closed BEFORE the child outcome (there IS no trustworthy outcome).
        if familyDegradedNonAdult {
            if surface != "SHIELD_MATCH" {   // a personal warn is stricter than unknown — never weakened
                surface = "UNKNOWN"
                reason = GuardianReasonCodeV1.familyProfileUnavailable.rawValue
            }
            adjustments.append("family:degraded-fail-closed")
            return AdjudicationV1(surfaceRaw: surface, reasonCodeRaw: reason, adjustments: adjustments)
        }

        // (4)/(6) — the child floor.
        if let outcome = childOutcome {
            switch outcome {
            case .restricted:
                surface = "CAUTION"
                reason = GuardianReasonCodeV1.childAgeRestricted.rawValue
                adjustments.append("child:AGE_RESTRICTED-floor")
            case .caution:
                if surface != "SHIELD_MATCH" {   // both warn; the personal warn already covers the surface
                    surface = "CAUTION"
                    reason = GuardianReasonCodeV1.childAgeCaution.rawValue
                }
                adjustments.append("child:AGE_CAUTION-floor")
            case .unknownReview:
                if surface != "SHIELD_MATCH" && surface != "CAUTION" {   // never weaken a standing warn
                    surface = "UNKNOWN"
                    reason = GuardianReasonCodeV1.childAgeUnknownReview.rawValue
                }
                adjustments.append("child:AGE_UNKNOWN_REVIEW")
            case .aligned:
                adjustments.append("child:AGE_ALIGNED-no-change")
            }
        }
        return AdjudicationV1(surfaceRaw: surface, reasonCodeRaw: reason, adjustments: adjustments)
    }
}
