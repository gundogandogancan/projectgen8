//
//  EmotionEvalR5Tests.swift — R5 §7 (P1-7): INDEPENDENT EVALUATION of the emotional-register capability.
//
//  LAWS: this set is NEW (not R3/R4 corpus sentences; synthetic, rights-clean, authored for R5). R3/R4 suites stay
//  as regression only. Thresholds are NOT tuned to the fixtures: the only HARD assertions are safety laws
//  (wrongly-softened-risk == 0; quoted threats never classified as the speaker's own pressure). Everything else is
//  MEASURED and printed honestly — including the non-separations (the §6 targeted-abuse gap is EXPECTED to fail
//  separation and is reported as such, never hidden).
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class EmotionEvalR5Tests: XCTestCase {

    struct EvalCase {
        let id: String
        let category: String          // the contrast family (§7 list)
        let text: String
        let lang: String
        /// Registers accepted as CORRECT for this case (UNKNOWN is listed where abstention is the right answer).
        let expected: Set<EmotionalRegisterV1>
        /// Whether a pressure register is the DESIRED detection (for pressure-vs-nonpressure P/R).
        let pressureExpected: Bool
        /// Whether abstention (UNKNOWN) is acceptable-but-not-ideal (honest coverage accounting).
        let abstentionAcceptable: Bool
    }

    // §7 — the R5-authored independent set (TR + EN, per-contrast pairs; NO prior-corpus sentences).
    static let cases: [EvalCase] = [
        // 1 — disease education vs disease fear-selling
        EvalCase(id: "TR-edu-disease", category: "disease-edu-vs-fearsell",
                 text: "Araştırmaya göre erken teşhis kanser tedavisinde başarıyı artırır; uzmanlar düzenli kontrol öneriyor.",
                 lang: "tr", expected: [.informational], pressureExpected: false, abstentionAcceptable: true),
        EvalCase(id: "TR-fearsell-disease", category: "disease-edu-vs-fearsell",
                 text: "Bu belirtiler sende de varsa büyük tehlike! Hemen al, son şans, stoklar tükeniyor!",
                 lang: "tr", expected: [.urgencyViaFear, .fearPressure], pressureExpected: true, abstentionAcceptable: false),
        EvalCase(id: "EN-edu-disease", category: "disease-edu-vs-fearsell",
                 text: "According to a recent study, early screening generally improves cancer treatment outcomes.",
                 lang: "en", expected: [.informational], pressureExpected: false, abstentionAcceptable: true),
        EvalCase(id: "EN-fearsell-disease", category: "disease-edu-vs-fearsell",
                 text: "Warning! This hidden illness is a danger to you - buy now, limited time, act fast!",
                 lang: "en", expected: [.urgencyViaFear, .fearPressure], pressureExpected: true, abstentionAcceptable: false),

        // 2 — earthquake preparedness vs unsourced panic
        EvalCase(id: "TR-quake-prep", category: "quake-prep-vs-panic",
                 text: "Deprem çantası hazırlamak riski azaltır; uzmanlar su, düdük ve el feneri öneriyor.",
                 lang: "tr", expected: [.informational], pressureExpected: false, abstentionAcceptable: true),
        EvalCase(id: "TR-quake-panic", category: "quake-prep-vs-panic",
                 text: "Büyük tehlike! Korkunç deprem her an olabilir!! Kimse güvende değil, şimdi kaç!",
                 lang: "tr", expected: [.urgencyViaFear, .sensationalPanic, .fearPressure], pressureExpected: true,
                 abstentionAcceptable: false),
        EvalCase(id: "EN-quake-prep", category: "quake-prep-vs-panic",
                 text: "Experts recommend keeping water and a flashlight ready; preparation generally reduces the risk.",
                 lang: "en", expected: [.informational], pressureExpected: false, abstentionAcceptable: true),
        EvalCase(id: "EN-quake-panic", category: "quake-prep-vs-panic",
                 text: "Terrifying danger!! The big one could hit any second, nobody is safe, run now!",
                 lang: "en", expected: [.urgencyViaFear, .sensationalPanic, .fearPressure], pressureExpected: true,
                 abstentionAcceptable: false),

        // 3 — plain news vs sensation
        EvalCase(id: "TR-news-plain", category: "news-vs-sensation",
                 text: "Bölgede dün akşam bir yangın çıktı; itfaiye raporuna göre can kaybı yok.",
                 lang: "tr", expected: [.informational, .unknown], pressureExpected: false, abstentionAcceptable: true),
        EvalCase(id: "TR-news-sensation", category: "news-vs-sensation",
                 text: "Şok! Korkunç yangın her yeri yuttu!! İnanamayacaksınız, tehlike büyüyor!!",
                 lang: "tr", expected: [.sensationalPanic], pressureExpected: true, abstentionAcceptable: false),
        EvalCase(id: "EN-news-plain", category: "news-vs-sensation",
                 text: "A fire broke out in the district last night; the official report lists no casualties.",
                 lang: "en", expected: [.informational, .unknown], pressureExpected: false, abstentionAcceptable: true),
        EvalCase(id: "EN-news-sensation", category: "news-vs-sensation",
                 text: "SHOCKING!! Terrifying fire swallows everything, the danger keeps growing!!",
                 lang: "en", expected: [.sensationalPanic], pressureExpected: true, abstentionAcceptable: false),

        // 4 — supportive speech vs emotional threat
        EvalCase(id: "TR-supportive", category: "support-vs-threat",
                 text: "Zor günlerden geçiyorsun ama yalnız değilsin; yanındayız, destek için buradayız.",
                 lang: "tr", expected: [.supportive], pressureExpected: false, abstentionAcceptable: false),
        EvalCase(id: "TR-emothreat", category: "support-vs-threat",
                 text: "Bu zinciri kırarsan ailene kötü şeyler olacak, paylaşmazsan görürsün.",
                 lang: "tr", expected: [.coerciveThreat], pressureExpected: true, abstentionAcceptable: false),
        EvalCase(id: "EN-supportive", category: "support-vs-threat",
                 text: "You are not alone in this; we are with you and support is available every day.",
                 lang: "en", expected: [.supportive], pressureExpected: false, abstentionAcceptable: false),
        EvalCase(id: "EN-emothreat", category: "support-vs-threat",
                 text: "If you don't forward this message, something terrible will follow you for years.",
                 lang: "en", expected: [.coerciveThreat], pressureExpected: true, abstentionAcceptable: false),

        // 5 — quoted threat vs direct threat
        EvalCase(id: "TR-quoted-threat", category: "quoted-vs-direct-threat",
                 text: "Tanık, saldırganın \"hepinize büyük tehlike yaşatacağım\" dediğini söyledi.",
                 lang: "tr", expected: [.unknown], pressureExpected: false, abstentionAcceptable: false),
        EvalCase(id: "TR-direct-threat", category: "quoted-vs-direct-threat",
                 text: "Dediğimi yapmazsan senin için büyük tehlike başlar, bunu unutma.",
                 lang: "tr", expected: [.coerciveThreat, .fearPressure], pressureExpected: true, abstentionAcceptable: false),
        EvalCase(id: "EN-quoted-threat", category: "quoted-vs-direct-threat",
                 text: "The witness said the man shouted \"I will bring danger to all of you\" before leaving.",
                 lang: "en", expected: [.unknown], pressureExpected: false, abstentionAcceptable: false),
        EvalCase(id: "EN-direct-threat", category: "quoted-vs-direct-threat",
                 text: "Unless you do what I say, real danger starts for you tonight.",
                 lang: "en", expected: [.coerciveThreat, .fearPressure], pressureExpected: true, abstentionAcceptable: false),

        // 6 — sport performance criticism vs targeted personal insult (§6 gap: separation NOT expected to work;
        //     measured honestly — targeted abuse is a DECLARED UNAVAILABLE capability in R5).
        EvalCase(id: "TR-sport-criticism", category: "criticism-vs-insult",
                 text: "Takımın savunması bu sezon çok kötü, hoca rotasyonu yine yanlış kurdu.",
                 lang: "tr", expected: [.unknown, .informational], pressureExpected: false, abstentionAcceptable: true),
        EvalCase(id: "TR-targeted-insult", category: "criticism-vs-insult",
                 text: "Sen tam bir beceriksizsin, bu takımda işin yok, defol git.",
                 lang: "tr", expected: [.unknown], pressureExpected: false, abstentionAcceptable: true),
        EvalCase(id: "EN-sport-criticism", category: "criticism-vs-insult",
                 text: "The defense has been poor all season and the coach keeps picking the wrong lineup.",
                 lang: "en", expected: [.unknown, .informational], pressureExpected: false, abstentionAcceptable: true),
        EvalCase(id: "EN-targeted-insult", category: "criticism-vs-insult",
                 text: "You are a complete failure and everyone here wants you gone.",
                 lang: "en", expected: [.unknown], pressureExpected: false, abstentionAcceptable: true),

        // 7 — fiction vs real
        EvalCase(id: "TR-fiction", category: "fiction-vs-real",
                 text: "Filmin finalinde kahraman \"şehri büyük tehlike bekliyor\" diyerek sahneyi kapatıyor.",
                 lang: "tr", expected: [.unknown], pressureExpected: false, abstentionAcceptable: false),
        EvalCase(id: "EN-fiction", category: "fiction-vs-real",
                 text: "In the movie's final act the hero says \"danger is coming for this city\" as the credits roll.",
                 lang: "en", expected: [.unknown], pressureExpected: false, abstentionAcceptable: false),

        // 8 — corrupted OCR (leet/garbled) → abstention expected, NEVER a confident pressure claim
        EvalCase(id: "TR-corrupt-ocr", category: "corrupted-ocr",
                 text: "T3hl1k3 h3m3n p4yl4s y0ksa k0tu s3yl3r", lang: "tr",
                 expected: [.unknown], pressureExpected: false, abstentionAcceptable: false),
        EvalCase(id: "EN-corrupt-ocr", category: "corrupted-ocr",
                 text: "D4ng3r!! sh4re n0w 0r 3ls3 b4d th1ngs", lang: "en",
                 expected: [.unknown], pressureExpected: false, abstentionAcceptable: false),

        // 9 — irony/ambiguity → UNKNOWN expected
        EvalCase(id: "TR-irony", category: "irony-unknown",
                 text: "Harika, yine \"korkunç tehlike\" başlıklarıyla uyanmış bulunuyoruz, ne sürpriz.",
                 lang: "tr", expected: [.unknown], pressureExpected: false, abstentionAcceptable: false),
        EvalCase(id: "EN-irony", category: "irony-unknown",
                 text: "Oh great, another \"terrifying danger\" headline, what a surprise.",
                 lang: "en", expected: [.unknown], pressureExpected: false, abstentionAcceptable: false),
    ]

    private func assess(_ c: EvalCase) -> EmotionalRegisterVerdictV1 {
        EmotionalRegisterAdapterV1.assessRegister(text: c.text, language: c.lang, itemIdentityRevision: 1,
                                                  policyRevision: 1, nowEpoch: 1000)
    }

    func testIndependentEvalR5MetricsAndSafetyLaws() {
        var perLang: [String: (correct: Int, total: Int)] = [:]
        var pressureTP = 0, pressureFP = 0, pressureFN = 0, pressureTN = 0
        var abstentions = 0
        var wronglySoftenedRisk = 0
        var quotedMisfires = 0
        var latencies: [Double] = []
        var confusion: [String: Int] = [:]
        var lines: [String] = []

        for c in Self.cases {
            let t0 = MonotonicClockV1.nowMs()
            let v = assess(c)
            latencies.append(MonotonicClockV1.nowMs() - t0)
            let correct = c.expected.contains(v.register)
            var slot = perLang[c.lang] ?? (0, 0)
            slot.total += 1; if correct { slot.correct += 1 }
            perLang[c.lang] = slot
            if v.register == .unknown { abstentions += 1 }
            switch (c.pressureExpected, v.register.isPressure) {
            case (true, true): pressureTP += 1
            case (true, false): pressureFN += 1
            case (false, true): pressureFP += 1
            case (false, false): pressureTN += 1
            }
            confusion["\(c.category)|exp:\(c.expected.map(\.rawValue).sorted().joined(separator: "/"))→got:\(v.register.rawValue)", default: 0] += 1
            // SAFETY LAW 1 — wrongly-softened risk must be ZERO: for every case with a pressure register detected
            // alongside a (hypothetically stance-softened) risk marker, the adjudicator must surface CAUTION.
            if v.register.isPressure {
                let softened = GeneralContentCharacterVerdictV1(
                    outcome: .contextAssessed, primaryCategory: .emotional,
                    markers: [GeneralContentMarkerV1(category: .emotional, hits: 1)], languageRaw: c.lang,
                    ocrNoisy: false, itemIdentityRevision: 1, policyRevision: 1, eventEpoch: 0,
                    expertModelVersion: "eval", contextStance: .reports, contextEffect: .softenToNote,
                    contextEvidence: [])
                let adj = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
                    baseSurfaceRaw: "GUARDIAN_ON",
                    baseReasonRaw: GuardianReasonCodeV1.generalContentContextSoftened.rawValue,
                    character: softened, register: v, childOutcome: nil, familyDegradedNonAdult: false)
                if adj.surfaceRaw != "CAUTION" { wronglySoftenedRisk += 1 }
            }
            // SAFETY LAW 2 — a QUOTED threat must never be classified as the speaker's own pressure.
            if c.category == "quoted-vs-direct-threat", !c.pressureExpected, v.register.isPressure {
                quotedMisfires += 1
            }
            lines.append("\(correct ? "OK " : "MISS") \(c.id) [\(c.category)] exp=\(c.expected.map(\.rawValue).sorted().joined(separator: "/")) got=\(v.register.rawValue) ev=\(v.evidence.joined(separator: "|"))")
        }

        let sorted = latencies.sorted()
        let p50 = sorted[sorted.count / 2]
        let p95 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        let precision = pressureTP + pressureFP == 0 ? 1.0 : Double(pressureTP) / Double(pressureTP + pressureFP)
        let recall = pressureTP + pressureFN == 0 ? 1.0 : Double(pressureTP) / Double(pressureTP + pressureFN)

        print("==== EMOTION_EVAL_R5 (independent, R5-authored; NOT R3/R4 sentences) ====")
        for l in lines { print(l) }
        print("---- metrics ----")
        for (lang, s) in perLang.sorted(by: { $0.key < $1.key }) {
            print("LANG \(lang): accepted \(s.correct)/\(s.total)")
        }
        print("PRESSURE detection: TP=\(pressureTP) FP=\(pressureFP) FN=\(pressureFN) TN=\(pressureTN) precision=\(String(format: "%.2f", precision)) recall=\(String(format: "%.2f", recall))")
        print("ABSTENTION (UNKNOWN): \(abstentions)/\(Self.cases.count)")
        print("WRONGLY_SOFTENED_RISK: \(wronglySoftenedRisk) (law: must be 0)")
        print("QUOTED_THREAT_MISFIRES: \(quotedMisfires) (law: must be 0)")
        print("LATENCY assessRegister p50=\(String(format: "%.3f", p50))ms p95=\(String(format: "%.3f", p95))ms (synthetic host, DEVICE_UNVERIFIED)")
        print("---- confusion (per contrast) ----")
        for (k, n) in confusion.sorted(by: { $0.key < $1.key }) { print("\(n)x \(k)") }
        print("==== end EMOTION_EVAL_R5 ====")

        // HARD LAWS ONLY (no fixture-fitted accuracy thresholds):
        XCTAssertEqual(wronglySoftenedRisk, 0, "a pressure register must always block stance softening")
        XCTAssertEqual(quotedMisfires, 0, "quoted threats must never be classified as the speaker's own pressure")
    }

    // §7 — stance-vs-register SEPARATION measurement (the two fields disagree where they should).
    func testStanceRegisterSeparationMeasured() {
        var separations = 0, comparable = 0
        for c in Self.cases where c.pressureExpected {
            let v = assess(c)
            let stance = ContextEvidenceAdapterV1.assessStance(text: c.text, language: c.lang,
                                                               itemIdentityRevision: 1, policyRevision: 1,
                                                               nowEpoch: 1000)
            guard stance.support == .supported else { continue }
            comparable += 1
            // Separation = the register carries pressure information the stance field does not encode.
            if v.register.isPressure { separations += 1 }
        }
        print("STANCE_VS_REGISTER separation: register added pressure info on \(separations)/\(comparable) comparable pressure cases")
        XCTAssertGreaterThan(comparable, 0)
    }
}
