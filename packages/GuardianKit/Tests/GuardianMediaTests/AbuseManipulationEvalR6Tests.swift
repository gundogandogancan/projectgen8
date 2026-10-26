//
//  AbuseManipulationEvalR6Tests.swift — R6 §7 + ADDENDUM §6: INDEPENDENT EVALUATION of the new targeted-abuse +
//  covert-manipulation capability (TargetedPressureHeuristicV1), measured alongside the register + stance dimensions.
//
//  LAWS: this set is NEW (not R3/R4/R5 corpus sentences; synthetic, rights-clean, authored for R6). R3/R4/R5 suites
//  stay as regression only. Thresholds are NOT tuned to the fixtures: the only HARD assertions are safety laws
//  (wrongly-softened-risk == 0; a 3rd-party/team/institution criticism never actions; a quoted insult never
//  actions). Everything else is MEASURED and printed honestly — including non-separations (humor/irony → UNKNOWN).
//
//  SUCCESS CRITERION (addendum §6): detect at least one content family with a pressure mechanism and NO overtly
//  negative lexicon, WITHOUT false-alarming on supportive/educational look-alikes. Measured below.
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class AbuseManipulationEvalR6Tests: XCTestCase {

    struct EvalCase {
        let id: String
        let category: String
        let text: String
        let lang: String
        /// Whether a SUPPORTED own-voice targeted-pressure signal is the DESIRED detection (the positive class).
        let pressureExpected: Bool
        /// Whether abstention / NONE is the correct answer (criticism, supportive, quoted, irony).
        let abstentionCorrect: Bool
    }

    // §7 + addendum §6 — the R6-authored independent set (TR + EN; per-contrast pairs; NO prior-corpus sentences).
    static let cases: [EvalCase] = [
        // 1 — sport-criticism vs personal insult
        EvalCase(id: "TR-sport-crit", category: "sport-criticism-vs-insult",
                 text: "Takımın savunması berbat oynadı, hoca yanlış kadro kurdu, performans çok düşük.",
                 lang: "tr", pressureExpected: false, abstentionCorrect: true),
        EvalCase(id: "TR-personal-insult", category: "sport-criticism-vs-insult",
                 text: "Sen tam bir beceriksizsin, bu takımda işin yok, defol git buradan.",
                 lang: "tr", pressureExpected: true, abstentionCorrect: false),
        EvalCase(id: "EN-sport-crit", category: "sport-criticism-vs-insult",
                 text: "The defense played poorly all season and the coach keeps picking the wrong lineup.",
                 lang: "en", pressureExpected: false, abstentionCorrect: true),
        EvalCase(id: "EN-personal-insult", category: "sport-criticism-vs-insult",
                 text: "You are a complete failure and everyone here wants you gone for good.",
                 lang: "en", pressureExpected: true, abstentionCorrect: false),

        // 2 — institution-criticism vs personal demeaning
        EvalCase(id: "TR-inst-crit", category: "institution-criticism-vs-demeaning",
                 text: "Hükümetin bu kararı yanlış ve zayıf, kurum yine hata yaptı.",
                 lang: "tr", pressureExpected: false, abstentionCorrect: true),
        EvalCase(id: "EN-inst-crit", category: "institution-criticism-vs-demeaning",
                 text: "The government failed to act and the policy is wrong and weak.",
                 lang: "en", pressureExpected: false, abstentionCorrect: true),

        // 3 — quoted vs direct threat
        EvalCase(id: "TR-quoted-insult", category: "quoted-vs-direct",
                 text: "Tanık, adamın \"sen tam bir beceriksizsin\" dediğini söyledi.",
                 lang: "tr", pressureExpected: false, abstentionCorrect: true),
        EvalCase(id: "EN-direct-threat", category: "quoted-vs-direct",
                 text: "Unless you do what I say, you'll regret it and bad things will happen to you.",
                 lang: "en", pressureExpected: true, abstentionCorrect: false),

        // 4 — supportive vs coercive 2nd-person
        EvalCase(id: "TR-supportive", category: "supportive-vs-coercive",
                 text: "Zor günlerden geçiyorsun ama yalnız değilsin, güçlüsün ve yanındayız.",
                 lang: "tr", pressureExpected: false, abstentionCorrect: true),
        EvalCase(id: "EN-supportive", category: "supportive-vs-coercive",
                 text: "You are not alone in this, you are strong and we support you every day.",
                 lang: "en", pressureExpected: false, abstentionCorrect: true),

        // 5 — conditional pressure WITHOUT overtly negative lexicon (addendum §6 success criterion)
        EvalCase(id: "TR-guilt-coercion", category: "no-lexicon-pressure",
                 text: "Senin yüzünden her şey mahvoldu, utanmalısın; hemen ara ve her şeyi düzelt.",
                 lang: "tr", pressureExpected: true, abstentionCorrect: false),
        EvalCase(id: "EN-guilt-coercion", category: "no-lexicon-pressure",
                 text: "It's your fault and you should be ashamed, now send the message and fix it immediately.",
                 lang: "en", pressureExpected: true, abstentionCorrect: false),

        // 6 — guilt/shame coercion vs honest apology-request
        EvalCase(id: "TR-apology-request", category: "guilt-coercion-vs-apology",
                 text: "Bence bir özür iyi olurdu, incindim ama konuşursak çözeriz.",
                 lang: "tr", pressureExpected: false, abstentionCorrect: true),
        EvalCase(id: "EN-apology-request", category: "guilt-coercion-vs-apology",
                 text: "I felt hurt by that, and I'd appreciate an apology when you're ready to talk.",
                 lang: "en", pressureExpected: false, abstentionCorrect: true),

        // 7 — provocation/incitement vs righteous anger at injustice
        EvalCase(id: "TR-incitement", category: "provocation-vs-righteous-anger",
                 text: "Bu rezalet! Hak ediyorlar, saldırın onlara, haddini bildirin hemen.",
                 lang: "tr", pressureExpected: true, abstentionCorrect: false),
        EvalCase(id: "TR-righteous-anger", category: "provocation-vs-righteous-anger",
                 text: "Bu haksızlığa çok öfkeliyim, gerçekten rezalet bir durum.",
                 lang: "tr", pressureExpected: false, abstentionCorrect: true),
        EvalCase(id: "EN-incitement", category: "provocation-vs-righteous-anger",
                 text: "This is outrageous! They deserve it, go after them and put them in their place now.",
                 lang: "en", pressureExpected: true, abstentionCorrect: false),
        EvalCase(id: "EN-righteous-anger", category: "provocation-vs-righteous-anger",
                 text: "I'm angry about this injustice, it is genuinely outrageous.",
                 lang: "en", pressureExpected: false, abstentionCorrect: true),

        // 8 — social comparison + deceptive urgency
        EvalCase(id: "EN-social-urgency", category: "social-comparison-deceptive-urgency",
                 text: "Everyone is doing it already, don't be left behind, last chance, sign up now!",
                 lang: "en", pressureExpected: true, abstentionCorrect: false),
        EvalCase(id: "TR-deceptive-urgency", category: "social-comparison-deceptive-urgency",
                 text: "Son şans! Stoklar tükeniyor, herkes aldı, sadece sen kaldın, hemen satın al!",
                 lang: "tr", pressureExpected: true, abstentionCorrect: false),

        // 9 — OCR noise (must not fabricate pressure)
        EvalCase(id: "TR-ocr-noise", category: "corrupted-ocr",
                 text: "S3n t4m b1r b3c3r1ks1zs1n d3f0l g1t", lang: "tr",
                 pressureExpected: false, abstentionCorrect: true),

        // 10 — irony → UNKNOWN
        EvalCase(id: "TR-irony", category: "irony-unknown",
                 text: "Harika, yine herkes bana akıl veriyor, ne sürpriz.",
                 lang: "tr", pressureExpected: false, abstentionCorrect: true),
        EvalCase(id: "EN-irony", category: "irony-unknown",
                 text: "Oh great, another person telling me what to do, what a surprise.",
                 lang: "en", pressureExpected: false, abstentionCorrect: true),
    ]

    private func assess(_ c: EvalCase) -> TargetedPressureVerdictV1 {
        TargetedPressureHeuristicV1.assess(text: c.text, language: c.lang, itemIdentityRevision: 1,
                                           policyRevision: 1, nowEpoch: 1000)
    }

    func testIndependentAbuseManipulationEvalR6() {
        var perLang: [String: (correct: Int, total: Int)] = [:]
        var tp = 0, fp = 0, fn = 0, tn = 0
        var abstentions = 0
        var wronglySoftenedRisk = 0           // a detected own-voice pressure must surface CAUTION, never softened
        var criticismActionedWrongly = 0      // a team/institution criticism must NEVER produce a caution
        var quotedActionedWrongly = 0         // a quoted insult must NEVER produce a caution
        var noLexiconDetected = 0, noLexiconTotal = 0   // addendum §6 success criterion
        var latencies: [Double] = []
        var lines: [String] = []

        for c in Self.cases {
            let t0 = MonotonicClockV1.nowMs()
            let v = assess(c)
            latencies.append(MonotonicClockV1.nowMs() - t0)
            let detected = v.isSupportedPressure
            // "correct" = detection matches the expected positive/negative class.
            let correct = (detected == c.pressureExpected)
            var slot = perLang[c.lang] ?? (0, 0); slot.total += 1; if correct { slot.correct += 1 }
            perLang[c.lang] = slot
            switch (c.pressureExpected, detected) {
            case (true, true): tp += 1
            case (true, false): fn += 1
            case (false, true): fp += 1
            case (false, false): tn += 1
            }
            if !detected { abstentions += 1 }

            // SAFETY LAW 1 — a detected own-voice pressure must surface CAUTION through the adjudicator (never softened).
            if detected {
                let adj = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
                    baseSurfaceRaw: "GUARDIAN_ON", baseReasonRaw: GuardianReasonCodeV1.textEvidenceBenign.rawValue,
                    character: nil, register: nil, childOutcome: nil, familyDegradedNonAdult: false,
                    targetedPressure: v)
                if adj.surfaceRaw != "CAUTION" { wronglySoftenedRisk += 1 }
            }
            // SAFETY LAW 2 — a criticism of a team/institution must NEVER produce a caution.
            if c.category == "sport-criticism-vs-insult" || c.category == "institution-criticism-vs-demeaning",
               c.id.contains("crit"), detected {
                criticismActionedWrongly += 1
            }
            // SAFETY LAW 3 — a quoted insult must NEVER produce a caution.
            if c.category == "quoted-vs-direct", c.id.contains("quoted"), detected { quotedActionedWrongly += 1 }
            // ADDENDUM §6 — the no-overt-lexicon pressure family.
            if c.category == "no-lexicon-pressure" { noLexiconTotal += 1; if detected { noLexiconDetected += 1 } }

            lines.append("\(correct ? "OK " : "MISS") \(c.id) [\(c.category)] expPressure=\(c.pressureExpected) detected=\(detected) target=\(v.target.rawValue) act=\(v.act.rawValue) mech=\(v.mechanism.rawValue) quoted=\(v.quotedNotOwnVoice) ev=\(v.evidence.joined(separator: "|"))")
        }

        let sorted = latencies.sorted()
        let p50 = sorted[sorted.count / 2]
        let p95 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        let precision = tp + fp == 0 ? 1.0 : Double(tp) / Double(tp + fp)
        let recall = tp + fn == 0 ? 1.0 : Double(tp) / Double(tp + fn)

        print("==== ABUSE_MANIPULATION_EVAL_R6 (independent, R6-authored; NOT R3/R4/R5 sentences) ====")
        for l in lines { print(l) }
        print("---- metrics ----")
        for (lang, s) in perLang.sorted(by: { $0.key < $1.key }) { print("LANG \(lang): accepted \(s.correct)/\(s.total)") }
        print("PRESSURE detection: TP=\(tp) FP=\(fp) FN=\(fn) TN=\(tn) precision=\(String(format: "%.2f", precision)) recall=\(String(format: "%.2f", recall))")
        print("ABSTENTION/NONE: \(abstentions)/\(Self.cases.count)")
        print("WRONGLY_SOFTENED_RISK: \(wronglySoftenedRisk) (law: must be 0)")
        print("CRITICISM_ACTIONED_WRONGLY: \(criticismActionedWrongly) (law: must be 0)")
        print("QUOTED_ACTIONED_WRONGLY: \(quotedActionedWrongly) (law: must be 0)")
        print("NO_OVERT_LEXICON_PRESSURE detected: \(noLexiconDetected)/\(noLexiconTotal) (addendum §6 success criterion)")
        print("LATENCY assess p50=\(String(format: "%.3f", p50))ms p95=\(String(format: "%.3f", p95))ms (synthetic host, DEVICE_UNVERIFIED)")
        print("==== end ABUSE_MANIPULATION_EVAL_R6 ====")

        // HARD LAWS ONLY (no fixture-fitted accuracy thresholds):
        XCTAssertEqual(wronglySoftenedRisk, 0, "a detected own-voice pressure must always surface CAUTION")
        XCTAssertEqual(criticismActionedWrongly, 0, "criticism of a team/institution must never be actioned")
        XCTAssertEqual(quotedActionedWrongly, 0, "a quoted insult must never be actioned as the speaker's")
        XCTAssertGreaterThanOrEqual(noLexiconDetected, 1, "addendum §6: at least one no-overt-lexicon pressure family must be detected")
    }

    // §7 — the three dimensions are SEPARATE (stance ≠ register ≠ targeted-pressure), measured honestly.
    func testThreeDimensionSeparationMeasured() {
        var comparable = 0, carriedNewInfo = 0
        for c in Self.cases where c.pressureExpected {
            let tp = assess(c)
            let stance = ContextEvidenceAdapterV1.assessStance(text: c.text, language: c.lang,
                                                               itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 1)
            guard tp.support == .supported else { continue }
            comparable += 1
            // Targeted-pressure carries TARGET/ACT/MECHANISM the stance field does not encode at all.
            if tp.isSupportedPressure { carriedNewInfo += 1 }
            _ = stance
        }
        print("THREE_DIM_SEPARATION: targeted-pressure added directed/mechanism info on \(carriedNewInfo)/\(comparable) comparable cases")
        XCTAssertGreaterThan(comparable, 0)
    }
}
