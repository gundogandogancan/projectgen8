import XCTest
import CryptoKit
import Foundation
@testable import GuardianCore

// AUDIT9 — INDEPENDENT P009E-R1 CLEAN-SESSION RE-AUDIT PROBES (fresh-context auditor, 2026-10-20).
// Mandate: docs/audit/prompts/GEN8_P009E_R1_INDEPENDENT_REAUDIT_MANDATE.md (S14 fresh family).
// ADD-ONLY: no production source or existing test modified. All metrics recomputed with
// AUDITOR-OWNED implementations; builder prints/claims are compared against, never trusted.
// Target commit under audit: 8dfdbf0fe34b9fab11a418ada0c30a20f3366fdc.

final class AUDIT9_P009ER1Probes: XCTestCase {

    // ───────────── auditor-owned V2 harness (independently re-derived; mirrors the contract, not the test file) ─────────────

    static var reg9: CalibrationRegistryV2!
    static var fusion9: SuitabilityFusionModelV1!
    static var resolved9: [(pair: CalibrationPairV1, m: ContentWorldModelV1, d: AdmissionStateCandidateV1)] = []
    static var dropped9: [String] = []

    func freshBrain() -> GuardianMetaBrainV2 {
        let b = GuardianMetaBrainV2()
        b.registry.register(VisionExpertV1()); b.registry.register(LanguageOCRExpertV1())
        b.registry.register(SpeechExpertV1()); b.registry.register(AudioEventExpertV1())
        b.registry.register(MusicExpertV1()); b.registry.register(SymbolExpertV1())
        b.registry.register(TemporalExpertV1()); b.registry.register(SafetyEvidenceExpertV1())
        b.registry.register(BenefitEvidenceExpertV1()); b.registry.register(AttentionPressureExpertV1())
        return b
    }

    /// Auditor resolver. Deliberately STRICT: no hidden fallback — an unresolvable reference returns nil
    /// and is RECORDED (never silently healed). Single-level alias only (a loop cannot recurse).
    func resolve9(_ pair: CalibrationPairV1) -> P009DPolicyScenarioV1? {
        let item = pair.itemID.replacingOccurrences(of: "ALIAS:", with: "")
        let aliasTarget = pair.corpus.hasPrefix("ALIAS:") ? String(pair.corpus.dropFirst(6)) : nil
        func fromP009C(_ name: String) -> P009DPolicyScenarioV1? {
            for split in P009CSplitV1.allCases {
                if let s = P009CCorpusV1.scenarios(split).first(where: { $0.name == name }) {
                    return P009DPolicyScenarioV1(name: s.name, family: s.family, segments: s.segments,
                                                 childProfile: pair.profile.childProfile,
                                                 parentPreference: pair.profile.parentPreference,
                                                 shieldConfig: pair.profile.shieldConfig, annotation: P009DPolicyAnnotationV1())
                }
            }
            return nil
        }
        switch pair.corpus {
        case "P009D":
            for split in P009DSplitV1.allCases {
                if let s = P009DPolicyCorpusV1.scenarios(split).first(where: { $0.name == item }) {
                    return P009DPolicyScenarioV1(name: s.name, family: s.family, segments: s.segments,
                                                 childProfile: pair.profile.childProfile,
                                                 parentPreference: pair.profile.parentPreference,
                                                 shieldConfig: pair.profile.shieldConfig, annotation: s.annotation)
                }
            }
            return nil
        case "P009C": return fromP009C(item)
        case "P009B_CAL_RESERVED":
            guard let s = P009BCorpusV2.scenarios(.calibrationReserved).first(where: { $0.name == item }) else { return nil }
            let segs = [P009CSegmentV1(startMs: 0, endMs: 3000, input: s.input)]
            return P009DPolicyScenarioV1(name: s.name, family: "cal-reserved", segments: segs,
                                         childProfile: pair.profile.childProfile,
                                         parentPreference: pair.profile.parentPreference,
                                         shieldConfig: pair.profile.shieldConfig, annotation: P009DPolicyAnnotationV1())
        case "P009E_TEEN":
            let segs = [P009CSegmentV1(startMs: 0, endMs: 3000,
                                       input: ExpertInputV2(ocrText: "explicit adult romance scenes compilation uncut",
                                                            detectedLanguage: "en"))]
            return P009DPolicyScenarioV1(name: item, family: "teen-sentinel", segments: segs,
                                         childProfile: pair.profile.childProfile,
                                         parentPreference: pair.profile.parentPreference,
                                         shieldConfig: pair.profile.shieldConfig, annotation: P009DPolicyAnnotationV1())
        default:
            if let t = aliasTarget { return fromP009C(t) }
            return nil
        }
    }

    override class func setUp() {
        super.setUp()
        let t = AUDIT9_P009ER1Probes()
        var results: [(CalibrationPairV1, ContentWorldModelV1, AdmissionStateCandidateV1)] = []
        var droppedIDs: [String] = []
        for (i, pair) in CalibrationDatasetRegistryV2.pairs.enumerated() {
            guard let sc = t.resolve9(pair) else {
                droppedIDs.append("\(pair.split.rawValue)/\(pair.corpus)/\(pair.itemID)")
                continue
            }
            let (m, d) = P009DPolicyCorpusV1.run(sc, brain: t.freshBrain(), item: ContentItemID(UInt64(190_000 + i)))
            results.append((pair, m, d))
        }
        resolved9 = results.map { (pair: $0.0, m: $0.1, d: $0.2) }
        dropped9 = droppedIDs
        // auditor refit — TRAIN_TUNE ONLY, identical discipline to the shipped harness
        let r = CalibrationRegistryV2()
        let train = results.filter { $0.0.split == .trainTune }
        for locale in ["tr", "en"] {
            let slice = train.filter { $0.0.annotation.locale == locale }
            r.register(DimensionCalibratorV1.fit(name: "risk", slice: locale,
                                                 xs: slice.map { $0.1.maxRiskSeen },
                                                 ys: slice.map { $0.0.annotation.finalLabel <= 1 }))
            r.register(DimensionCalibratorV1.fit(name: "benefit", slice: locale,
                                                 xs: slice.map { min(1, Double($0.1.benefitEvidence.count) * 0.4) },
                                                 ys: slice.map { $0.0.annotation.finalLabel >= 3 }))
            r.register(DimensionCalibratorV1.fit(name: "manip", slice: locale,
                                                 xs: slice.map { min(1, Double($0.1.manipulationEvidence.count) * 0.4) },
                                                 ys: slice.map { $0.0.annotation.finalLabel <= 2 }))
        }
        reg9 = r
        fusion9 = SuitabilityFusionModelV1.fit(features: features9(train, r),
                                               targets: train.map { Double($0.0.annotation.finalLabel) })
    }

    static func features9(_ rows: [(CalibrationPairV1, ContentWorldModelV1, AdmissionStateCandidateV1)],
                          _ r: CalibrationRegistryV2) -> [[Double]] {
        rows.map { (pair, m, d) in
            let loc = pair.annotation.locale
            let f = PersonalSuitabilityScoreV2.EngineV1.features(worldModel: m, decision: d)
            return [r.calibrator(name: "risk", slice: loc)?.probability(f.risk) ?? f.risk,
                    r.calibrator(name: "benefit", slice: loc)?.probability(f.benefit) ?? f.benefit,
                    r.calibrator(name: "manip", slice: loc)?.probability(f.manip) ?? f.manip,
                    (d.shieldOutcome?.hardMatch ?? false) ? 1 : 0,
                    (d.childOutcome == .restricted || d.childOutcome == .caution) ? 1 : 0]
        }
    }
    func engine9() -> PersonalSuitabilityScoreV2.EngineV1 {
        PersonalSuitabilityScoreV2.EngineV1(registry: Self.reg9, fusion: Self.fusion9)
    }
    func rows9(_ s: CalibrationSplitV1) -> [(pair: CalibrationPairV1, m: ContentWorldModelV1, d: AdmissionStateCandidateV1)] {
        Self.resolved9.filter { $0.pair.split == s }
    }
    func repoRoot() -> URL {
        // …/packages/GuardianKit/Tests/GuardianCoreTests/AUDIT9_P009ER1Probes.swift → repo root is 4 levels up
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    func teen9(_ name: String, text: String, lang: String, age: Int, jur: String = "TR") -> P009DPolicyScenarioV1 {
        P009DPolicyScenarioV1(name: name, family: "audit9",
                              segments: [P009CSegmentV1(startMs: 0, endMs: 3000,
                                                        input: ExpertInputV2(ocrText: text, detectedLanguage: lang))],
                              childProfile: GuardianEnteredChildProfileV1(ageYears: age, jurisdictionCode: jur, enteredByGuardian: true),
                              parentPreference: ParentPreferencePolicyV1(), shieldConfig: nil,
                              annotation: P009DPolicyAnnotationV1())
    }
    // auditor-owned metrics (strict half-open binning — independent of the builder's index-based binning)
    func myECE(_ preds: [Double], _ labels: [Bool], bins: Int = 10) -> (ece: Double, assigned: Int) {
        guard !preds.isEmpty else { return (0, 0) }
        var ece = 0.0, assigned = 0
        for i in 0..<bins {
            let lo = Double(i) / Double(bins), hi = Double(i + 1) / Double(bins)
            let idx = preds.indices.filter { i == bins - 1 ? (preds[$0] >= lo && preds[$0] <= hi) : (preds[$0] >= lo && preds[$0] < hi) }
            guard !idx.isEmpty else { continue }
            assigned += idx.count
            let mp = idx.map { preds[$0] }.reduce(0, +) / Double(idx.count)
            let fp = idx.map { labels[$0] ? 1.0 : 0.0 }.reduce(0, +) / Double(idx.count)
            ece += Double(idx.count) / Double(preds.count) * abs(mp - fp)
        }
        return (ece, assigned)
    }
    func myBrier(_ p: [Double], _ y: [Bool]) -> Double {
        zip(p, y).map { ($0 - ($1 ? 1 : 0)) * ($0 - ($1 ? 1 : 0)) }.reduce(0, +) / Double(max(1, p.count))
    }
    func myAUROC(_ p: [Double], _ y: [Bool]) -> Double? {
        let pos = zip(p, y).filter { $0.1 }.map { $0.0 }, neg = zip(p, y).filter { !$0.1 }.map { $0.0 }
        guard !pos.isEmpty, !neg.isEmpty else { return nil }
        var w = 0.0
        for a in pos { for b in neg { w += a > b ? 1 : (a == b ? 0.5 : 0) } }
        return w / Double(pos.count * neg.count)
    }

    // ───────────── S2: V2 referential integrity ─────────────

    func testA9_01_V2FullResolutionAndExactDeltaFromV1() {
        XCTAssertEqual(CalibrationDatasetRegistryV2.pairs.count, 59, "declared V2 size")
        XCTAssertEqual(Self.dropped9, [], "V2 must resolve 59/59 — NO dangling reference may remain: \(Self.dropped9)")
        XCTAssertEqual(Self.resolved9.count, 59)
        // split populations (claimed TRAIN 26 / CAL 12 / HELD_OUT 8 / STRESS 4 / OOD 4 / SENTINEL 5)
        XCTAssertEqual(rows9(.trainTune).count, 26)
        XCTAssertEqual(rows9(.calibration).count, 12)
        XCTAssertEqual(rows9(.heldOutFinal).count, 8)
        XCTAssertEqual(rows9(.stress).count, 4)
        XCTAssertEqual(rows9(.ood).count, 4)
        XCTAssertEqual(rows9(.safetySentinel).count, 5)
        // no alias indirection of any kind may remain in V2
        for p in CalibrationDatasetRegistryV2.pairs {
            XCTAssertFalse(p.itemID.contains("ALIAS:"), "\(p.itemID)")
            XCTAssertFalse(p.corpus.contains("ALIAS:"), "\(p.itemID): alias indirection must be gone in V2")
        }
        // duplicate semantic identity: (itemID, profileID) must be unique dataset-wide
        var seen = Set<String>()
        for p in CalibrationDatasetRegistryV2.pairs {
            let key = "\(p.itemID)|\(p.profile.profileID)"
            XCTAssertTrue(seen.insert(key).inserted, "duplicate item×profile identity: \(key)")
        }
        // V1→V2 delta must be EXACTLY the 7 remapped pairs, order-preserving, labels/splits preserved
        let v1 = CalibrationDatasetRegistryV1.pairs, v2 = CalibrationDatasetRegistryV2.pairs
        XCTAssertEqual(v1.count, v2.count)
        var changed: [String] = []
        for (a, b) in zip(v1, v2) {
            XCTAssertEqual(a.split, b.split, "split may never change in the V1→V2 correction")
            XCTAssertEqual(a.source, b.source)
            if a.itemID != b.itemID || a.corpus != b.corpus || a.profile.profileID != b.profile.profileID {
                changed.append("\(a.itemID)→\(b.itemID)[\(a.profile.profileID)→\(b.profile.profileID)]")
            } else {
                XCTAssertEqual(a.annotation.labelA, b.annotation.labelA, "\(a.itemID): untouched pair label drift")
                XCTAssertEqual(a.annotation.labelB, b.annotation.labelB, "\(a.itemID)")
                XCTAssertEqual(a.annotation.adjudicated, b.annotation.adjudicated, "\(a.itemID)")
            }
        }
        XCTAssertEqual(changed.count, 7, "exactly 5 phantom + 2 alias corrections, nothing else: \(changed)")
        let changedTargets = Set(zip(v1, v2).filter { $0.0.itemID != $0.1.itemID }.map { $0.1.itemID })
        XCTAssertEqual(changedTargets,
                       ["tc-persuasive-ad", "tc-manipulative-urgency", "tc-calm-nature", "tc-intent-ambiguity", "hc-ocean-calm"])
        print("AUDIT9_V2 resolved=\(Self.resolved9.count)/59 delta=\(changed)")
    }

    func testA9_02_DanglingAliasLoopAliasMissingFailClosed() {
        let A = ProfileFixtureV1.adultNeutral
        func probe(_ item: String, _ corpus: String) -> P009DPolicyScenarioV1? {
            resolve9(CalibrationPairV1(itemID: item, corpus: corpus, profile: A, split: .stress, source: .syntheticDerived,
                                       annotation: CalibrationAnnotationV1(itemID: item, profileID: A.profileID,
                                                                           locale: "en", labelA: 2, labelB: 2)))
        }
        // dangling reference → nil (recorded, never silently healed to some other scenario)
        XCTAssertNil(probe("pd-does-not-exist-anywhere", "P009D"))
        XCTAssertNil(probe("tc-does-not-exist-anywhere", "P009C"))
        // alias to missing target → nil
        XCTAssertNil(probe("x-alias-to-missing", "ALIAS:zz-no-such-scenario"))
        // alias loop (alias → alias name, which is not a real scenario) → nil, no recursion/hang
        XCTAssertNil(probe("x-alias-loop-a", "ALIAS:x-alias-loop-b"))
        // the BUILDER harness must agree (same contract): its resolver also fails closed on these
        let builder = P009EScoreTests()
        XCTAssertNil(builder.scenario(for: CalibrationPairV1(itemID: "pd-does-not-exist-anywhere", corpus: "P009D",
                                                             profile: A, split: .stress, source: .syntheticDerived,
                                                             annotation: CalibrationAnnotationV1(itemID: "x", profileID: A.profileID,
                                                                                                 locale: "en", labelA: 2, labelB: 2))))
    }

    func testA9_03_SplitLeakageDetectorAndDetectorSensitivity() {
        // builder detector clean on V2
        XCTAssertTrue(CalibrationDatasetRegistryV2.itemSplitViolations.isEmpty,
                      "\(CalibrationDatasetRegistryV2.itemSplitViolations)")
        // auditor's own item→split map (independent of the builder detector)
        var map: [String: CalibrationSplitV1] = [:]
        for p in CalibrationDatasetRegistryV2.pairs {
            if let s = map[p.itemID] { XCTAssertEqual(s, p.split, "item \(p.itemID) in two splits") }
            map[p.itemID] = p.split
        }
        // detector SENSITIVITY: an injected violation must be caught by the same logic the builder uses
        func violations(_ pairs: [(String, CalibrationSplitV1)]) -> [String] {
            var seen: [String: CalibrationSplitV1] = [:]; var v: [String] = []
            for (item, split) in pairs {
                if let s0 = seen[item], s0 != split { v.append(item) }
                seen[item] = split
            }
            return v
        }
        let injected = CalibrationDatasetRegistryV2.pairs.map { ($0.itemID, $0.split) } + [("tc-calm-nature", .heldOutFinal)]
        XCTAssertEqual(violations(injected), ["tc-calm-nature"], "detector must catch a cross-split duplicate when one exists")
    }

    func testA9_04_SemanticNearDupCrossSplitLeakage() {
        // content-level cross-split audit over the EXECUTED V2 scenarios (token Jaccard + exact duplicate)
        var items: [(String, CalibrationSplitV1, Set<String>)] = []
        var seen = Set<String>()
        for r in Self.resolved9 {
            guard seen.insert(r.pair.itemID).inserted, let sc = resolve9(r.pair) else { continue }
            let text = sc.segments.compactMap { $0.input.ocrText }.joined(separator: " ") + " "
                + sc.segments.compactMap { $0.input.speechTranscript }.joined(separator: " ")
            let toks = Set(text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
            items.append((r.pair.itemID, r.pair.split, toks))
        }
        XCTAssertGreaterThanOrEqual(items.count, 40, "V2 executed item inventory")
        var worst: (Double, String) = (0, "none")
        for i in items.indices {
            for j in items.indices where j > i && items[i].1 != items[j].1 {
                let a = items[i].2, b = items[j].2
                let jac = Double(a.intersection(b).count) / Double(max(1, a.union(b).count))
                if jac > worst.0 { worst = (jac, "\(items[i].1.rawValue)/\(items[i].0) ~ \(items[j].1.rawValue)/\(items[j].0)") }
                XCTAssertLessThanOrEqual(jac, 0.8, "cross-split near-duplicate: \(items[i].0) vs \(items[j].0) J=\(jac)")
                XCTAssertFalse(!a.isEmpty && a == b, "cross-split exact duplicate: \(items[i].0) vs \(items[j].0)")
            }
        }
        // the NEW V2 risk surface: hc-ocean-calm (CALIBRATION) and tc-calm-nature (TRAIN) share a family
        let ocean = items.first { $0.0 == "hc-ocean-calm" }, calm = items.first { $0.0 == "tc-calm-nature" }
        XCTAssertNotNil(ocean, "hc-ocean-calm must execute in V2"); XCTAssertNotNil(calm)
        if let o = ocean, let c = calm {
            let jac = Double(o.2.intersection(c.2).count) / Double(max(1, o.2.union(c.2).count))
            print("AUDIT9_LEAKAGE calm-family crossSplit J=\(String(format: "%.2f", jac))")
            XCTAssertLessThanOrEqual(jac, 0.8, "same-family cross-split pair must stay under the near-dup law")
        }
        print("AUDIT9_LEAKAGE worstCrossSplitJaccard=\(String(format: "%.2f", worst.0)) pair=\(worst.1)")
        XCTAssertTrue(CorpusSplitLeakageAuditorV1.audit().isEmpty, "P009B corpus split independence regressed")
    }

    // ───────────── S4: ECE binning — exhaustive fixtures, hand recomputation ─────────────

    func testA9_05_ECEIndexBinningFixtures() {
        // replicate the production assignment rule independently, then hand-verify every fixture
        func handECE(_ preds: [Double], _ labels: [Bool], bins: Int = 10) -> (ece: Double, counts: [Int]) {
            var assign: [[Int]] = Array(repeating: [], count: bins)
            for i in preds.indices { assign[min(bins - 1, max(0, Int(preds[i] * Double(bins))))].append(i) }
            var ece = 0.0
            for idx in assign where !idx.isEmpty {
                let mp = idx.map { preds[$0] }.reduce(0, +) / Double(idx.count)
                let fp = idx.map { labels[$0] ? 1.0 : 0.0 }.reduce(0, +) / Double(idx.count)
                ece += Double(idx.count) / Double(preds.count) * abs(mp - fp)
            }
            return (ece, assign.map { $0.count })
        }
        func check(_ name: String, _ preds: [Double], _ labels: [Bool]) {
            let builder = CalibrationMetricsV1.eceAndBins(preds: preds, labels: labels)
            let assigned = builder.bins.map { $0.count }.reduce(0, +)
            XCTAssertEqual(assigned, preds.count, "\(name): NO prediction may be dropped or double-counted")
            let mine = handECE(preds, labels)
            XCTAssertEqual(mine.counts.reduce(0, +), preds.count, "\(name): auditor replication no-drop")
            XCTAssertEqual(builder.ece, mine.ece, accuracy: 1e-12, "\(name): hand-recomputed ECE must match exactly")
        }
        check("conf=0 and conf=1 extremes", [0.0, 1.0], [false, true])
        check("exact decimal boundaries", [0.1, 0.2, 0.3, 0.5, 0.9], [true, false, true, false, true])
        check("repeated identical confidence", Array(repeating: 0.45, count: 6), [true, false, true, true, false, false])
        check("one per bin", (0..<10).map { Double($0) * 0.1 + 0.05 }, (0..<10).map { $0 % 2 == 0 })
        check("all in one bin", [0.71, 0.72, 0.73, 0.74], [true, true, false, true])
        check("uneven occupancy", [0.05, 0.06, 0.07, 0.55, 0.95], [false, false, true, true, true])
        // hand-verified value on a tiny fixture: preds .25/.25 labels T/F → one bin, |0.25-0.5|=0.25
        let tiny = CalibrationMetricsV1.eceAndBins(preds: [0.25, 0.25], labels: [true, false])
        XCTAssertEqual(tiny.ece, 0.25, accuracy: 1e-12)
        XCTAssertEqual(tiny.bins.count, 1); XCTAssertEqual(tiny.bins[0].count, 2)
        // conf=1.0 must land in the TOP bin (not fall off the edge)
        let top = CalibrationMetricsV1.eceAndBins(preds: [1.0], labels: [true])
        XCTAssertEqual(top.bins.count, 1); XCTAssertEqual(top.ece, 0.0, accuracy: 1e-12)
        // fp-edge truth (documented, deterministic): 0.3*10 rounds DOWN in binary fp → bin 2, exactly once.
        let fp = CalibrationMetricsV1.eceAndBins(preds: [0.2, 0.3], labels: [false, true])
        XCTAssertEqual(fp.bins.map { $0.count }.reduce(0, +), 2, "fp boundary values stay exactly-once")
        // ENTRY-GATE FIX INVERSION (A9-R1-F3; pre-declared in docs/calibration/ENTRY_GATE lock notes;
        // original pinned the silent clamp as an INFO finding): invalid domain now HARD-REFUSES —
        // NaN marker + empty bins on the legacy signature; typed throw on the strict API.
        let oor = CalibrationMetricsV1.eceAndBins(preds: [-0.2, 1.3], labels: [false, true])
        XCTAssertTrue(oor.ece.isNaN && oor.bins.isEmpty, "A9-R1-F3 FIXED: no silent clamp into the metric")
        // empty input well-defined
        XCTAssertEqual(CalibrationMetricsV1.eceAndBins(preds: [], labels: []).ece, 0)
    }

    // ───────────── S9: calibration truth — independent reproduction of EVERY claimed number ─────────────

    func testA9_06_IndependentMetricReproduction() {
        // TRAIN fit (claimed: n=26, MAE .628, w=[-1.83,1.44,-0.19,-1.00,-1.15])
        let f = Self.fusion9!
        XCTAssertTrue(f.fitted)
        XCTAssertEqual(rows9(.trainTune).count, 26)
        XCTAssertEqual(f.trainMAE, 0.628, accuracy: 0.02, "claimed TRAIN MAE .628 must reproduce")
        XCTAssertEqual(f.wRisk, -1.83, accuracy: 0.02); XCTAssertEqual(f.wBenefit, 1.44, accuracy: 0.02)
        XCTAssertEqual(f.wManip, -0.19, accuracy: 0.02); XCTAssertEqual(f.wShield, -1.00, accuracy: 0.02)
        XCTAssertEqual(f.wChild, -1.15, accuracy: 0.02)
        // CAL / HELD_OUT ordinal MAE via the auditor's own loop (claimed .743 n=12 abst=0; .559 n=7 abst=1)
        func maeLoop(_ rs: [(pair: CalibrationPairV1, m: ContentWorldModelV1, d: AdmissionStateCandidateV1)])
            -> (mae: Double, n: Int, abstained: Int, reasons: [String]) {
            var errs: [Double] = []; var abstained = 0; var reasons: [String] = []
            for r in rs {
                let c = engine9().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
                if let sc = c.score { errs.append(abs(sc / 25.0 - Double(r.pair.annotation.finalLabel))) }
                else { abstained += 1; reasons.append("\(r.pair.itemID):\(c.abstentionReason ?? "?")") }
            }
            return (errs.isEmpty ? 0 : errs.reduce(0, +) / Double(errs.count), errs.count, abstained, reasons)
        }
        let cal = maeLoop(rows9(.calibration)), held = maeLoop(rows9(.heldOutFinal))
        print("AUDIT9_MAE cal=\(String(format: "%.3f", cal.mae)) n=\(cal.n) abst=\(cal.abstained) | heldOut=\(String(format: "%.3f", held.mae)) n=\(held.n) abst=\(held.abstained) reasons=\(held.reasons)")
        XCTAssertEqual(cal.mae, 0.743, accuracy: 0.02, "claimed CAL MAE .743 must reproduce")
        XCTAssertEqual(cal.n, 12); XCTAssertEqual(cal.abstained, 0, "no silent exclusion from the CAL denominator")
        XCTAssertEqual(held.mae, 0.559, accuracy: 0.02, "claimed HELD_OUT MAE .559 must reproduce")
        XCTAssertEqual(held.n, 7); XCTAssertEqual(held.abstained, 1, "exactly one typed held-out abstention")
        XCTAssertFalse(held.reasons.contains { $0.hasSuffix(":?") }, "abstention must carry a typed reason")
        // risk reliability (claimed ECE .250 / Brier .139 / AUROC .94) — auditor binning AND builder binning
        var preds: [Double] = [], labels: [Bool] = []
        for r in rows9(.calibration) {
            if let p = Self.reg9.calibrator(name: "risk", slice: r.pair.annotation.locale)?.probability(r.m.maxRiskSeen) {
                preds.append(p); labels.append(r.pair.annotation.finalLabel <= 1)
            }
        }
        XCTAssertEqual(preds.count, 12, "every CAL pair enters the reliability set — no denominator bias")
        let mine = myECE(preds, labels)
        let builder = CalibrationMetricsV1.eceAndBins(preds: preds, labels: labels)
        XCTAssertEqual(mine.assigned, preds.count)
        XCTAssertEqual(builder.bins.map { $0.count }.reduce(0, +), preds.count)
        XCTAssertEqual(mine.ece, builder.ece, accuracy: 0.02, "independent binning must agree")
        XCTAssertEqual(mine.ece, 0.250, accuracy: 0.02, "claimed ECE .250 must reproduce")
        XCTAssertEqual(myBrier(preds, labels), 0.139, accuracy: 0.01, "claimed Brier .139 must reproduce")
        XCTAssertEqual(myAUROC(preds, labels) ?? -1, 0.94, accuracy: 0.02, "claimed AUROC .94 must reproduce")
        print("AUDIT9_RISK ece=\(String(format: "%.3f", mine.ece)) brier=\(String(format: "%.3f", myBrier(preds, labels))) auroc=\(String(format: "%.3f", myAUROC(preds, labels) ?? -1))")
        // GATE TRUTH: ECE .25 >> .05 target — must remain UNMET; high AUROC does NOT license any
        // "calibrated" claim (ranking ≠ calibration); nothing here may be relaxed.
        XCTAssertGreaterThan(mine.ece, 0.05, "ECE target is genuinely UNMET — must stay reported-unmet, never relaxed")
        XCTAssertEqual(Self.reg9.calibrationClass, .engineeringOnly)
    }

    func testA9_07_HeldOutContaminationAndRefitDeterminism() {
        // determinism: a second independent refit must reproduce the artifact EXACTLY
        let train = Self.resolved9.filter { $0.pair.split == .trainTune }.map { ($0.pair, $0.m, $0.d) }
        let again = SuitabilityFusionModelV1.fit(features: Self.features9(train, Self.reg9),
                                                 targets: train.map { Double($0.0.annotation.finalLabel) })
        XCTAssertEqual(again.wRisk, Self.fusion9.wRisk); XCTAssertEqual(again.wBenefit, Self.fusion9.wBenefit)
        XCTAssertEqual(again.wManip, Self.fusion9.wManip); XCTAssertEqual(again.wShield, Self.fusion9.wShield)
        XCTAssertEqual(again.wChild, Self.fusion9.wChild); XCTAssertEqual(again.bias, Self.fusion9.bias)
        // counterfactual contamination: adding HELD_OUT_FINAL to the fit MUST move the artifact —
        // the TRAIN-only reproduction above is therefore load-bearing (no post-hoc held-out tuning).
        let held = Self.resolved9.filter { $0.pair.split == .heldOutFinal }.map { ($0.pair, $0.m, $0.d) }
        let leaked = SuitabilityFusionModelV1.fit(features: Self.features9(train + held, Self.reg9),
                                                  targets: (train + held).map { Double($0.0.annotation.finalLabel) })
        let delta = abs(leaked.wRisk - Self.fusion9.wRisk) + abs(leaked.wBenefit - Self.fusion9.wBenefit)
                  + abs(leaked.wManip - Self.fusion9.wManip) + abs(leaked.wShield - Self.fusion9.wShield)
                  + abs(leaked.wChild - Self.fusion9.wChild) + abs(leaked.bias - Self.fusion9.bias)
        print("AUDIT9_LEAK_COUNTERFACTUAL deltaIfHeldOutLeaked=\(String(format: "%.4f", delta))")
        XCTAssertGreaterThan(delta, 1e-6, "held-out inclusion must change the artifact")
        // sentinel/OOD/stress rows may NEVER enter any fit
        XCTAssertFalse(train.contains { $0.0.split != .trainTune })
        // calibrators also TRAIN-only: refitting risk(en) on TRAIN reproduces the registered calibrator
        let sliceEN = train.filter { $0.0.annotation.locale == "en" }
        let riskAgain = DimensionCalibratorV1.fit(name: "risk", slice: "en",
                                                  xs: sliceEN.map { $0.1.maxRiskSeen },
                                                  ys: sliceEN.map { $0.0.annotation.finalLabel <= 1 })
        let registered = Self.reg9.calibrator(name: "risk", slice: "en")!
        XCTAssertEqual(riskAgain.a, registered.a); XCTAssertEqual(riskAgain.b, registered.b)
        XCTAssertEqual(riskAgain.sampleCount, registered.sampleCount)
    }

    // ───────────── S3: oodStatus single-truth-source + never conflated states ─────────────

    func testA9_08_OODStatusHonestyAndStateSeparation() {
        // LAW: oodStatus must be a pure function of m.oodFlags on EVERY path (scored and abstained) —
        // no second truth source, no hardcode (A8-F3 closure, verified adversarially over all 59 rows)
        for r in Self.resolved9 {
            let c = engine9().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
            if r.m.oodFlags > 0 {
                XCTAssertTrue(c.oodStatus == "OOD" || c.oodStatus == "OOD-flagged(\(r.m.oodFlags))",
                              "\(r.pair.itemID): oodFlags=\(r.m.oodFlags) but status=\(c.oodStatus)")
                XCTAssertNotEqual(c.oodStatus, "in-distribution",
                                  "\(r.pair.itemID): evidence-flagged OOD may never present as in-distribution")
            } else {
                XCTAssertEqual(c.oodStatus, "in-distribution",
                               "\(r.pair.itemID): no flags → status must not invent OOD")
            }
            // nil score must never present positively; UNKNOWN ≠ OOD ≠ UNSUPPORTED conflation check
            if c.score == nil {
                XCTAssertEqual(c.interpretation, "UNKNOWN")
                XCTAssertNotNil(c.abstentionReason)
            }
        }
        // the four OOD-split structural rows: all abstain, each with a TYPED reason
        for r in rows9(.ood) {
            let c = engine9().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
            XCTAssertNil(c.score, "\(r.pair.itemID)")
            let reason = c.abstentionReason ?? "MISSING"
            XCTAssertNotEqual(reason, "MISSING")
            print("AUDIT9_OOD \(r.pair.itemID) reason=\(reason) oodStatus=\(c.oodStatus) flags=\(r.m.oodFlags)")
            // unsupported language must surface as its OWN reason class, never silently relabeled OOD
            if r.pair.itemID == "od-unsupported-language-child" && r.m.oodFlags == 0 {
                XCTAssertNotEqual(reason, "ood", "UNSUPPORTED must not be conflated with OOD")
            }
        }
        // unsupported locale on an in-distribution item: UNSUPPORTED, not OOD, not UNKNOWN-knowledge
        if let r = rows9(.calibration).first {
            let c = engine9().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: "ja")
            XCTAssertNil(c.score)
            XCTAssertEqual(c.abstentionReason, "language-slice-unsupported")
            if r.m.oodFlags == 0 { XCTAssertEqual(c.oodStatus, "in-distribution") }
        }
        // missing calibrator (empty registry): UNCALIBRATED_SLICE — a separate honest class again
        if let r = rows9(.calibration).first {
            let cEmpty = PersonalSuitabilityScoreV2.EngineV1(registry: CalibrationRegistryV2(), fusion: Self.fusion9)
                .evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: "en")
            XCTAssertNil(cEmpty.score)
            XCTAssertEqual(cEmpty.calibrationStatus, "UNCALIBRATED_SLICE")
        }
    }

    // ───────────── S5: real multi-profile divergence + strong-risk universal protection ─────────────

    func testA9_09_RealProfileDivergenceAndStrongRiskUniversal() {
        // fear-band divergence via the REAL policy path on one world model (fresh run, fresh item ID)
        let s = P009DPolicyCorpusV1.scenarios(.tune).first { $0.name == "pd-child-fear" }!
        let m = P009CCorpusV1.run(P009CScenarioV1(name: s.name, family: s.family, segments: s.segments,
                                                  annotation: P009CAnnotationV1()),
                                  brain: freshBrain(), item: ContentItemID(191_000))
        var states: [String: AdmissionStateV1] = [:]
        for p in ProfileFixtureV1.all {
            states[p.profileID] = AdmissionPolicyPipelineV1.evaluate(worldModel: m, childProfile: p.childProfile,
                                                                     parentPreference: p.parentPreference,
                                                                     shieldConfig: p.shieldConfig, nowMs: 0).state
        }
        print("AUDIT9_DIVERGENCE fear-band states=\(states.mapValues { $0.rawValue })")
        XCTAssertNotEqual(states["adult-neutral"], states["parent-child9-tr"],
                          "child policy must genuinely diverge from adult on fear-band content (STATE, not ID strings)")
        XCTAssertGreaterThanOrEqual(Set(states.values.map { $0.rawValue }).count, 2)
        // STRONG-RISK UNIVERSAL PROTECTION: a severe item protects EVERY profile — divergence is FORBIDDEN here
        let severe = P009DPolicyScenarioV1(name: "a9-severe-universal", family: "audit9",
            segments: [P009CSegmentV1(startMs: 0, endMs: 4000,
                                      input: ExpertInputV2(ocrText: "graphic brutal violence gore blood killing footage uncensored",
                                                           detectedLanguage: "en"),
                                      temporalRisk: 0.95, temporalTopics: ["violence"])],
            childProfile: nil, parentPreference: ParentPreferencePolicyV1(), shieldConfig: nil,
            annotation: P009DPolicyAnnotationV1())
        let mSev = P009CCorpusV1.run(P009CScenarioV1(name: severe.name, family: severe.family, segments: severe.segments,
                                                     annotation: P009CAnnotationV1()),
                                     brain: freshBrain(), item: ContentItemID(191_001))
        for p in ProfileFixtureV1.all {
            let d = AdmissionPolicyPipelineV1.evaluate(worldModel: mSev, childProfile: p.childProfile,
                                                       parentPreference: p.parentPreference,
                                                       shieldConfig: p.shieldConfig, nowMs: 0)
            print("AUDIT9_UNIVERSAL \(p.profileID) state=\(d.state.rawValue) child=\(d.childOutcome?.rawValue ?? "-")")
            XCTAssertNotEqual(d.state, .neutral, "\(p.profileID): strong risk must never be NEUTRAL for any profile")
            // AUDIT9 FINDING (recorded in the report, severity LOW): for 13+ profiles the COMPONENT-level
            // childOutcome can read AGE_ALIGNED on strong-violence content because violence/gore is H1-UNAVAILABLE
            // (unbandable) and the teen fail-closed lexicon covers only the sexual sentinel class. Protection is
            // carried entirely by the safety-engine STATE precedence (asserted above and below). The locked
            // under-13 law is asserted strictly:
            if let child = p.childProfile, child.ageYears < JurisdictionAgeBandRegistryV1.h1RequiredUnderAge {
                XCTAssertNotEqual(d.childOutcome, .aligned, "\(p.profileID): under-13 may never be AGE_ALIGNED (H1 open)")
            }
            let c = engine9().evaluate(worldModel: mSev, decision: d, profile: p, locale: "en")
            XCTAssertNotEqual(c.interpretation, "ALIGNED-CANDIDATE", "\(p.profileID): no positive interpretation")
            if d.state == .strongProtection || d.state == .ageRestricted {
                XCTAssertLessThanOrEqual(c.score ?? 0, 10, "\(p.profileID): protection veto caps the number")
            }
        }
    }

    // ───────────── S6: single-author annotation honesty ─────────────

    func testA9_10_SimulatedDualSlotHonestyAndAdjudicationRule() {
        // the dataset must DECLARE simulation — never present as independent human calibration
        XCTAssertTrue(CalibrationDatasetRegistryV2.annotationMode.contains("SIMULATED_DUAL_SLOT"))
        XCTAssertTrue(CalibrationDatasetRegistryV2.annotationMode.contains("single-author"))
        XCTAssertTrue(CalibrationDatasetRegistryV2.annotationMode.contains("not independent humans"))
        XCTAssertFalse(CalibrationDatasetRegistryV2.annotationMode.lowercased().contains("independent human annot"),
                       "may not claim independent human annotation")
        // adjudication rule (R1): REQUIRED when |A−B| ≥ 2 — the data must satisfy its own declared rule
        XCTAssertTrue(CalibrationDatasetRegistryV2.adjudicationRule.contains("REQUIRED when |A-B| >= 2"))
        for p in CalibrationDatasetRegistryV2.pairs {
            if abs(p.annotation.labelA - p.annotation.labelB) >= 2 {
                XCTAssertNotNil(p.annotation.adjudicated, "\(p.itemID): |A−B|≥2 without adjudication violates the R1 rule")
            }
            if let adj = p.annotation.adjudicated {
                XCTAssertTrue(p.annotation.disagreement, "\(p.itemID): adjudication is only permitted on disagreement")
                XCTAssertTrue((0...4).contains(adj))
            }
        }
        // agreement metrics may not be overclaimed: disagreement is preserved in the data (not laundered)
        XCTAssertGreaterThan(CalibrationDatasetRegistryV2.pairs.filter { $0.annotation.disagreement }.count, 3)
    }

    // ───────────── S14: sentinel false-safe challenge ─────────────

    func testA9_11_SentinelFalseSafeChallenge() {
        // all 5 sentinels EXECUTED (a dropped sentinel would pass vacuously) + auditor's own falseSafe loop
        XCTAssertEqual(rows9(.safetySentinel).count, 5, "every SAFETY_SENTINEL pair must actually execute")
        var falseSafe = 0
        for r in rows9(.safetySentinel) {
            let c = engine9().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
            if (c.score ?? 0) >= 62.5 || c.interpretation == "ALIGNED-CANDIDATE" { falseSafe += 1 }
            if r.pair.annotation.finalLabel == 0 && r.d.state == .neutral { falseSafe += 1 }
        }
        print("AUDIT9_SENTINEL n=\(rows9(.safetySentinel).count) falseSafe=\(falseSafe)")
        XCTAssertEqual(falseSafe, 0, "claimed sentinel falseSafe=0 must reproduce under the auditor's loop")
        // rename challenge: same sentinel input, fresh name/ID — identical fail-closed behavior (no ID memorization)
        let renamed = teen9("zz-audit9-\(UUID().uuidString.prefix(8))",
                            text: "explicit adult romance scenes compilation uncut", lang: "en", age: 14)
        let (_, dR) = P009DPolicyCorpusV1.run(renamed, brain: freshBrain(), item: ContentItemID(192_000))
        XCTAssertNotEqual(dR.state, .neutral); XCTAssertNotEqual(dR.childOutcome, .aligned)
        // benefit-wrapped sentinel: educational lexicon flooding around sentinel text, child 9 — must stay closed
        let wrapped = teen9("a9-benefit-wrapped-sentinel",
                            text: "learn tutorial lesson guide science course explicit adult romance scenes compilation uncut",
                            lang: "en", age: 9)
        let (mW, dW) = P009DPolicyCorpusV1.run(wrapped, brain: freshBrain(), item: ContentItemID(192_001))
        XCTAssertNotEqual(dW.state, .neutral, "benefit wrapping must not neutralize a sentinel-class input")
        XCTAssertNotEqual(dW.childOutcome, .aligned)
        let cW = engine9().evaluate(worldModel: mW, decision: dW, profile: .parentChild9TR, locale: "en")
        XCTAssertNotEqual(cW.interpretation, "ALIGNED-CANDIDATE")
        if dW.state == .strongProtection || dW.state == .ageRestricted { XCTAssertLessThanOrEqual(cW.score ?? 0, 10) }
    }

    // ───────────── S7: demo-weights label truth (HUD) + frozen-artifact integrity ─────────────

    func testA9_12_DemoWeightsLabelTruthAndFrozenArtifacts() throws {
        let root = repoRoot()
        let hud = try String(contentsOf: root.appendingPathComponent("Gen8/GuardianIntelligenceHUD.swift"), encoding: .utf8)
        // the HUD's hardcoded fusion constants are a DEMO snapshot, not the fitted artifact — must say so
        XCTAssertTrue(hud.contains("DEMO FUSION WEIGHTS"), "HUD must label its hardcoded weights as DEMO")
        XCTAssertTrue(hud.contains("not the fitted artifact"))
        XCTAssertTrue(hud.contains("PRODUCTION SCORE DISPLAY: OFF"))
        for forbidden in ["production calibrated", "scientifically validated", "real-world validated",
                          "population validated", "calibrated personal score"] {
            XCTAssertFalse(hud.lowercased().contains(forbidden), "forbidden claim in HUD: \(forbidden)")
        }
        // truth check the label itself: the HUD demo constants (-1.6/1.12/0/-1) genuinely differ from the
        // live V2 fitted artifact (-1.83/1.44/-0.19/-1.00) — the DEMO label is accurate, not cosmetic
        XCTAssertGreaterThan(abs(Self.fusion9.wRisk - (-1.6)) + abs(Self.fusion9.wBenefit - 1.12), 0.1,
                             "demo snapshot ≠ fitted artifact — the label is load-bearing")
        // AUDIT8 frozen original: active probe file must be BYTE-IDENTICAL (builder claims zero inversions)
        let frozen = try Data(contentsOf: root.appendingPathComponent("docs/audit/AUDIT8_P009EProbes_ORIGINAL_LOCKED.swift.txt"))
        let active = try Data(contentsOf: root.appendingPathComponent("packages/GuardianKit/Tests/GuardianCoreTests/AUDIT8_P009EProbes.swift"))
        XCTAssertEqual(frozen, active, "AUDIT8 active probes must be byte-identical to the frozen original")
        let sha = SHA256.hash(data: frozen).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(sha, "930a4cc4c1c08b9b5a92084e1c0af6eddbcb28a0b536a4f5506185fec6019792", "frozen AUDIT8 SHA-256 lock")
    }

    // ───────────── S13/S14: score admission gate + production display law ─────────────

    func testA9_13_ScoreAdmissionGateAndNoNumericInAdmissionState() {
        guard let r = rows9(.calibration).first else { return XCTFail() }
        // type law: AdmissionStateCandidateV1 carries NO field named score (categorical state only)
        let mirror = Mirror(reflecting: r.d)
        XCTAssertFalse(mirror.children.contains { ($0.label ?? "").lowercased().contains("score") },
                       "admission state must stay categorical — no numeric score field")
        // release gate: CLOSED, exactly the six honest blockers; evaluate() is pure (re-call identical)
        let (open, conditions) = ProductionScoreReleaseGateV1.evaluate()
        XCTAssertFalse(open); XCTAssertEqual(conditions.count, 10)
        XCTAssertEqual(conditions.filter { !$0.met }.count, 6)
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().open)
        // production display OFF at every layer, even with the fully fitted V2 registry
        XCTAssertFalse(Self.reg9.productionDisplayAllowed())
        XCTAssertFalse(GuardianMetaBrainV2().calibration.scoreDisplayAllowed(), "P009B skeleton still refuses")
        // veto law on the live V2 artifact
        for r in rows9(.stress) where r.d.state == .strongProtection || r.d.state == .ageRestricted {
            let c = engine9().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
            if let s = c.score { XCTAssertLessThanOrEqual(s, 10) }
            XCTAssertNotEqual(c.interpretation, "ALIGNED-CANDIDATE")
        }
    }

    // ───────────── S12: C6 bright-to-bright effectiveness (fresh values) ─────────────

    func testA9_14_C6BrightToBrightStillLoadBearing() {
        func shot(_ raw: UInt64, c: Double, s: Double, at: Double) -> ShotDescriptorV1 {
            let rep = Tier0CorpusV1.frame(content: c, style: s, chromeTop: 0.9, chromeBottom: 0.1, projShift: 0)
            return ShotDescriptorV1(shotID: ShotID(raw), observationID: ObservationID(9), startMs: at, endMs: at,
                                    representative: rep, transitionIn: .cut, swipeGate: .noSwipe,
                                    replacementRatioIn: 0.85, confidenceIn: 0.7,
                                    captionFingerprint: nil, audioContinuityWithPrevious: nil)
        }
        // fresh auditor value pairs (none reused from AUDIT2): different bright items must never merge
        for (i, p) in [(0.91, 0.93, 0.87, 0.91, 5200.0), (0.89, 0.91, 0.84, 0.89, 8000.0),
                       (0.94, 0.96, 0.90, 0.94, 4100.0)].enumerated() {
            let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
            _ = e.process(shot(1, c: p.0, s: p.1, at: 0))
            let d = e.process(shot(2, c: p.2, s: p.3, at: p.4))
            XCTAssertNotEqual(d.state, .sameItemConfirmed, "bright→bright[\(i)] must never unsafely merge")
            XCTAssertFalse(d.safeAdmissionInheritance, "bright→bright[\(i)] must never inherit admission")
        }
        // the independence guard must remain LOAD-BEARING on the C6 shape (not vacuously green)
        let pol = ProfileAwareItemGroupingPolicyV2.frozenTier0
        var loadBearing = 0
        for c1 in stride(from: 0.78, through: 0.94, by: 0.02) {
            for dc in stride(from: 0.01, through: 0.08, by: 0.01) {
                let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
                _ = e.process(shot(1, c: c1, s: c1 + 0.03, at: 0))
                let d = e.process(shot(2, c: c1 - dc, s: c1 + 0.02, at: 5000))
                guard let ch = d.channels else { continue }
                let fired = d.evidence.filter { $0.supportsSameItem }.map { $0.source.raw }
                let wouldMerge = d.mergeScore >= pol.confirmSameNormalized && d.newScore < pol.newVetoLevel
                    && ch.anchored && !ch.strongNew
                if wouldMerge && !EvidenceIndependenceGuardV1.allowsSameConfirmation(firedSameSources: fired) {
                    loadBearing += 1
                    XCTAssertNotEqual(d.state, .sameItemConfirmed)
                }
            }
        }
        print("AUDIT9_C6 loadBearingCases=\(loadBearing)")
        XCTAssertGreaterThan(loadBearing, 0, "C6 guard must still be load-bearing, present and unweakened")
    }

    // ───────────── S2/S14: V1 frozen preservation ─────────────

    func testA9_15_V1RegistryFrozenAsAuditEvidence() {
        // V1 must still DECLARE its defects exactly as AUDIT8 pinned them (frozen evidence, not healed)
        let v1 = CalibrationDatasetRegistryV1.pairs
        XCTAssertEqual(v1.count, 59)
        XCTAssertEqual(v1.filter { $0.itemID == "pd-persuasive-ad" }.count, 2, "phantom refs must remain in frozen V1")
        XCTAssertEqual(v1.filter { $0.itemID == "pd-manipulative-urgency" }.count, 1)
        XCTAssertEqual(v1.filter { $0.itemID == "pd-calm-nature" }.count, 2)
        XCTAssertEqual(v1.filter { $0.corpus.hasPrefix("ALIAS:") }.count, 2, "both dead ALIAS pairs must remain in V1")
        // and V1's phantoms still do NOT resolve (the defect is preserved, not silently fixed in place)
        let phantoms = v1.filter { ["pd-persuasive-ad", "pd-manipulative-urgency", "pd-calm-nature"].contains($0.itemID) }
        XCTAssertEqual(phantoms.count, 5)
        for p in phantoms { XCTAssertNil(resolve9(p), "\(p.itemID): V1 phantom must stay unresolvable") }
        // V2 is the live registry and contains none of V1's defects
        XCTAssertTrue(CalibrationDatasetRegistryV2.pairs.allSatisfy { !$0.corpus.hasPrefix("ALIAS:") })
        XCTAssertFalse(CalibrationDatasetRegistryV2.pairs.contains { $0.itemID.hasPrefix("pd-persuasive") || $0.itemID == "pd-calm-nature" || $0.itemID == "pd-manipulative-urgency" })
        // provenance honesty identical in V2: synthetic/structural only, no real-world claim possible
        XCTAssertEqual(CalibrationDatasetRegistryV2.sourceClassCounts[.syntheticDerived], 55)
        XCTAssertEqual(CalibrationDatasetRegistryV2.sourceClassCounts[.structuralOnly], 4)
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims)
    }

    // ───────────── S11: Tier-0 capability truth ─────────────

    func testA9_16_Tier0CapabilityTruthUnchanged() {
        let resolver = CapabilityResolverV2()
        XCTAssertEqual(resolver.permittedDomains(for: .extensionFastTier0), [.temporal],
                       "Tier-0 stays identity/temporal only — no cheap-channel semantics")
        XCTAssertTrue(resolver.permittedDomains(for: .extensionTier1Lite).isEmpty, "UNAVAILABLE until device-proven")
        XCTAssertTrue(resolver.permittedDomains(for: .futureSharedTier1).isEmpty, "BLOCKED")
        XCTAssertEqual(ProfileAwareItemGroupingPolicyV2.frozenTier0.revision, "item-grouping-policy-v2-extension-tier0",
                       "frozen Tier-0 grouping policy revision unchanged")
        XCTAssertEqual(ProfileAwareItemGroupingPolicyV2.frozenTier0.profileName, "EXTENSION_FAST_TIER0")
    }

    // ───────────── S12/S15: release logging + privacy posture ─────────────

    func testA9_17_ReleaseHygieneNoUngatedPrintNoNetworking() throws {
        let root = repoRoot().appendingPathComponent("packages/GuardianKit/Sources")
        let fm = FileManager.default
        var ungatedPrints: [String] = [], networking: [String] = []
        let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil)!
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for (n, line) in text.components(separatedBy: "\n").enumerated() {
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.hasPrefix("//") else { continue }
                // standalone print( — not fingerprint(/footprint( etc.
                if let r = t.range(of: "print(") {
                    let before = t[..<r.lowerBound]
                    let prev = before.last
                    if prev == nil || !(prev!.isLetter || prev! == "_" || prev! == ".") {
                        ungatedPrints.append("\(url.lastPathComponent):\(n + 1)")
                    }
                }
                for token in ["URLSession", "URLRequest", "NWConnection", "CFSocket"] {
                    if t.contains(token) { networking.append("\(url.lastPathComponent):\(n + 1):\(token)") }
                }
            }
        }
        XCTAssertEqual(ungatedPrints, [], "production GuardianKit sources must contain no ungated print — release logging OFF")
        XCTAssertEqual(networking, [], "GuardianKit must contain no networking primitives — no telemetry/upload path exists")
    }

    // ───────────── S9: aggregation masking (slice truth; Simpson check) ─────────────

    func testA9_18_SliceAggregationMaskingAndProtectLabelLaw() {
        // per-locale and per-profile CAL slices printed (underpowered — recorded, not hidden)
        for loc in ["tr", "en"] {
            var errs: [Double] = []
            for r in rows9(.calibration) where r.pair.annotation.locale == loc {
                let c = engine9().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: loc)
                if let s = c.score { errs.append(abs(s / 25.0 - Double(r.pair.annotation.finalLabel))) }
            }
            let mae = errs.isEmpty ? -1 : errs.reduce(0, +) / Double(errs.count)
            print("AUDIT9_SLICE locale=\(loc) n=\(errs.count) mae=\(String(format: "%.3f", mae))")
            XCTAssertFalse(errs.isEmpty, "both locale slices must be populated on CAL")
        }
        // Simpson-type guard: the aggregate may not hide a protect-label failure in ANY slice —
        // across ALL 59 resolved pairs, a label-0 (protect) pair may never score positive or present positively
        for r in Self.resolved9 where r.pair.annotation.finalLabel == 0 {
            let c = engine9().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
            XCTAssertNotEqual(c.interpretation, "ALIGNED-CANDIDATE", "\(r.pair.itemID): protect-labeled pair presented positively")
            if let s = c.score { XCTAssertLessThan(s, 62.5, "\(r.pair.itemID): protect-labeled pair in the aligned band") }
        }
        // age/Shield slice floors: child-9 pairs never ALIGNED on label ≤1; shield profile honors hard caps
        for r in Self.resolved9 where r.pair.profile.profileID == "parent-child9-tr" && r.pair.annotation.finalLabel <= 1 {
            let c = engine9().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
            XCTAssertNotEqual(c.interpretation, "ALIGNED-CANDIDATE", "\(r.pair.itemID)")
        }
    }
}
