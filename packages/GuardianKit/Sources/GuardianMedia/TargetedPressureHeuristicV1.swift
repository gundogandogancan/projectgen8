//
//  TargetedPressureHeuristicV1.swift — R6 §4 + ADDENDUM §5/§6: the FIRST honestly-named structural capability for
//  TARGETED ABUSE + COVERT PSYCHOLOGICAL INFLUENCE. It is a HEURISTIC / STRUCTURAL EVIDENCE producer — NOT an
//  "abuse detector", NOT a sentiment model, NOT a measurement of anyone's psychological state (mandate law).
//
//  WHY A NEW DIMENSION (not a bigger word list — mandate §4): R3 proved a marker word ≠ meaning; R4 added STANCE
//  (who-says-what toward a flagged harm); R5 added EMOTIONAL REGISTER (how fear/urgency is delivered). What was
//  STILL missing: WHO the pressure is aimed AT, WHAT act it performs, and WHICH covert influence MECHANISM carries
//  it. "Takımın savunması kötü" (criticism of a team) and "sen tam bir beceriksizsin" (a demeaning insult aimed at
//  a person) were BOTH UNKNOWN in R5. This type separates them STRUCTURALLY — never from a single swear word.
//
//  THE THREE ORTHOGONAL DIMENSIONS (each its own field; UNKNOWN is first-class):
//   • TARGET   — who is addressed: 2nd-person DIRECTED ("sen/you") vs a 3rd-party DISCUSSED ("o/onlar/the team")
//                vs a GROUP ("hepiniz/you all"). A collective/institutional subject is NOT a directed personal target.
//   • ACT      — the speech act over that target: CRITICISM (of conduct/performance) vs DEMEANING INSULT (attacks
//                the person's worth) vs THREAT (a consequence is promised) vs NONE.
//   • MECHANISM — the covert influence structure (ADDENDUM §5): fear→action demand, guilt/shame→coercive call,
//                provocation→hostility incitement, social-comparison pressure, deceptive urgency. Each is a
//                RELATION between structural cues, never a lone keyword.
//
//  HARD HONESTY LAWS (mandate §4 + addendum §3 — each pinned by a counter-example test):
//   • Criticism of a TEAM / POLITICIAN / INSTITUTION is NEVER a targeted personal attack on its own (no public-figure
//     harm rating). A collective/3rd-party subject blocks the DEMEANING_INSULT→directed escalation.
//   • A QUOTED insult/threat is the QUOTED party's, not the speaker's (reuse R4's quotation law) → directed verdict
//     abstains to UNKNOWN for own-voice attribution.
//   • Humor / irony ambiguity → UNKNOWN BY DESIGN (we never claim to separate friendly ribbing from abuse without
//     context). A supportive 2nd-person message ("sen güçlüsün, yanındayız") must NEVER alarm.
//   • A mechanism REQUIRES a real behaviour-directing structure (a demand/CTA/consequence), not a mere topic word —
//     "righteous anger at an injustice" without an incitement-to-act structure is NOT provocation (addendum §3).
//   • NO numeric 0–100 anywhere (P009E closed). TR + EN only; anything else → notApplicable (honest abstention).
//
//  LINGUISTIC BACKBONE: shares ContextEvidenceAdapterV1's tokenizer + quotation/role detectors (same frozen-aligned
//  LanguageAwareTokenizerV1 behaviour) and anchors fear/anger/urgency/CTA on the CANONICAL frozen GuardianCore
//  lexicons via LexiconMatcherV2 (no duplicate brains). The NEW intelligence is the RELATIONS, declared heuristic.
//
//  Pure + headless + versioned + testable. Lives in GuardianMedia (GuardianCore frozen). Dual-compiled app+extension.
//
import Foundation
import GuardianCore

// MARK: - §4 — TARGET (who the expression is aimed at).

public enum TargetedPressureTargetV1: String, Sendable, Equatable, Codable {
    case directedSecondPerson = "DIRECTED_2ND_PERSON" // aimed AT the viewer/addressee ("sen/you")
    case thirdPartyDiscussed  = "THIRD_PARTY"         // about someone/something else ("o/onlar/the team/the minister")
    case group                = "GROUP"               // a collective ("hepiniz/you all/you people")
    case unknown              = "UNKNOWN"             // structure does not disambiguate the target
}

// MARK: - §4 — ACT (the speech act performed).

public enum TargetedPressureActV1: String, Sendable, Equatable, Codable {
    case criticism       = "CRITICISM"        // critique of conduct/performance/idea (NOT automatically abuse)
    case demeaningInsult = "DEMEANING_INSULT" // attacks the person's worth ("beceriksizsin/you are worthless")
    case threat          = "THREAT"           // a consequence is promised ("görürsün/you'll regret it")
    case none            = "NONE"             // no abusive/critical/threatening act detected
    case unknown         = "UNKNOWN"          // an act may be present but structure cannot classify it
}

// MARK: - §4 + ADDENDUM §5 — the covert influence MECHANISM (behaviour-direction structure).

public enum CovertPressureMechanismV1: String, Sendable, Equatable, Codable, CaseIterable {
    case fearToActionDemand      = "FEAR_TO_ACTION_DEMAND"      // fear anchor + an immediate action demand/CTA
    case guiltShameCoercion      = "GUILT_SHAME_COERCION"       // guilt/shame cue ("senin yüzünden/utanmalısın") + imperative
    case provocationIncitement   = "PROVOCATION_INCITEMENT"     // hostility cue + a call to go after a target ("saldırın")
    case socialComparisonPressure = "SOCIAL_COMPARISON_PRESSURE" // "herkes yapıyor/others already" + a self-directed demand
    case deceptiveUrgency        = "DECEPTIVE_URGENCY"          // manufactured scarcity/urgency ("son şans") + CTA
    case none                    = "NONE"                       // no behaviour-directing mechanism found
}

// MARK: - §4 — the verdict (categorical dimensions + the exact structural cues; never raw OCR).

public struct TargetedPressureVerdictV1: Sendable, Equatable, Codable {
    public let target: TargetedPressureTargetV1
    public let act: TargetedPressureActV1
    public let mechanism: CovertPressureMechanismV1
    /// supported = TR/EN + enough text; notApplicable = honest abstention (never softens/alarms anything).
    public let support: GuardianContextSupportV1
    /// True iff a QUOTED/reported frame attributes the act to another party (own-voice attribution abstains).
    public let quotedNotOwnVoice: Bool
    /// The structural evidence cues that produced the verdict (e.g. "target:2nd-person", "act:demeaning:beceriksiz",
    /// "mech:guilt+imperative"). Privacy-safe: the heuristic's OWN matched cues, never the raw OCR line.
    public let evidence: [String]
    public let languageRaw: String
    // --- Independent provenance (stamped by the caller; mirrors the register verdict) ---
    public let itemIdentityRevision: Int
    public let policyRevision: UInt64
    public let eventEpoch: Double
    public let heuristicVersion: String

    public init(target: TargetedPressureTargetV1, act: TargetedPressureActV1, mechanism: CovertPressureMechanismV1,
                support: GuardianContextSupportV1, quotedNotOwnVoice: Bool, evidence: [String], languageRaw: String,
                itemIdentityRevision: Int, policyRevision: UInt64, eventEpoch: Double, heuristicVersion: String) {
        self.target = target; self.act = act; self.mechanism = mechanism; self.support = support
        self.quotedNotOwnVoice = quotedNotOwnVoice; self.evidence = evidence; self.languageRaw = languageRaw
        self.itemIdentityRevision = itemIdentityRevision; self.policyRevision = policyRevision
        self.eventEpoch = eventEpoch; self.heuristicVersion = heuristicVersion
    }

    /// Does this verdict carry a SUPPORTED, own-voice targeted-pressure signal that warrants a distinct caution?
    /// TRUE iff: supported + not-quoted + a DIRECTED personal demeaning/threat, OR any real covert MECHANISM.
    /// Criticism alone, a 3rd-party/group subject, a quoted act, or NONE → NOT a caution (never over-claims).
    public var isSupportedPressure: Bool {
        guard support == .supported, !quotedNotOwnVoice else { return false }
        let directedPersonalAttack = target == .directedSecondPerson
            && (act == .demeaningInsult || act == .threat)
        return directedPersonalAttack || mechanism != .none
    }
}

public enum TargetedPressureHeuristicV1 {
    public static let version = "targeted-pressure-heuristic-v1"
    public static let supportedLanguagePrefixes: Set<String> = ["tr", "en"]

    public static func isSupported(language: String?) -> Bool {
        guard let l = language?.lowercased(), !l.isEmpty else { return false }
        return supportedLanguagePrefixes.contains(String(l.prefix(2)))
    }

    /// R6 §4 — assess TARGET / ACT / MECHANISM from the text's LINGUISTIC STRUCTURE. Pure: same inputs → same verdict.
    /// Called PER ITEM on the same OCR text the other adapters use (no extra OCR). Abstains honestly on everything
    /// it cannot structurally separate (humor/irony, unsupported language, insufficient text, quoted attribution).
    public static func assess(text: String?, language: String?,
                              itemIdentityRevision: Int, policyRevision: UInt64,
                              nowEpoch: Double) -> TargetedPressureVerdictV1 {
        func verdict(_ t: TargetedPressureTargetV1, _ a: TargetedPressureActV1, _ m: CovertPressureMechanismV1,
                     _ support: GuardianContextSupportV1, _ quoted: Bool, _ ev: [String],
                     _ langRaw: String) -> TargetedPressureVerdictV1 {
            TargetedPressureVerdictV1(target: t, act: a, mechanism: m, support: support, quotedNotOwnVoice: quoted,
                                      evidence: ev, languageRaw: langRaw, itemIdentityRevision: itemIdentityRevision,
                                      policyRevision: policyRevision, eventEpoch: nowEpoch, heuristicVersion: version)
        }
        let langRaw = language?.lowercased() ?? "und"
        guard isSupported(language: language) else {
            return verdict(.unknown, .none, .none, .notApplicable, false, ["unsupported-language"], langRaw)
        }
        guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), raw.count >= 6 else {
            return verdict(.unknown, .none, .none, .notApplicable, false, ["insufficient-text"], langRaw)
        }
        let isTR = langRaw.hasPrefix("tr")
        let lang = isTR ? "tr" : "en"
        let lowered = isTR ? raw.lowercased(with: Locale(identifier: "tr_TR")) : raw.lowercased()
        let toks = ContextEvidenceAdapterV1.tokens(raw, isTR: isTR)
        var ev: [String] = []

        func anyTok(_ cues: [String]) -> Bool { cues.contains { toks.contains($0) } }
        func anyPhrase(_ cues: [String]) -> Bool { cues.contains { lowered.contains($0) } }

        // ── QUOTATION — reuse the R4 law: a quoted act is not the speaker's own voice. ───────────────────────────
        let quoteChars: Set<Character> = ["\"", "\u{201C}", "\u{201D}", "«", "»", "\u{2018}", "\u{2019}"]
        let reportFrames = isTR
            ? ["dedi", "dedi ki", "söyledi", "dediğini", "açıkladı", "bildirdi", "iddia etti", "ifade etti", "aktardı"]
            : ["said", "says", "claimed", "claims", "reported", "stated", "told reporters", "shouted"]
        let quoted = raw.contains(where: { quoteChars.contains($0) })
            && reportFrames.contains(where: { f in f.contains(" ") ? lowered.contains(f) : toks.contains(f) })
        if quoted { ev.append("quote:reported-act") }

        // ── IRONY / HUMOR ambiguity → the whole verdict abstains (never guess intent we cannot read). ────────────
        let ironyCuesTR = ["ne sürpriz", "harika yine", "tabii ki", "sözde", "güya", "aferin"]
        let ironyCuesEN = ["oh great", "what a surprise", "yeah right", "so-called", "sure, sure", "nice job"]
        let ironic = anyPhrase(isTR ? ironyCuesTR : ironyCuesEN)
        if ironic { ev.append("abstain:irony-humor-ambiguity") }

        // ── TARGET — 2nd person directed vs group vs 3rd-party discussed. ─────────────────────────────────────────
        let secondPerson = isTR
            ? ["sen", "sana", "seni", "senin", "kendini", "kendin"]
            : ["you", "your", "yours", "yourself"]
        let groupCues = isTR
            ? ["hepiniz", "hepinize", "siz", "sizi", "size", "sizin", "siz insanlar"]
            : ["you all", "you people", "all of you", "you guys"]
        // Collective / institutional / 3rd-party subjects — a critique of these is NEVER a directed personal attack.
        let collective3rdParty = isTR
            ? ["takım", "takımın", "hükümet", "kurum", "parti", "yönetim", "bakan", "belediye", "şirket", "o ", "onlar",
               "onları", "hoca", "kadro", "sistem"]
            : ["the team", "government", "institution", "the party", "management", "minister", "council", "company",
               "they ", "them", "the coach", "the squad", "the system"]
        let addressed2nd = anyTok(secondPerson)
            || (isTR && toks.contains(where: { $0.hasSuffix("sin") || $0.hasSuffix("sın")
                                            || $0.hasSuffix("mazsan") || $0.hasSuffix("mezsen") }))
        let addressedGroup = anyTok(groupCues) || anyPhrase(isTR ? ["siz insanlar"] : ["you all", "you people"])
        let thirdParty = anyPhrase(collective3rdParty)
        let target: TargetedPressureTargetV1 = {
            if addressed2nd && !addressedGroup { return .directedSecondPerson }
            if addressedGroup { return .group }
            if thirdParty { return .thirdPartyDiscussed }
            return .unknown
        }()
        ev.append("target:\(target.rawValue)")

        // ── SUPPORTIVE 2nd-person — a counter-example guard: comfort/solidarity must NEVER read as an attack. ────
        let supportiveCues = isTR
            ? ["yalnız değilsin", "yanındayız", "güçlüsün", "başaracaksın", "destek", "gurur duyuyorum", "seninleyiz"]
            : ["you are not alone", "you're not alone", "we are with you", "you are strong", "you can do it",
               "i'm proud of you", "we support you"]
        let supportive = anyPhrase(supportiveCues)
        if supportive { ev.append("counter:supportive-2nd-person") }

        // ── ACT — criticism vs demeaning insult vs threat (structural, not a single swear). ──────────────────────
        // DEMEANING predicates attack the PERSON'S WORTH (adjective-of-worthlessness directed at a subject).
        let demeaningTR = ["beceriksizsin", "beceriksiz", "işe yaramazsın", "işe yaramaz", "aptalsın", "salaksın",
                           "değersizsin", "rezilsin", "berbatsın", "defol", "defol git", "senden adam olmaz"]
        let demeaningEN = ["you are a failure", "you're a failure", "worthless", "you are useless", "you're useless",
                           "you are stupid", "you're stupid", "you are pathetic", "get lost", "you are a loser",
                           "wants you gone", "want you gone"]
        // EN worth-attacking tokens that count as demeaning ONLY with a 2nd-person subject present ("you ... failure").
        let demeaningWorthTokensEN = ["failure", "loser", "worthless", "useless", "pathetic", "stupid", "idiot"]
        // CRITICISM targets conduct/performance/ideas (negative evaluation WITHOUT attacking personal worth).
        let criticismTR = ["kötü oynadı", "kötü", "yanlış", "başarısız oldu", "zayıf", "hata", "rotasyon yanlış",
                           "savunma kötü", "performans düşük", "beğenmedim"]
        let criticismEN = ["played poorly", "poor", "wrong", "failed to", "weak", "mistake", "bad lineup",
                           "defense is poor", "underperformed", "not good enough"]
        let threatTR = ["görürsün", "pişman olacaksın", "başına gelecek", "kötü şeyler olacak", "yakarım", "ararım seni",
                        "cezanı çekeceksin", "bulurum seni"]
        let threatEN = ["you'll regret", "you will regret", "you'll see", "bad things will happen to you",
                        "i'll find you", "you will pay", "come for you"]
        // DEMEANING cues mix single tokens ("beceriksizsin") and phrases ("you are a failure") → test both ways.
        // EN worth-attacking NOUNS ("failure/loser") count only alongside a 2nd-person subject ("you ... failure"),
        // so a 3rd-party "the plan was a failure" is NOT a personal insult.
        let hasDemeaning = isTR
            ? (anyTok(demeaningTR) || anyPhrase(demeaningTR))
            : (anyPhrase(demeaningEN) || (addressed2nd && anyTok(demeaningWorthTokensEN)))
        let hasThreat = anyPhrase(isTR ? threatTR : threatEN)
        let hasCriticism = anyPhrase(isTR ? criticismTR : criticismEN)
        let act: TargetedPressureActV1 = {
            if hasThreat { return .threat }
            // A DEMEANING insult counts as a directed personal attack ONLY when aimed at a 2nd-person subject and the
            // subject is not a collective (criticising a team/institution is criticism, not a personal insult).
            if hasDemeaning {
                return (target == .directedSecondPerson) ? .demeaningInsult : .criticism
            }
            if hasCriticism { return .criticism }
            return .none
        }()
        if act != .none { ev.append("act:\(act.rawValue)") }

        // ── MECHANISM — covert influence structures (each is a RELATION, declared heuristic). ────────────────────
        let fearHits = LexiconMatcherV2.hits(raw, lexicon: Lexicons.fear, language: lang,
                                             supplement: LexiconMatcherV2.supplementalFear)
        let urgencyHits = LexiconMatcherV2.hits(raw, lexicon: Lexicons.urgency, language: lang)
                        + LexiconMatcherV2.hits(raw, lexicon: Lexicons.scarcity, language: lang)
        let ctaHits = LexiconMatcherV2.hits(raw, lexicon: Lexicons.repeatedCTA, language: lang)
                    + LexiconMatcherV2.hits(raw, lexicon: Lexicons.clickbait, language: lang)
        let angerHits = LexiconMatcherV2.hits(raw, lexicon: Lexicons.anger, language: lang)
        let imperativeCues = isTR
            ? ["hemen", "şimdi", "derhal", "tıkla", "paylaş", "satın al", "kaydol", "abone ol", "harekete geç",
               "yap", "gönder", "ara", "yorum yap"]
            : ["now", "immediately", "right now", "click", "share", "buy", "sign up", "subscribe", "act now",
               "do it", "send", "call", "comment"]
        let imperative = anyPhrase(imperativeCues) || ctaHits > 0
        // GUILT / SHAME cues (self-blame framing directed at the viewer).
        let guiltShame = isTR
            ? ["senin yüzünden", "utanmalısın", "utan", "sen olmasaydın", "senin suçun", "mahvettin", "hayal kırıklığı"]
            : ["because of you", "you should be ashamed", "shame on you", "it's your fault", "your fault",
               "you ruined", "you let everyone down"]
        let hasGuiltShame = anyPhrase(guiltShame)
        // PROVOCATION / incitement cues (a call to go after a target — hostility amplification).
        let incitement = isTR
            ? ["saldırın", "hak ediyorlar", "haddini bildirin", "gösterin onlara", "susturun", "linç", "ezin onları",
               "peşini bırakmayın"]
            : ["go after them", "they deserve it", "put them in their place", "show them", "silence them",
               "take them down", "don't let them get away"]
        let hasIncitement = anyPhrase(incitement)
        // SOCIAL COMPARISON cues (everyone-else framing used to pressure the viewer).
        let socialComparison = isTR
            ? ["herkes yapıyor", "herkes aldı", "sadece sen", "geride kalma", "başkaları çoktan", "herkes burada"]
            : ["everyone is doing", "everyone already", "only you", "don't be left behind", "others already",
               "everyone else has"]
        let hasSocialComparison = anyPhrase(socialComparison)
        // DECEPTIVE URGENCY cues (manufactured scarcity + an immediate CTA).
        let deceptiveUrgencyCue = isTR
            ? ["son şans", "stoklar tükeniyor", "süre doluyor", "kaçırma", "son dakika fırsat", "bitmek üzere"]
            : ["last chance", "running out", "time is running out", "don't miss out", "limited time", "almost gone"]
        let hasDeceptiveUrgency = anyPhrase(deceptiveUrgencyCue)

        let mechanism: CovertPressureMechanismV1 = {
            // Precedence: the most specific coercion structures first; generic fear→action last.
            if hasGuiltShame && imperative { return .guiltShameCoercion }
            if hasIncitement && (angerHits > 0 || target == .thirdPartyDiscussed || target == .group) {
                return .provocationIncitement
            }
            if hasDeceptiveUrgency && imperative { return .deceptiveUrgency }
            if hasSocialComparison && imperative { return .socialComparisonPressure }
            if fearHits > 0 && imperative && (urgencyHits > 0 || ctaHits > 0) { return .fearToActionDemand }
            return .none
        }()
        if mechanism != .none {
            ev.append("mech:\(mechanism.rawValue)")
            if hasGuiltShame { ev.append("cue:guilt-shame") }
            if hasIncitement { ev.append("cue:incitement") }
            if hasDeceptiveUrgency { ev.append("cue:deceptive-urgency") }
            if hasSocialComparison { ev.append("cue:social-comparison") }
            if fearHits > 0 { ev.append("cue:fear(\(fearHits))") }
            if imperative { ev.append("cue:imperative-or-cta") }
        }

        // ── ABSTENTION RULES (honesty-first) ──────────────────────────────────────────────────────────────────
        // A quoted act, irony, or a supportive 2nd-person message never produces an own-voice pressure verdict.
        if quoted {
            return verdict(target, act == .none ? .none : .unknown, .none, .supported, true,
                           ev + ["abstain:quoted-not-own-voice"], langRaw)
        }
        if ironic {
            return verdict(.unknown, .unknown, .none, .supported, false, ev, langRaw)
        }
        if supportive && mechanism == .none && act != .threat {
            // Supportive speech directed at the viewer — explicitly NONE/NONE (never an attack), no mechanism.
            return verdict(target, .none, .none, .supported, false, ev + ["abstain:supportive"], langRaw)
        }
        return verdict(target, act, mechanism, .supported, false, ev, langRaw)
    }

    /// The canonical `attention:`-namespaced evidence label for a SUPPORTED own-voice pressure finding (fed into the
    /// world-model bridge as manipulation/attention evidence, exactly like the register). Returns nil when the
    /// verdict does not warrant a label (criticism / 3rd-party / quoted / unsupported) — nothing fabricated.
    public static func evidenceLabel(_ v: TargetedPressureVerdictV1) -> String? {
        guard v.isSupportedPressure else { return nil }
        if v.mechanism != .none { return "attention:covert-\(v.mechanism.rawValue.lowercased().replacingOccurrences(of: "_", with: "-"))" }
        if v.act == .threat { return "attention:targeted-threat-directed" }
        if v.act == .demeaningInsult { return "attention:targeted-demeaning-directed" }
        return nil
    }
}
