//
//  AdversarialPressureEvalR7Tests.swift — R7 §8: ADVERSARIAL PRESSURE EVALUATION (the HONEST map of where the
//  TargetedPressureHeuristicV1 breaks). A FRESH set (NOT the R6 corpus): novel institution/person names, quote-
//  within-quote, casual slang, legitimate vs fake urgency, supportive guilt talk vs coercion, satire, multi-speaker,
//  OCR fragmentation, condemnation vs incitement — TR + EN + mixed.
//
//  HONEST FRAMING (binding): these labels are ENGINEERING-AUTHORED, not independent ground truth. The purpose is to
//  MEASURE FP / FN / abstention and EXPECT failures — the finding is the MAP of where the structural heuristic breaks,
//  which feeds the RWC corpus/annotation plan. This test does NOT assert accuracy thresholds; it asserts only the
//  hard SAFETY laws (criticism-of-an-institution alone never becomes a directed personal attack; a quoted/condemned
//  act is not own-voice). All numbers are printed verbatim for the docs/progress/ADVERSARIAL_PRESSURE_R7.md writeup.
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class AdversarialPressureEvalR7Tests: XCTestCase {

    private struct Case { let text: String; let lang: String; let expectPressure: Bool; let family: String }

    // FRESH adversarial set (authored for R7; no R6 sentences reused). expectPressure = the engineering-authored
    // label for "a SUPPORTED own-voice directed-attack or covert-mechanism SHOULD fire" (best-effort, not truth).
    private let cases: [Case] = [
        // novel institution/person names — criticism of an institution is NOT a directed personal attack (law)
        .init(text: "Zarnovil Kurumu bu kararıyla büyük bir hata yaptı.", lang: "tr", expectPressure: false, family: "institution-criticism"),
        .init(text: "The Brennokk Agency completely mishandled the report.", lang: "en", expectPressure: false, family: "institution-criticism"),
        // directed personal demeaning (own voice) — SHOULD fire
        .init(text: "Sen tam bir aptalsın, hiçbir şey beceremiyorsun.", lang: "tr", expectPressure: true, family: "directed-demeaning"),
        .init(text: "You are worthless and everyone can see you will fail.", lang: "en", expectPressure: true, family: "directed-demeaning"),
        // quote-within-quote — the demeaning is attributed to someone else (NOT own voice)
        .init(text: "Muhabir dedi ki: \"birisi ona 'beceriksizsin' demiş\".", lang: "tr", expectPressure: false, family: "quote-within-quote"),
        .init(text: "She reported that he said \"you are a failure\" to the crowd.", lang: "en", expectPressure: false, family: "quote-within-quote"),
        // casual slang / friendly ribbing — ambiguous; label clean (abstain expected)
        .init(text: "Yürü be kanka, kafayı yemişsin sen ya 😄", lang: "tr", expectPressure: false, family: "casual-slang"),
        .init(text: "lol bro you're such a disaster at this game haha", lang: "en", expectPressure: false, family: "casual-slang"),
        // legitimate real urgency (evacuation) — NOT manipulation
        .init(text: "Resmi uyarı: sel riski nedeniyle bölgeyi derhal boşaltın, yetkilileri izleyin.", lang: "tr", expectPressure: false, family: "legit-urgency"),
        .init(text: "Official notice: evacuate the coastal area now due to the approaching storm.", lang: "en", expectPressure: false, family: "legit-urgency"),
        // fake urgency / deceptive scarcity (covert mechanism) — SHOULD fire
        .init(text: "Son 2 dakika! Hemen tıkla yoksa hesabın sonsuza dek silinecek!", lang: "tr", expectPressure: true, family: "fake-urgency"),
        .init(text: "Only 1 spot left — act in the next 60 seconds or lose everything forever!", lang: "en", expectPressure: true, family: "fake-urgency"),
        // supportive guilt talk vs coercion — supportive is clean
        .init(text: "Üzülme, herkes hata yapar; yanındayız, istediğinde konuşabiliriz.", lang: "tr", expectPressure: false, family: "supportive"),
        .init(text: "It's okay to struggle, we are here for you whenever you need us.", lang: "en", expectPressure: false, family: "supportive"),
        // guilt/shame coercion (covert mechanism) — SHOULD fire
        .init(text: "Beni gerçekten sevseydin bunu benim için yapardın, yoksa git.", lang: "tr", expectPressure: true, family: "guilt-coercion"),
        .init(text: "If you really cared about me you would do this, otherwise just leave.", lang: "en", expectPressure: true, family: "guilt-coercion"),
        // satire / irony — not structurally detectable → abstain expected (label clean)
        .init(text: "Harika bir plan! Kesinlikle hiçbir şey ters gitmez, ne güzel.", lang: "tr", expectPressure: false, family: "satire"),
        .init(text: "Oh brilliant, because that has always worked out so well before.", lang: "en", expectPressure: false, family: "satire"),
        // multi-speaker — a demeaning line embedded among others
        .init(text: "A: nasılsın? B: iyiyim. A: sen zaten her şeyi batırırsın.", lang: "tr", expectPressure: true, family: "multi-speaker"),
        // OCR fragmentation — broken tokens, meaning degraded (abstain acceptable)
        .init(text: "se n ap tal s ın hiç bir şe y", lang: "tr", expectPressure: false, family: "ocr-fragment"),
        // condemnation of violence (NOT incitement) — clean
        .init(text: "Bu şiddeti şiddetle kınıyoruz; kimse böyle davranmamalı.", lang: "tr", expectPressure: false, family: "condemnation"),
        .init(text: "We strongly condemn this violence; no one should ever act like this.", lang: "en", expectPressure: false, family: "condemnation"),
        // mixed TR/EN directed attack — SHOULD fire
        .init(text: "You are so aptal, hiçbir işe yaramıyorsun seriously.", lang: "tr", expectPressure: true, family: "mixed-directed"),
        // provocation/incitement (covert mechanism) — SHOULD fire
        .init(text: "Herkes gidip onlara haddini bildirsin, korkmayın, saldırın!", lang: "tr", expectPressure: true, family: "incitement"),
    ]

    func testAdversarialPressureMap() {
        var tp = 0, fp = 0, fn = 0, tn = 0, abstained = 0
        var perFamily: [String: (hit: Bool, expected: Bool)] = [:]
        print("=== R7 §8 ADVERSARIAL PRESSURE MAP (engineering-authored labels; NOT ground truth) ===")
        for c in cases {
            let v = TargetedPressureHeuristicV1.assess(text: c.text, language: c.lang,
                                                       itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 0)
            let fired = v.isSupportedPressure
            if v.support != .supported { abstained += 1 }
            switch (c.expectPressure, fired) {
            case (true, true):   tp += 1
            case (true, false):  fn += 1
            case (false, true):  fp += 1
            case (false, false): tn += 1
            }
            perFamily[c.family] = (fired, c.expectPressure)
            print(String(format: "[%@/%@] expect=%@ fired=%@ t=%@ a=%@ m=%@ quoted=%@ :: %@",
                         c.family, c.lang, c.expectPressure ? "P" : "-", fired ? "P" : "-",
                         v.target.rawValue, v.act.rawValue, v.mechanism.rawValue, v.quotedNotOwnVoice ? "Y" : "N",
                         String(c.text.prefix(48))))
        }
        let total = cases.count
        let precision = tp + fp > 0 ? Double(tp) / Double(tp + fp) : 0
        let recall = tp + fn > 0 ? Double(tp) / Double(tp + fn) : 0
        print(String(format: "TOTAL=%d TP=%d FP=%d FN=%d TN=%d abstained=%d precision=%.2f recall=%.2f",
                     total, tp, fp, fn, tn, abstained, precision, recall))

        // HARD SAFETY LAWS ONLY (never fitted to the set) — these are the invariants that must hold even when the
        // heuristic misses nuance. Everything else is a MEASUREMENT, not an assertion.
        // (1) Institution criticism must NEVER be classified as a directed personal attack.
        for c in cases where c.family == "institution-criticism" {
            let v = TargetedPressureHeuristicV1.assess(text: c.text, language: c.lang,
                                                       itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 0)
            let directedPersonal = v.target == .directedSecondPerson && (v.act == .demeaningInsult || v.act == .threat)
            XCTAssertFalse(directedPersonal, "criticising an institution is not a directed personal attack: \(c.text)")
        }
        // (2) A quoted/attributed act is never own-voice supported pressure (quote-within-quote).
        for c in cases where c.family == "quote-within-quote" {
            let v = TargetedPressureHeuristicV1.assess(text: c.text, language: c.lang,
                                                       itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 0)
            XCTAssertFalse(v.isSupportedPressure && !v.quotedNotOwnVoice && v.mechanism == .none,
                           "a quoted demeaning line is not an own-voice directed attack: \(c.text)")
        }
        // (3) Condemnation of violence must never be treated as incitement (own-voice provocation mechanism).
        for c in cases where c.family == "condemnation" {
            let v = TargetedPressureHeuristicV1.assess(text: c.text, language: c.lang,
                                                       itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 0)
            XCTAssertNotEqual(v.mechanism, .provocationIncitement, "condemning violence is not incitement: \(c.text)")
        }
        // The eval always "passes" as a measurement run (failures are the FINDING, printed above); only the safety
        // laws above can fail the test. This matches the mandate: EXPECT heuristic FP/FN, map them honestly.
        XCTAssertEqual(total, 24, "the fresh adversarial set size (for the doc)")
    }
}
