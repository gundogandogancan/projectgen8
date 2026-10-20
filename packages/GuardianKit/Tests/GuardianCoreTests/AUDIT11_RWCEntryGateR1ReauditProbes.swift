import XCTest
import CryptoKit
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT11 — RWC ENTRY GATE R1 — INDEPENDENT CLEAN-SESSION RE-AUDIT PROBES (add-only).
// Auditor: fresh-context independent re-auditor, 2026-10-20 (no builder session knowledge).
// Target: 06b338640925b6e6df4b4acc2a71bd83052f395d
//         (tag gen8-real-world-calibration-entry-gate-r1-audit-candidate, tag object 2627744a…).
// RULES: no existing source/test modified; own fixtures and own independent math — NOT copies of
// the builder R1 tests. Probes that pin a residual/limitation are annotated FINDING A11-*.
// Report: docs/audit/GEN8_RWC_ENTRY_GATE_R1_INDEPENDENT_REAUDIT.md
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class AUDIT11_RWCEntryGateR1ReauditProbes: XCTestCase {

    // ── independent helpers (own names, own fixtures, own math) ──

    private var repoRoot: String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    }

    /// The REAL resolver used by the production harness — the audit drives the ACTUAL entrypoint.
    private func productionResolver(_ pair: CalibrationPairV1) -> P009DPolicyScenarioV1? {
        P009EScoreTests().scenario(for: pair)
    }

    private func ghostPair(item: String, corpus: String, profile: ProfileFixtureV1) -> CalibrationPairV1 {
        CalibrationPairV1(itemID: item, corpus: corpus, profile: profile, split: .calibration,
                          source: .syntheticDerived,
                          annotation: CalibrationAnnotationV1(itemID: item, profileID: profile.profileID,
                                                              locale: "en", labelA: 1, labelB: 1))
    }

    /// Own single-pass ECE/Brier (array-bucket construction — independent of the production code).
    private func a11ECEBrier(_ preds: [Double], _ labels: [Bool], bins: Int = 10) -> (ece: Double, brier: Double) {
        var cnt = [Int](repeating: 0, count: bins)
        var sumP = [Double](repeating: 0, count: bins)
        var sumY = [Double](repeating: 0, count: bins)
        for (p, l) in zip(preds, labels) {
            let b = min(bins - 1, max(0, Int(p * Double(bins))))
            cnt[b] += 1; sumP[b] += p; sumY[b] += l ? 1 : 0
        }
        var ece = 0.0
        for b in 0..<bins where cnt[b] > 0 {
            ece += Double(cnt[b]) / Double(preds.count) * abs(sumP[b] / Double(cnt[b]) - sumY[b] / Double(cnt[b]))
        }
        let brier = zip(preds, labels).reduce(0.0) { $0 + pow($1.0 - ($1.1 ? 1.0 : 0.0), 2) } / Double(preds.count)
        return (ece, brier)
    }

    /// Own AUROC — Mann-Whitney U with tie-averaged ranks (a DIFFERENT algorithm from the
    /// production pairwise-comparison implementation; agreement is therefore real evidence).
    private func a11RankAUROC(_ preds: [Double], _ labels: [Bool]) -> Double? {
        let nPos = labels.filter { $0 }.count, nNeg = labels.count - nPos
        guard nPos > 0, nNeg > 0, preds.count == labels.count else { return nil }
        let order = preds.indices.sorted { preds[$0] < preds[$1] }
        var ranks = [Double](repeating: 0, count: preds.count)
        var i = 0
        while i < order.count {
            var j = i
            while j + 1 < order.count && preds[order[j + 1]] == preds[order[i]] { j += 1 }
            let avgRank = Double(i + j + 2) / 2.0            // 1-based positions i+1 … j+1
            for k in i...j { ranks[order[k]] = avgRank }
            i = j + 1
        }
        let sumRanksPos = zip(ranks, labels).filter { $0.1 }.map { $0.0 }.reduce(0, +)
        let u = sumRanksPos - Double(nPos * (nPos + 1)) / 2.0
        return u / Double(nPos * nNeg)
    }

    /// Own F1 pipeline driver (fresh family name, fresh item band, fresh stimuli).
    private func a11Brain() -> GuardianMetaBrainV2 {
        let b = GuardianMetaBrainV2()
        b.registry.register(VisionExpertV1()); b.registry.register(LanguageOCRExpertV1())
        b.registry.register(SpeechExpertV1()); b.registry.register(AudioEventExpertV1())
        b.registry.register(MusicExpertV1()); b.registry.register(SymbolExpertV1())
        b.registry.register(TemporalExpertV1()); b.registry.register(SafetyEvidenceExpertV1())
        b.registry.register(BenefitEvidenceExpertV1()); b.registry.register(AttentionPressureExpertV1())
        return b
    }
    private func a11Verdict(_ text: String, lang: String, risk: Double,
                            child: GuardianEnteredChildProfileV1?,
                            parent: ParentPreferencePolicyV1 = ParentPreferencePolicyV1(),
                            item: UInt64) -> AdmissionStateCandidateV1 {
        let seg = [P009CSegmentV1(startMs: 0, endMs: 2000,
                                  input: ExpertInputV2(ocrText: text, detectedLanguage: lang),
                                  temporalRisk: risk, temporalTopics: ["a11"])]
        let sc = P009DPolicyScenarioV1(name: "a11-\(item)", family: "audit11", segments: seg,
                                       childProfile: child, parentPreference: parent,
                                       shieldConfig: nil, annotation: P009DPolicyAnnotationV1())
        return P009DPolicyCorpusV1.run(sc, brain: a11Brain(), item: ContentItemID(item)).1
    }

    /// Ensure the LIVE production harness preparation has run (selection-order independent).
    private func ensureLiveHarness() {
        if P009EScoreTests.pairResults.isEmpty && P009EScoreTests.integrityRefusal == nil {
            P009EScoreTests.setUp()
        }
    }

    // ═════════ (1) current canonical calibration path cannot silent-drop ═════════

    /// Two REAL registry pairs made unresolvable → the ACTUAL entrypoint refuses with BOTH composite
    /// IDs named (sorted) and ZERO records escape — the silent-drop shape is unreachable.
    func testA11_01_CanonicalPath_TwoVictims_NothingEscapes() {
        let pairs = CalibrationDatasetRegistryV2.pairs
        let victims = Set([CalibrationRunPreparationV1.compositeID(pairs[11]),
                           CalibrationRunPreparationV1.compositeID(pairs[42])])
        var escaped = -1
        do {
            let r = try CalibrationRunPreparationV1.prepare(declared: pairs) { p in
                victims.contains(CalibrationRunPreparationV1.compositeID(p)) ? nil : self.productionResolver(p)
            }
            escaped = r.count
            XCTFail("57/59 resolution MUST refuse — got \(r.count) records")
        } catch let e as CalibrationIntegrityErrorV1 {
            guard case let .unresolvedPairs(d, r, ids, cat) = e else { return XCTFail("wrong case \(e)") }
            XCTAssertEqual(d, 59); XCTAssertEqual(r, 57)
            XCTAssertEqual(ids, victims.sorted(), "every victim named, deterministically sorted")
            XCTAssertEqual(cat, "scenario-resolution")
        } catch { XCTFail("typed CalibrationIntegrityErrorV1 required, got \(error)") }
        XCTAssertEqual(escaped, -1, "no resolved-record array may escape a partial resolution")
    }

    // ═════════ (2) same-count identity substitution ═════════

    func testA11_02_SameCountSubstitution_CaseAndLookalike_Refused() {
        // plain substitution, equal counts
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["n1", "n2", "n3", "n4"], resolvedIDs: ["n1", "n2", "n3", "n9"])) { e in
            guard case let .unresolvedPairs(4, 4, ids, _)? = e as? CalibrationIntegrityErrorV1
            else { return XCTFail("typed unresolvedPairs required") }
            XCTAssertEqual(ids, ["n4"], "missing named; equal count cannot cancel")
        }
        // case substitution: identity is case-sensitive by contract (no invented normalization)
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["CASE"], resolvedIDs: ["case"])) { e in
            guard case let .unresolvedPairs(_, _, ids, _)? = e as? CalibrationIntegrityErrorV1
            else { return XCTFail() }
            XCTAssertEqual(ids, ["CASE"])
        }
        // Cyrillic lookalike substitution (U+0430 'а' vs Latin 'a') — distinct identities, refused
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["\u{0430}xe"], resolvedIDs: ["axe"])) { e in
            guard case let .unresolvedPairs(_, _, ids, _)? = e as? CalibrationIntegrityErrorV1
            else { return XCTFail() }
            XCTAssertEqual(ids, ["\u{0430}xe"], "lookalike cannot impersonate the declared identity")
        }
    }

    // ═════════ (3) duplicate-declared attack through the REAL pipeline ═════════

    func testA11_03_DuplicateDeclared_RealLedger_Refused() {
        let pairs = CalibrationDatasetRegistryV2.pairs
        let dupLedger = pairs + [pairs[pairs.count - 1]]                  // duplicate the LAST real pair
        let dupID = CalibrationRunPreparationV1.compositeID(pairs[pairs.count - 1])
        XCTAssertThrowsError(try CalibrationRunPreparationV1.prepare(declared: dupLedger,
                                                                     resolve: productionResolver)) { e in
            XCTAssertEqual(e as? CalibrationIntegrityErrorV1,
                           .duplicateDeclaredIDs(ids: [dupID], category: "scenario-resolution"),
                           "a duplicated declared pair is a typed integrity failure, not data")
        }
    }

    // ═════════ (4) duplicate-resolved attack ═════════

    func testA11_04_DuplicateResolved_Refused() {
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["m1", "m2", "m3"], resolvedIDs: ["m1", "m2", "m2"])) { e in
            XCTAssertEqual(e as? CalibrationIntegrityErrorV1,
                           .duplicateResolvedIDs(ids: ["m2"], category: "scenario-resolution"))
        }
    }

    // ═════════ (5) compound identity errors — deterministic precedence, all refused ═════════

    /// Claimed precedence: malformed → duplicateDeclared → duplicateResolved → missing → extra.
    /// More important than the order: NO compound-invalid dataset reaches fit under ANY error.
    func testA11_05_CompoundErrors_DeterministicPrecedence_AllRefused() {
        // malformed + duplicate declared → malformed wins
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: [" ", "x", "x"], resolvedIDs: ["x"])) { e in
            XCTAssertEqual(e as? CalibrationIntegrityErrorV1,
                           .malformedIDs(declared: 1, resolved: 0, category: "scenario-resolution"))
        }
        // duplicate declared + missing → duplicateDeclared wins
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["d", "d", "e"], resolvedIDs: ["e"])) { e in
            XCTAssertEqual(e as? CalibrationIntegrityErrorV1,
                           .duplicateDeclaredIDs(ids: ["d"], category: "scenario-resolution"))
        }
        // duplicate resolved + unexpected extra → duplicateResolved wins
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["p", "q"], resolvedIDs: ["p", "q", "r", "r"])) { e in
            XCTAssertEqual(e as? CalibrationIntegrityErrorV1,
                           .duplicateResolvedIDs(ids: ["r"], category: "scenario-resolution"))
        }
        // missing + extra (the substitution compound) → missing wins (the safety-relevant class)
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["p", "q"], resolvedIDs: ["p", "z"])) { e in
            guard case let .unresolvedPairs(2, 2, ids, _)? = e as? CalibrationIntegrityErrorV1
            else { return XCTFail() }
            XCTAssertEqual(ids, ["q"])
        }
        // extra alone (everything declared resolved) → unexpectedResolvedIDs
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["p"], resolvedIDs: ["p", "z"])) { e in
            XCTAssertEqual(e as? CalibrationIntegrityErrorV1,
                           .unexpectedResolvedIDs(ids: ["z"], category: "scenario-resolution"))
        }
        // determinism: the same compound input always yields the SAME typed error (3 repeats)
        for _ in 0..<3 {
            XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
                declaredIDs: [" ", "d", "d"], resolvedIDs: ["zz", "zz"])) { e in
                XCTAssertEqual(e as? CalibrationIntegrityErrorV1,
                               .malformedIDs(declared: 1, resolved: 0, category: "scenario-resolution"))
            }
        }
    }

    // ═════════ (6) malformed identity — charset truth characterized, not assumed ═════════

    func testA11_06_MalformedIdentity_CharsetTruth() {
        for bad in ["", " ", "\t", "\u{00A0}"] {
            XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
                declaredIDs: [bad, "ok"], resolvedIDs: ["ok"]),
                "whitespace-class ID \(bad.unicodeScalars.map { $0.value }) must be malformed") { e in
                guard case .malformedIDs? = e as? CalibrationIntegrityErrorV1
                else { return XCTFail("malformed typed error required") }
            }
        }
        // CHARACTERIZATION (A11-F2-IDCHARSET candidate): the malformed law trims CharacterSet.whitespaces
        // (space/tab/Zs) — NEWLINE is not in that set. Determine the actual behavior and assert the
        // guard is CONSISTENT with the charset truth either way; record the measured direction.
        let newlineIsMalformedByCharset = "\n".trimmingCharacters(in: .whitespaces).isEmpty
        var threwMalformed = false, accepted = false
        do {
            try CalibrationRunGuardV1.requireFullResolution(declaredIDs: ["\n"], resolvedIDs: ["\n"])
            accepted = true
        } catch let e as CalibrationIntegrityErrorV1 {
            if case .malformedIDs = e { threwMalformed = true }
        } catch {}
        XCTAssertEqual(threwMalformed, newlineIsMalformedByCharset,
                       "guard behavior must match its own charset law (no hidden path)")
        XCTAssertEqual(accepted, !newlineIsMalformedByCharset)
        print("AUDIT11_IDCHARSET newlineOnlyID malformedCaught=\(threwMalformed) accepted=\(accepted) (characterized)")
        // even if a control-character ID is accepted as 'well-formed', exact identity still binds it:
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["\nghost"], resolvedIDs: ["ghost"]), "control-char identity cannot be substituted")
    }

    // ═════════ (7) real-registry unresolved injection at the ACTUAL entrypoint ═════════

    func testA11_07_RealRegistry_GhostInjection_Refused() {
        let ghost = ghostPair(item: "a11-ghost-item", corpus: "P009B_CAL_RESERVED", profile: .parentTeen14TR)
        XCTAssertThrowsError(try CalibrationRunPreparationV1.prepare(
            declared: CalibrationDatasetRegistryV2.pairs + [ghost], resolve: productionResolver)) { e in
            guard case let .unresolvedPairs(60, 59, ids, _)? = e as? CalibrationIntegrityErrorV1
            else { return XCTFail("typed unresolvedPairs required") }
            XCTAssertEqual(ids, ["a11-ghost-item#parent-teen14-tr"])
        }
    }

    // ═════════ (8) strict MAE — independent rubric-domain fixture ═════════

    func testA11_08_MAEStrict_RubricDomain_IndependentFixture() throws {
        // hand-computed: |0−1| + |4−3| + |2.5−2.5| + |1−0| = 3 → /4 = 0.75 (both arrays inside 0…4,
        // boundaries 0 and 4 EXACT — valid inclusive)
        XCTAssertEqual(try CalibrationMetricsV1.maeStrict([0.0, 4.0, 2.5, 1.0], [1.0, 3.0, 2.5, 0.0],
                                                          domain: 0...4), 0.75, accuracy: 1e-12)
        // below / above the rubric domain — typed outOfDomain with the right index
        XCTAssertThrowsError(try CalibrationMetricsV1.maeStrict([2.0, -0.25], [1.0, 1.0], domain: 0...4)) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .outOfDomain(index: 1, value: -0.25))
        }
        XCTAssertThrowsError(try CalibrationMetricsV1.maeStrict([2.0], [4.0 + 1e-9], domain: 0...4)) { e in
            guard case .outOfDomain(let i, _)? = e as? MetricInputErrorV1 else { return XCTFail() }
            XCTAssertEqual(i, 0)
        }
        // non-finite — typed, in either array
        XCTAssertThrowsError(try CalibrationMetricsV1.maeStrict([Double.nan], [1.0], domain: 0...4)) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .nonFinite(index: 0))
        }
        XCTAssertThrowsError(try CalibrationMetricsV1.maeStrict([1.0], [.infinity], domain: 0...4))
        XCTAssertThrowsError(try CalibrationMetricsV1.maeStrict([1.0], [-.infinity], domain: 0...4))
        // shape mismatch + empty — typed
        XCTAssertThrowsError(try CalibrationMetricsV1.maeStrict([1.0, 2.0], [1.0], domain: 0...4)) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .shapeMismatch(preds: 2, labels: 1))
        }
        XCTAssertThrowsError(try CalibrationMetricsV1.maeStrict([], [], domain: 0...4)) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .emptyInput)
        }
        // domain is EXPLICIT, not global: 3.7 is lawful rubric, unlawful probability — NO silent
        // regression forcing every MAE call into 0…1
        XCTAssertEqual(try CalibrationMetricsV1.maeStrict([3.7], [3.7], domain: 0...4), 0, accuracy: 1e-15)
        XCTAssertThrowsError(try CalibrationMetricsV1.maeStrict([3.7], [3.7]), "default domain stays 0…1")
    }

    // ═════════ (9) strict AUROC vs independent rank-based math ═════════

    func testA11_09_AUROCStrict_IndependentRankMath() throws {
        // perfect separation / perfect inversion
        XCTAssertEqual(try CalibrationMetricsV1.aurocStrict(preds: [0.95, 0.85, 0.15, 0.05],
                                                            labels: [true, true, false, false]), 1.0, accuracy: 1e-12)
        XCTAssertEqual(try CalibrationMetricsV1.aurocStrict(preds: [0.9, 0.1],
                                                            labels: [false, true]), 0.0, accuracy: 1e-12)
        // one positive / one negative
        XCTAssertEqual(try CalibrationMetricsV1.aurocStrict(preds: [0.3, 0.7],
                                                            labels: [false, true]), 1.0, accuracy: 1e-12)
        // asymmetric mixed fixture — Mann-Whitney rank AUROC must agree with the production
        // pairwise implementation exactly (two independent algorithms)
        let preds = [0.15, 0.25, 0.35, 0.45, 0.60, 0.70, 0.80, 0.95]
        let labels = [false, false, true, false, true, false, true, true]
        let mine = a11RankAUROC(preds, labels)!
        XCTAssertEqual(try CalibrationMetricsV1.aurocStrict(preds: preds, labels: labels), mine, accuracy: 1e-12)
        // invalid domains — typed
        for bad in [Double.nan, .infinity, -.infinity, -1e-9, 1.0 + 1e-9] {
            XCTAssertThrowsError(try CalibrationMetricsV1.aurocStrict(preds: [0.4, bad],
                                                                      labels: [false, true]), "\(bad)") { e in
                XCTAssertTrue(e is MetricInputErrorV1)
            }
        }
        // shape + empty — typed
        XCTAssertThrowsError(try CalibrationMetricsV1.aurocStrict(preds: [0.4, 0.5], labels: [true])) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .shapeMismatch(preds: 2, labels: 1))
        }
        XCTAssertThrowsError(try CalibrationMetricsV1.aurocStrict(preds: [], labels: [])) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .emptyInput)
        }
    }

    // ═════════ (10) AUROC ties and degenerate labels ═════════

    func testA11_10_AUROC_TiesAndDegenerate() throws {
        // complete ties: every pair scores 0.5 → AUROC exactly 0.5; rank math agrees
        let flat = [0.5, 0.5, 0.5, 0.5], flatL = [true, false, true, false]
        XCTAssertEqual(try CalibrationMetricsV1.aurocStrict(preds: flat, labels: flatL), 0.5, accuracy: 1e-12)
        XCTAssertEqual(a11RankAUROC(flat, flatL)!, 0.5, accuracy: 1e-12)
        // partial ties — hand-computed: pos {0.8, 0.4}, neg {0.4, 0.2} → pairs:
        // (0.8>0.4)=1, (0.8>0.2)=1, (0.4==0.4)=0.5, (0.4>0.2)=1 → 3.5/4 = 0.875
        let pt = [0.8, 0.4, 0.4, 0.2], ptL = [true, true, false, false]
        XCTAssertEqual(try CalibrationMetricsV1.aurocStrict(preds: pt, labels: ptL), 0.875, accuracy: 1e-12)
        XCTAssertEqual(a11RankAUROC(pt, ptL)!, 0.875, accuracy: 1e-12)
        // degenerate: all positive / all negative — typed refusal, metric undefined
        XCTAssertThrowsError(try CalibrationMetricsV1.aurocStrict(preds: [0.1, 0.9],
                                                                  labels: [true, true])) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .degenerateLabels(positives: 2, negatives: 0))
        }
        XCTAssertThrowsError(try CalibrationMetricsV1.aurocStrict(preds: [0.1, 0.9],
                                                                  labels: [false, false])) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .degenerateLabels(positives: 0, negatives: 2))
        }
    }

    // ═════════ (11) legacy signatures — invalid input NEVER yields a plausible finite result ═════════

    func testA11_11_LegacyMarkers_And_P008PilotSiblings_Characterized() {
        // V1 legacy mae: NaN marker on non-finite and on shape mismatch (never a truncated average)
        XCTAssertTrue(CalibrationMetricsV1.mae([0.2, Double.nan], [0.2, 0.2]).isNaN)
        XCTAssertTrue(CalibrationMetricsV1.mae([.infinity, 0.1], [0.1, 0.1]).isNaN)
        XCTAssertTrue(CalibrationMetricsV1.mae([0.1, 0.2, 0.3], [0.1]).isNaN, "shape mismatch refused via marker")
        // V1 legacy mae intentionally has NO domain bound (caller-defined scale on the legacy path):
        XCTAssertEqual(CalibrationMetricsV1.mae([5.0], [3.0]), 2.0, accuracy: 1e-12,
                       "legacy mae is finite-checked only — domain law lives in maeStrict (documented)")
        // V1 legacy auroc: nil undefined-channel — never a finite miscount
        XCTAssertNil(CalibrationMetricsV1.auroc(preds: [0.4, Double.nan], labels: [false, true]))
        XCTAssertNil(CalibrationMetricsV1.auroc(preds: [0.4, 1.0001], labels: [false, true]))
        XCTAssertNil(CalibrationMetricsV1.auroc(preds: [0.4], labels: [false, true]))
        // V1 legacy eceAndBins: NaN marker + empty bins on domain violation
        let m = CalibrationMetricsV1.eceAndBins(preds: [0.2, -0.2], labels: [false, true])
        XCTAssertTrue(m.ece.isNaN && m.brier.isNaN && m.bins.isEmpty)
        // ── FINDING A11-LEGACY-P008 (LOW, pinned; disclosed by builder in the R1 report §2 residual):
        // the PRE-P009E pilot metrics (enum CalibrationMetrics, CalibrationMetrics.swift) were NOT
        // hardened: mae truncates to min(count) — a silent shape-mismatch tolerance — and ece silently
        // excludes NaN confidences from every bin while dividing by the full n (finite plausible value).
        // Only caller today: CalibrationPilotRunner (P008A LAB pilot; outside the canonical P009E
        // calibration pipeline; sole consumer is P008ACoreTests). Must be hardened or retired before
        // any real-corpus use. Characterized here so the residual can never close silently:
        let truncated = CalibrationMetrics.mae(predicted: [0.9, 0.1], truth: [0.9])
        XCTAssertEqual(truncated, 0.0, accuracy: 1e-12,
            "FINDING A11-LEGACY-P008: pilot mae truncates to min(count) — if this now fails, the legacy " +
            "pilot metrics were hardened: re-audit and retire the finding via the inversion discipline")
        let nanECE = CalibrationMetrics.ece(confidences: [Double.nan, 0.9], correct: [true, true], bins: 10)
        XCTAssertTrue(nanECE.isFinite,
            "FINDING A11-LEGACY-P008: pilot ece silently drops NaN from bins yet stays finite-plausible")
        XCTAssertEqual(nanECE, 0.05, accuracy: 1e-12, "measured shape of the silent exclusion")
        print("AUDIT11_LEGACY_P008 pilotMAETruncated=\(truncated) pilotECEWithNaN=\(nanECE) (pinned)")
    }

    // ═════════ (12) historical metrics — INDEPENDENT recomputation (own math, live artefacts) ═════════

    func testA11_12_HistoricalMetrics_IndependentRecomputation() throws {
        ensureLiveHarness()
        XCTAssertNil(P009EScoreTests.integrityRefusal, "live harness must have passed the canonical gate")
        XCTAssertEqual(P009EScoreTests.pairResults.count, 59)
        let engine = PersonalSuitabilityScoreV2.EngineV1(registry: P009EScoreTests.fittedRegistry,
                                                         fusion: P009EScoreTests.fittedFusion)
        // TRAIN MAE — the fitted fusion artefact itself
        XCTAssertEqual(String(format: "%.3f", P009EScoreTests.fittedFusion.trainMAE), "0.628",
                       "TRAIN MAE drifted — metric hardening must not move valid-input values")
        // own MAE recomputation (plain loop, no production metric API)
        func a11MAE(_ split: CalibrationSplitV1) -> (mae: Double, n: Int, abstained: Int) {
            var absSum = 0.0; var n = 0; var abstained = 0
            for r in P009EScoreTests.pairResults where r.pair.split == split {
                let c = engine.evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile,
                                        locale: r.pair.annotation.locale)
                if let s = c.score { absSum += abs(s / 25.0 - Double(r.pair.annotation.finalLabel)); n += 1 }
                else { abstained += 1 }
            }
            return (absSum / Double(max(n, 1)), n, abstained)
        }
        let cal = a11MAE(.calibration)
        XCTAssertEqual(String(format: "%.3f", cal.mae), "0.743", "CAL MAE reproduced independently")
        XCTAssertEqual(cal.n, 12); XCTAssertEqual(cal.abstained, 0)
        let held = a11MAE(.heldOutFinal)
        XCTAssertEqual(String(format: "%.3f", held.mae), "0.559", "HELD_OUT MAE reproduced independently")
        XCTAssertEqual(held.n, 7); XCTAssertEqual(held.abstained, 1)
        // risk-calibrator reliability on the calibration split — own ECE/Brier/AUROC math
        var preds: [Double] = [], labels: [Bool] = []
        for r in P009EScoreTests.pairResults where r.pair.split == .calibration {
            if let p = P009EScoreTests.fittedRegistry.calibrator(name: "risk", slice: r.pair.annotation.locale)?
                .probability(r.m.maxRiskSeen) {
                preds.append(p); labels.append(r.pair.annotation.finalLabel <= 1)
            }
        }
        XCTAssertFalse(preds.isEmpty)
        let mine = a11ECEBrier(preds, labels)
        XCTAssertEqual(String(format: "%.3f", mine.ece), "0.250", "ECE reproduced by independent math")
        XCTAssertEqual(String(format: "%.3f", mine.brier), "0.139", "Brier reproduced by independent math")
        XCTAssertGreaterThan(mine.ece, 0.05, "ECE target remains UNMET — and must stay UNRELAXED")
        // cross-check against the strict production API (valid inputs: values must be identical)
        let theirs = try CalibrationMetricsV1.eceAndBinsStrict(preds: preds, labels: labels)
        XCTAssertEqual(theirs.ece, mine.ece, accuracy: 1e-12)
        XCTAssertEqual(theirs.brier, mine.brier, accuracy: 1e-12)
        // AUROC via rank math vs production pairwise — then the historical value
        let auroc = a11RankAUROC(preds, labels)!
        XCTAssertEqual(try CalibrationMetricsV1.aurocStrict(preds: preds, labels: labels), auroc, accuracy: 1e-9)
        XCTAssertEqual(String(format: "%.2f", auroc), "0.94", "AUROC reproduced independently")
        XCTAssertEqual(auroc, 0.938, accuracy: 0.02)
        // sentinel false-safe — own loop, harness definition
        var falseSafe = 0, sentinels = 0
        for r in P009EScoreTests.pairResults where r.pair.split == .safetySentinel {
            sentinels += 1
            let c = engine.evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile,
                                    locale: r.pair.annotation.locale)
            let positive = (c.score ?? 0) >= 62.5 && c.interpretation == "ALIGNED-CANDIDATE"
            if positive || (r.d.state == .neutral && r.pair.annotation.finalLabel == 0) { falseSafe += 1 }
        }
        XCTAssertEqual(sentinels, 5); XCTAssertEqual(falseSafe, 0, "sentinel no-false-safe reproduced")
        print("AUDIT11_HISTORICAL train=0.628 cal=\(String(format: "%.3f", cal.mae)) " +
              "held=\(String(format: "%.3f", held.mae)) ece=\(String(format: "%.3f", mine.ece)) " +
              "brier=\(String(format: "%.3f", mine.brier)) auroc=\(String(format: "%.3f", auroc)) falseSafe=\(falseSafe)")
    }

    // ═════════ (13) frozen originals — SHA-256 recomputed from disk by the auditor ═════════

    func testA11_13_FrozenOriginals_SHA256_FromDisk() throws {
        let frozen10 = try Data(contentsOf: URL(fileURLWithPath: repoRoot +
            "/docs/audit/AUDIT10_RealWorldCalibrationEntryGateProbes_ORIGINAL_LOCKED.swift.txt"))
        XCTAssertEqual(SHA256.hash(data: frozen10).map { String(format: "%02x", $0) }.joined(),
                       "a1ffb855cea4af9b9ee83e88e9240982d4df31d5393dac2b5a668c597caf0580",
                       "AUDIT10 frozen original byte-exact (mandate-pinned SHA)")
        let frozen9 = try Data(contentsOf: URL(fileURLWithPath: repoRoot +
            "/docs/audit/AUDIT9_P009ER1Probes_ORIGINAL_LOCKED.swift.txt"))
        XCTAssertEqual(SHA256.hash(data: frozen9).map { String(format: "%02x", $0) }.joined(),
                       "a349a487dc091d444f04939864582175409542f47d6275c6bb0bd8022163bc4e",
                       "AUDIT9 frozen original byte-exact (mandate-pinned SHA)")
    }

    // ═════════ (14) AUDIT10 inversion manifest — exists and pre-declares ALL THREE inversions ═════════

    /// Commit-order proof (manifest BEFORE inversions) is git evidence recorded in the re-audit report:
    /// e2d008d (docs-only, 12:27:12) < 905eab5 (12:28:39) < 1788ef9 (12:30:39) < 6f5f380 (12:32:38).
    func testA11_14_InversionManifest_DeclaresAllThreeInversions() throws {
        let manifest = try String(contentsOfFile: repoRoot + "/docs/audit/AUDIT10_INVERSION_LOCK.md",
                                  encoding: .utf8)
        for required in ["### I-1", "### I-2", "### I-3",
                         "testP08_F2_ProductionCallgraph_GuardIsUnwired_Pinned",
                         "testP10_F2_MultisetDuplicates_PinnedDefect",
                         "testP14_F3_LegacyNaNMarker_And_UnguardedSiblings_Pinned",
                         "a1ffb855cea4af9b9ee83e88e9240982d4df31d5393dac2b5a668c597caf0580",
                         "BEFORE"] {
            XCTAssertTrue(manifest.contains(required), "manifest must declare: \(required)")
        }
        XCTAssertTrue(manifest.contains("nothing else may change in the probe file"),
                      "manifest bounds the migration explicitly")
    }

    // ═════════ (15) bounded inversion — frozen vs active differ ONLY in the 3 declared blocks ═════════

    func testA11_15_BoundedInversion_FrozenVsActive_LineAccounting() throws {
        let frozen = try String(contentsOf: URL(fileURLWithPath: repoRoot +
            "/docs/audit/AUDIT10_RealWorldCalibrationEntryGateProbes_ORIGINAL_LOCKED.swift.txt"),
            encoding: .utf8).components(separatedBy: "\n")
        let active = try String(contentsOfFile: repoRoot +
            "/packages/GuardianKit/Tests/GuardianCoreTests/AUDIT10_RealWorldCalibrationEntryGateProbes.swift",
            encoding: .utf8).components(separatedBy: "\n")
        XCTAssertLessThanOrEqual(abs(frozen.count - active.count), 10, "file shape stays close")
        // counted multiset difference — every differing line must belong to a declared inversion block
        var counts: [String: Int] = [:]
        for l in frozen { counts[l, default: 0] += 1 }
        for l in active { counts[l, default: 0] -= 1 }
        let removed = counts.filter { $0.value > 0 }.map { $0.key }   // only in frozen
        let added = counts.filter { $0.value < 0 }.map { $0.key }     // only in active
        XCTAssertLessThanOrEqual(removed.count, 30, "removal volume bounded")
        XCTAssertLessThanOrEqual(added.count, 30, "addition volume bounded")
        let declaredMarkers = [
            "A10-F2-UNWIRED", "A10-F2-WIRING", "A10-F2-MULTISET", "A10-F3-SIBLINGS",
            "else { continue }", "requireFullResolution", "CalibrationRunPreparationV1",
            "silent-drop control flow", "static truth: the production fit harness",
            "silently excluded from fitting", "set-containment", "duplicate-bearing multisets",
            "cancels out", "XCTAssertTrue(accepted", "XCTAssertFalse(accepted",
            "contract says MUST FAIL", "the defect was fixed", "frozen-original discipline",
            "AUDIT10_F2_MULTISET", "UNGUARDED SIBLING METRICS", "P14 — legacy NaN marker semantics",
            "mae propagates NaN silently", "silently miscounts", "Pinned sibling gaps",
            "mae() silently propagates", "aurocNaN", "auroc() swallows NaN", "not even a NaN marker",
            "AUDIT10_F3_SIBLINGS maeNaN", "inversion pre-declared", "canonical integrity pipeline",
            "silent drop is gone", "composite IDs are unique", "cancellation shapes",
            "explicit NaN marker", "maeStrict", "canonical typed path", "original pinned",
            "SIBLING METRICS"
        ]
        func accounted(_ line: String) -> Bool {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { return true }
            return declaredMarkers.contains { line.contains($0) }
        }
        for l in removed {
            XCTAssertTrue(accounted(l), "UNDECLARED removal outside the three inversion blocks: '\(l)'")
        }
        for l in added {
            XCTAssertTrue(accounted(l), "UNDECLARED addition outside the three inversion blocks: '\(l)'")
        }
    }

    // ═════════ (16) AUDIT9 discipline artefacts — lock, erratum, pointer, single-hunk shape ═════════

    func testA11_16_AUDIT9Discipline_ArtefactsConsistent() throws {
        let lock = try String(contentsOfFile: repoRoot + "/docs/audit/AUDIT9_F3_INVERSION_LOCK.md",
                              encoding: .utf8)
        XCTAssertTrue(lock.contains("a349a487dc091d444f04939864582175409542f47d6275c6bb0bd8022163bc4e"))
        XCTAssertTrue(lock.contains("clamped, never silently dropped"), "original assertion preserved in the lock")
        XCTAssertTrue(lock.contains("A9-R1-F3 FIXED: no silent clamp into the metric"), "changed assertion recorded")
        let notes = try String(contentsOfFile: repoRoot + "/docs/calibration/ENTRY_GATE_LOCK_NOTES.md",
                               encoding: .utf8)
        XCTAssertTrue(notes.contains("AUDIT9_F3_INVERSION_LOCK.md"), "pointer resolved to the canonical lock")
        let erratum = try String(contentsOfFile: repoRoot + "/docs/audit/AUDIT9_FPEDGE_ERRATUM.md",
                                 encoding: .utf8)
        XCTAssertTrue(erratum.contains("rounds DOWN in binary fp"), "original false wording preserved verbatim")
        XCTAssertTrue(erratum.contains("rounds **UP to exactly") || erratum.contains("rounds UP"),
                      "erratum states the measured truth")
        // AUDIT9 active file: still exactly the single declared hunk vs its frozen original (R1 did not touch it)
        let frozen9 = try String(contentsOf: URL(fileURLWithPath: repoRoot +
            "/docs/audit/AUDIT9_P009ER1Probes_ORIGINAL_LOCKED.swift.txt"), encoding: .utf8)
            .components(separatedBy: "\n")
        let active9 = try String(contentsOfFile: repoRoot +
            "/packages/GuardianKit/Tests/GuardianCoreTests/AUDIT9_P009ER1Probes.swift", encoding: .utf8)
            .components(separatedBy: "\n")
        XCTAssertEqual(active9.count - frozen9.count, 2, "net +2 lines — the single declared hunk, nothing more")
        var c9: [String: Int] = [:]
        for l in frozen9 { c9[l, default: 0] += 1 }
        for l in active9 { c9[l, default: 0] -= 1 }
        let rem9 = c9.filter { $0.value > 0 }.map { $0.key }
        XCTAssertEqual(rem9.count, 2, "exactly two original lines replaced")
        XCTAssertTrue(rem9.allSatisfy { $0.contains("clamp") }, "both inside the clamp block: \(rem9)")
    }

    // ═════════ (17) fp-edge runtime truth ═════════

    func testA11_17_FPEdge_RuntimeTruth() throws {
        XCTAssertEqual(0.3 * 10.0, 3.0, "the fp PRODUCT is exactly 3.0 (rounds up)")
        XCTAssertEqual(Int(0.3 * 10.0), 3, "therefore Int(0.3*10.0) == 3 → bin 3")
        for k in 1...9 {
            XCTAssertEqual(Int(Double(k) / 10.0 * 10.0), k, "no k/10 boundary floors down at bins=10 (k=\(k))")
        }
        // behavioral confirmation through the strict metric: a lone 0.3 lands in ONE bin with meanPred 0.3
        let r = try CalibrationMetricsV1.eceAndBinsStrict(preds: [0.3], labels: [false])
        XCTAssertEqual(r.bins.count, 1)
        XCTAssertEqual(r.bins[0].meanPred, 0.3, accuracy: 1e-15)
        XCTAssertEqual(r.bins[0].count, 1, "exactly once — deterministic assignment")
        // the LIVING source must carry the corrected statement, not the refuted one
        let living = try String(contentsOfFile: repoRoot +
            "/packages/GuardianKit/Sources/GuardianCore/CalibrationIntegrityV1.swift", encoding: .utf8)
        XCTAssertFalse(living.contains("rounds DOWN"), "refuted claim absent from the living source")
        XCTAssertTrue(living.contains("rounds UP to exactly 3.0"), "corrected claim present")
    }

    // ═════════ (18) F1 — limitation honestly preserved (fresh stimuli, not builder fixtures) ═════════

    func testA11_18_F1_CoverageLimitation_PreservedNotHidden() {
        // (a) covered cue still fail-closed reviewed at strong risk (law intact)
        let covered = a11Verdict("massacre survivors interviewed on camera", lang: "en", risk: 0.85,
                                 child: GuardianEnteredChildProfileV1(ageYears: 14, jurisdictionCode: "TR",
                                                                      enteredByGuardian: true), item: 91_001)
        XCTAssertEqual(covered.childOutcome, .unknownReview, "covered violence cue: never AGE_ALIGNED")
        XCTAssertEqual(covered.state, .strongProtection, "strong risk keeps universal protection")
        // (b) FRESH uncovered paraphrases: limitation must still be OPEN (component-level alignable),
        // while end-to-end strong-risk protection holds (no false-safe) — exactly the AUDIT10 pin
        var componentAligned = 0
        var item: UInt64 = 91_100
        for (text, lang) in [("slaughter in the village square footage", "en"),
                             ("bloodshed on the streets after dark", "en"),
                             ("ölümcül saldırı anları kamerada", "tr")] {
            item += 1
            let d = a11Verdict(text, lang: lang, risk: 0.9,
                               child: GuardianEnteredChildProfileV1(ageYears: 14, jurisdictionCode: "TR",
                                                                    enteredByGuardian: true), item: item)
            XCTAssertEqual(d.state, .strongProtection, "'\(text)': END-TO-END protection must hold (no false-safe)")
            if d.childOutcome == .aligned { componentAligned += 1 }
        }
        XCTAssertGreaterThan(componentAligned, 0,
            "CARRIED LIMITATION A10-F1-COVERAGE: fresh uncovered paraphrases still component-ALIGN — " +
            "if this now fails, coverage changed silently and must be re-audited (never silently closed)")
        // (c) benign cue false-trigger characterization still holds (doctrine-consistent over-restriction)
        let benign = a11Verdict("savaş belgeseli tanıtımı: lise tarih kulübü", lang: "tr", risk: 0.0,
                                child: GuardianEnteredChildProfileV1(ageYears: 15, jurisdictionCode: "TR",
                                                                     enteredByGuardian: true), item: 91_200)
        XCTAssertEqual(benign.childOutcome, .unknownReview, "cue-only teen review (A10-F1-FALSETRIGGER carried)")
        XCTAssertNotEqual(benign.state, .strongProtection, "benign content never escalates the global state")
        // (d) adult with the same benign text: routing lexicon is not detection
        let adult = a11Verdict("savaş belgeseli tanıtımı: lise tarih kulübü", lang: "tr", risk: 0.0,
                               child: nil, item: 91_201)
        XCTAssertNil(adult.childOutcome)
        XCTAssertNotEqual(adult.state, .strongProtection)
        print("AUDIT11_F1 coverage componentAlignedFreshMisses=\(componentAligned)/3 (limitation OPEN, carried)")
    }

    // ═════════ (19) production score remains structurally blocked ═════════

    func testA11_19_ProductionScore_StructurallyBlocked() {
        let (open, conditions) = ProductionScoreReleaseGateV1.evaluate()
        XCTAssertFalse(open, "production score release gate CLOSED")
        XCTAssertEqual(conditions.count, 10)
        XCTAssertGreaterThanOrEqual(conditions.filter { !$0.met }.count, 4, "multiple conditions honestly unmet")
        XCTAssertFalse(conditions.first { $0.name.contains("rights-clear") }!.met)
        XCTAssertFalse(conditions.first { $0.name.contains("independent") }!.met)
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertFalse(GuardianMetaBrainV2().calibration.scoreDisplayAllowed(), "P009B skeleton still refusing")
    }

    // ═════════ (20) no real-data / fitting artefacts ═════════

    func testA11_20_NoRealDataArtefacts() {
        let pairs = CalibrationDatasetRegistryV2.pairs
        XCTAssertEqual(pairs.count, 59, "ledger did not grow — no corpus work happened")
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims,
                       "zero PROJECT_OWNED_REAL / LICENSED items — real-world claims structurally impossible")
        let classes = Set(pairs.map { $0.source })
        XCTAssertTrue(classes.isSubset(of: [.syntheticDerived, .structuralOnly]),
                      "only SYNTHETIC_DERIVED / STRUCTURAL_ONLY classes present: \(classes)")
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertTrue(CalibrationDatasetRegistryV2.itemSplitViolations.isEmpty, "split hygiene intact")
        XCTAssertEqual(pairs.filter { $0.split == .trainTune }.count, 26)
        XCTAssertEqual(pairs.filter { $0.split == .calibration }.count, 12)
        XCTAssertEqual(pairs.filter { $0.split == .heldOutFinal }.count, 8)
        XCTAssertEqual(pairs.filter { $0.split == .safetySentinel }.count, 5)
    }

    // ═════════ (21) empty-ledger contract — determined, not assumed ═════════

    /// Contract truth: the guard accepts []/[] VACUOUSLY (nothing declared, nothing missing) — but no
    /// metric or fitted model can be produced from an empty run: fit abstains, strict metrics refuse.
    func testA11_21_EmptyLedger_VacuousGate_NoMetricDownstream() throws {
        XCTAssertNoThrow(try CalibrationRunGuardV1.requireFullResolution(declaredIDs: [], resolvedIDs: []))
        let records = try CalibrationRunPreparationV1.prepare(declared: []) { _ -> Int? in 1 }
        XCTAssertTrue(records.isEmpty, "empty declared → empty records (vacuous acceptance, documented)")
        XCTAssertFalse(SuitabilityFusionModelV1.fit(features: [], targets: []).fitted,
                       "fusion fit abstains on empty input")
        XCTAssertFalse(DimensionCalibratorV1.fit(name: "a11", slice: "en", xs: [], ys: []).fitted,
                       "dimension calibrator abstains on empty input")
        XCTAssertThrowsError(try CalibrationMetricsV1.maeStrict([], [], domain: 0...4),
                             "no MAE exists for an empty run")
        XCTAssertThrowsError(try CalibrationMetricsV1.aurocStrict(preds: [], labels: []),
                             "no AUROC exists for an empty run")
    }

    // ═════════ (22) composite-ID separator ambiguity — fail-closed, pinned ═════════

    /// FINDING A11-F2-COMPOSITE-ALIAS (INFO, pinned): `itemID#profileID` does not escape '#', so two
    /// DISTINCT pairs can alias to one composite string. Today this collapses to a duplicate-declared
    /// TYPED REFUSAL (fail-closed — no silent aliasing is possible through the canonical door), but the
    /// future real-corpus ID contract must forbid '#' in opaque asset IDs (constitution R1 addendum).
    func testA11_22_CompositeIDSeparatorAmbiguity_FailsClosed() {
        let crafted = ProfileFixtureV1(profileID: "x#adult-neutral", childProfile: nil,
                                       parentPreference: ParentPreferencePolicyV1(), shieldConfig: nil)
        let p1 = ghostPair(item: "amb#x", corpus: "P009D", profile: .adultNeutral)
        let p2 = ghostPair(item: "amb", corpus: "P009D", profile: crafted)
        XCTAssertEqual(CalibrationRunPreparationV1.compositeID(p1),
                       CalibrationRunPreparationV1.compositeID(p2),
                       "FINDING A11-F2-COMPOSITE-ALIAS: distinct pairs alias to one composite ID")
        XCTAssertThrowsError(try CalibrationRunPreparationV1.prepare(declared: [p1, p2]) { _ -> Int? in 1 }) { e in
            guard case .duplicateDeclaredIDs? = e as? CalibrationIntegrityErrorV1
            else { return XCTFail("aliasing must surface as a typed duplicate refusal (fail-closed)") }
        }
    }

    // ═════════ (23) unicode identity semantics — documented, not invented ═════════

    /// Contract note: Swift String equality is CANONICAL equivalence — NFC and NFD spellings of the
    /// same text are ONE identity (consistent on both sides, no substitution window). Confusable but
    /// canonically distinct scripts stay distinct (see testA11_02). Opaque ASCII IDs (constitution R1
    /// addendum) make this moot for real corpora; recorded here as measured truth.
    func testA11_23_UnicodeCanonicalEquivalence_Characterized() throws {
        let nfc = "caf\u{00E9}#p", nfd = "cafe\u{0301}#p"
        XCTAssertEqual(nfc, nfd, "Swift canonical equivalence (measured, not assumed)")
        XCTAssertNoThrow(try CalibrationRunGuardV1.requireFullResolution(declaredIDs: [nfc], resolvedIDs: [nfd]),
                         "NFC declared / NFD resolved: one identity under canonical equivalence — accepted")
        print("AUDIT11_UNICODE nfc==nfd:\(nfc == nfd) (canonical equivalence contract documented)")
    }

    // ═════════ (24) wiring truth from source — prepare precedes fit; silent drop absent ═════════

    func testA11_24_HarnessWiring_SourceOrderTruth() throws {
        let src = try String(contentsOfFile: repoRoot +
            "/packages/GuardianKit/Tests/GuardianCoreTests/P009EScoreTests.swift", encoding: .utf8)
        XCTAssertFalse(src.contains("else { continue }"), "the silent-drop construction is gone")
        guard let prep = src.range(of: "CalibrationRunPreparationV1.prepare"),
              let fit = src.range(of: "SuitabilityFusionModelV1.fit(features: feats") else {
            return XCTFail("harness must contain BOTH the canonical prepare call and the fit call")
        }
        XCTAssertLessThan(prep.lowerBound, fit.lowerBound, "DECLARED→GATE strictly precedes FIT in the harness")
        // the canonical preparation source itself calls the hardened guard
        let prepSrc = try String(contentsOfFile: repoRoot +
            "/packages/GuardianKit/Sources/GuardianCore/CalibrationRunPreparationV1.swift", encoding: .utf8)
        XCTAssertTrue(prepSrc.contains("requireFullResolution"), "prepare routes through the integrity gate")
        XCTAssertTrue(prepSrc.contains("return records"),
                      "records are returned only after the gate call (throw aborts before return)")
        // and the LIVE harness went through it
        ensureLiveHarness()
        XCTAssertNil(P009EScoreTests.integrityRefusal)
        XCTAssertEqual(P009EScoreTests.pairResults.count, CalibrationDatasetRegistryV2.pairs.count)
    }

    // ═════════ (25) API-level bypass — structural scope limitation, pinned ═════════

    /// SCOPE LIMITATION A11-F2-APIBYPASS (pinned; disclosed by the builder as residual risk): Swift
    /// cannot forbid a FUTURE rogue caller from invoking DimensionCalibratorV1.fit /
    /// SuitabilityFusionModelV1.fit directly on partial data. The CURRENT canonical execution path is
    /// gated (testA11_24); enforcement for future executors is convention + re-audit call-graph scans.
    /// This probe keeps the limitation visible so it can never close silently.
    func testA11_25_DirectFitAPIs_RemainCallable_ScopeLimitationPinned() {
        let xs = (0..<12).map { Double($0) / 12.0 }
        let ys = (0..<12).map { $0 % 2 == 0 }
        let rogue = DimensionCalibratorV1.fit(name: "a11-rogue", slice: "en", xs: xs, ys: ys)
        XCTAssertTrue(rogue.fitted,
            "SCOPE LIMITATION A11-F2-APIBYPASS: fit APIs are directly callable without the gate — " +
            "if this now fails, the API contract changed and must be re-audited")
        let feats = (0..<10).map { [Double($0) / 10.0, 0.5, 0.2, 0.0, 0.0] }
        let rogueFusion = SuitabilityFusionModelV1.fit(features: feats, targets: (0..<10).map { Double($0 % 5) })
        XCTAssertTrue(rogueFusion.fitted, "fusion fit also directly callable (same limitation)")
        print("AUDIT11_APIBYPASS directFitCallable=true (structural scope limitation — carried)")
    }
}
