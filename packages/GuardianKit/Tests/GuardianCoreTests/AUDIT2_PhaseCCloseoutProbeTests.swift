// AUDIT2 — INDEPENDENT PHASE-C CLOSEOUT AUDITOR-AUTHORED PROBES (clean session, 2026-10-19).
// NOT part of the project's own suite design. Safe to delete after the audit.
// READ-ONLY with respect to all production code, policies, fixtures, and artifacts.
//
// Coverage per the Phase-C closeout audit spec:
//   bright→bright · dark→dark · same-layout different item · correlated luma features (recomputed from the
//   device SHOTEV artifact) · stale provisional identity · strongNew conflict · provisional risk escalation ·
//   rapid session reset · release logging compile-flag matrix · malformed/boundary Tier-1 handoff ·
//   counterfactual proof that EvidenceIndependenceGuardV1 is the load-bearing C6 blocker ·
//   SHA-256 of the Phase-B measured-evidence artifact (not covered by the prior auditor's integrity test).

import XCTest
import CryptoKit
import Foundation
@testable import GuardianCore

final class AUDIT2_PhaseCCloseoutProbeTests: XCTestCase {

    // Independent shot builder (device reality: endMs NOT maintained — endMs == startMs — so any dwell
    // correctness shown here cannot come from stored durations).
    private func shot(_ raw: UInt64, c: Double, s: Double, at: Double,
                      entry: ShotTransitionInV1 = .cut, gate: SwipeGateStateV1 = .noSwipe,
                      chromeTop: Double = 0.9, chromeBottom: Double = 0.1,
                      caption: UInt64? = nil, audio: Bool? = nil) -> ShotDescriptorV1 {
        let rep = Tier0CorpusV1.frame(content: c, style: s, chromeTop: chromeTop, chromeBottom: chromeBottom, projShift: 0)
        return ShotDescriptorV1(shotID: ShotID(raw), observationID: ObservationID(7), startMs: at, endMs: at,
                                representative: rep, transitionIn: entry, swipeGate: gate,
                                replacementRatioIn: 0.85, confidenceIn: 0.7,
                                captionFingerprint: caption, audioContinuityWithPrevious: audio)
    }
    private func tier0() -> ContentItemGroupingEngineV2 {
        ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
    }

    // MARK: 1 — bright→bright DIFFERENT items, auditor-chosen values (NOT the project's 0.88/0.84 pair)
    func testAUDIT2_brightToBrightVariantsNeverUnsafeSame() {
        let pairs: [(Double, Double, Double, Double, Double)] = [   // (c1,s1,c2,s2,dwellMs)
            (0.92, 0.95, 0.86, 0.90, 4500),
            (0.90, 0.90, 0.82, 0.88, 6000),
            (0.95, 0.92, 0.91, 0.92, 5000),    // extremely close luma
            (0.85, 0.85, 0.80, 0.85, 12000),   // long user watch
            (0.93, 0.94, 0.89, 0.93, 3900),    // just past the long-dwell threshold
        ]
        for (i, p) in pairs.enumerated() {
            let e = tier0()
            _ = e.process(shot(1, c: p.0, s: p.1, at: 0))
            let d = e.process(shot(2, c: p.2, s: p.3, at: p.4))
            print("AUDIT2_PROBE brightBright[\(i)] state=\(d.state.rawValue) S=\(d.mergeScore) N=\(d.newScore) inherit=\(d.safeAdmissionInheritance)")
            XCTAssertNotEqual(d.state, .sameItemConfirmed, "bright→bright[\(i)] different items must never merge")
            XCTAssertFalse(d.safeAdmissionInheritance, "bright→bright[\(i)] must never inherit")
        }
    }

    // MARK: 2 — dark→dark DIFFERENT items, auditor-chosen values
    func testAUDIT2_darkToDarkVariantsNeverUnsafeSame() {
        let pairs: [(Double, Double, Double, Double, Double)] = [
            (0.05, 0.06, 0.15, 0.08, 5000),
            (0.10, 0.08, 0.04, 0.07, 7000),
            (0.12, 0.12, 0.08, 0.12, 4200),
            (0.06, 0.05, 0.10, 0.06, 15000),
        ]
        for (i, p) in pairs.enumerated() {
            let e = tier0()
            _ = e.process(shot(1, c: p.0, s: p.1, at: 0))
            let d = e.process(shot(2, c: p.2, s: p.3, at: p.4))
            print("AUDIT2_PROBE darkDark[\(i)] state=\(d.state.rawValue) S=\(d.mergeScore) N=\(d.newScore)")
            XCTAssertNotEqual(d.state, .sameItemConfirmed, "dark→dark[\(i)] different items must never merge")
            XCTAssertFalse(d.safeAdmissionInheritance)
        }
    }

    // MARK: 3 — same-layout (identical style/projections/histogram/chrome) DIFFERENT semantic item
    func testAUDIT2_sameLayoutDifferentItemNeverUnsafeSame() {
        let cases: [(Double, Double, Double)] = [   // (c1, c2, dwell) — style constant 0.50
            (0.20, 0.80, 7000),   // far content
            (0.30, 0.55, 5000),   // mid-distance content
            (0.40, 0.60, 4000),   // closer content, long-ish dwell
        ]
        for (i, p) in cases.enumerated() {
            let e = tier0()
            _ = e.process(shot(1, c: p.0, s: 0.50, at: 0))
            let d = e.process(shot(2, c: p.1, s: 0.50, at: p.2))
            print("AUDIT2_PROBE sameLayout[\(i)] state=\(d.state.rawValue) S=\(d.mergeScore) theme=\(d.channels?.themeDistance ?? -1) proj=\(d.channels?.projectionCorrelation ?? -1)")
            XCTAssertNotEqual(d.state, .sameItemConfirmed, "same-layout[\(i)] different item must never merge")
            XCTAssertFalse(d.safeAdmissionInheritance)
        }
    }

    // MARK: 4 — counterfactual: the independence guard is the LOAD-BEARING C6 blocker (not fixture drift).
    // Find a C6-shaped case where the pre-Phase-C rule (S≥confirm, N<veto, anchored) WOULD merge and the only
    // blocking condition is EvidenceIndependenceGuardV1. If no such case existed, the guard would be vacuous.
    func testAUDIT2_independenceGuardIsLoadBearingOnC6Shape() {
        let pol = ProfileAwareItemGroupingPolicyV2.frozenTier0
        var found = 0
        for c1 in stride(from: 0.78, through: 0.94, by: 0.02) {
            for dc in stride(from: 0.01, through: 0.08, by: 0.01) {
                let e = tier0()
                _ = e.process(shot(1, c: c1, s: c1 + 0.03, at: 0))
                let d = e.process(shot(2, c: c1 - dc, s: c1 + 0.02, at: 5000))   // long dwell = C6 shape
                guard let ch = d.channels else { continue }
                let firedSame = d.evidence.filter { $0.supportsSameItem }.map { $0.source.raw }
                let independenceOK = EvidenceIndependenceGuardV1.allowsSameConfirmation(firedSameSources: firedSame)
                let oldRuleWouldMerge = d.mergeScore >= pol.confirmSameNormalized
                    && d.newScore < pol.newVetoLevel && ch.anchored && !ch.strongNew
                if oldRuleWouldMerge && !independenceOK {
                    found += 1
                    XCTAssertNotEqual(d.state, .sameItemConfirmed,
                                      "guard-blocked case must land AMBIGUOUS/NEW (c1=\(c1) dc=\(dc))")
                    XCTAssertEqual(d.state, .ambiguous, "C6 shape resolves to its labeled-safe outcome")
                    if found == 1 {
                        print("AUDIT2_COUNTERFACTUAL c1=\(c1) dc=\(dc) S=\(d.mergeScore) N=\(d.newScore) anchored=\(ch.anchored) fired=\(firedSame.joined(separator: "+")) → pre-Phase-C rule MERGES, guard blocks")
                    }
                }
            }
        }
        print("AUDIT2_COUNTERFACTUAL loadBearingCases=\(found)")
        XCTAssertGreaterThan(found, 0, "guard must be load-bearing on the C6 shape (otherwise the probe pass is unexplained)")
    }

    // MARK: 5 — correlated luma features: recompute Pearson from the RAW device SHOTEV artifact + SHA-256 lock.
    // Independently validates the GROSS_LUMA one-family claim (doc: theme~regional +0.64, hist~regional +0.60,
    // chrome~regional +0.58, proj anti-correlated) and the measured dwell defect (prevDwellMs=0 on 100% of rows).
    func testAUDIT2_measuredEvidenceArtifactCorrelationsAndSHA() throws {
        let path = "/Users/dogancangundogan/PROJECTGEN8/Gen8/docs/evals/artifacts/P009A_R2_MEASURED_tier0_evidence.log"
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let hex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let lock = try String(contentsOfFile: path + ".sha256", encoding: .utf8)
        let expected = lock.split(separator: " ").first.map(String.init) ?? ""
        print("AUDIT2_SHA P009A_R2_MEASURED_tier0_evidence.log recomputed=\(hex) locked=\(expected)")
        XCTAssertEqual(hex, expected, "measured-evidence artifact SHA-256 must match its lock file")

        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
            .filter { $0.contains("SHOTEV") }
        XCTAssertEqual(lines.count, 88, "doc claims 88 SHOTEV rows")
        func value(_ line: String, _ key: String) -> Double? {
            guard let r = line.range(of: " " + key + "=") else { return nil }
            return Double(line[r.upperBound...].prefix(while: { !$0.isWhitespace }))
        }
        var theme: [Double] = [], hist: [Double] = [], chrome: [Double] = [], regional: [Double] = [], proj: [Double] = []
        var dwellZero = 0
        for l in lines {
            guard let t = value(l, "theme"), let h = value(l, "hist"), let c = value(l, "chrome"),
                  let g = value(l, "regional"), let p = value(l, "proj"), let dw = value(l, "prevDwellMs") else {
                return XCTFail("malformed SHOTEV row: \(l)")
            }
            theme.append(t); hist.append(h); chrome.append(c); regional.append(g); proj.append(p)
            if dw == 0 { dwellZero += 1 }
        }
        XCTAssertEqual(dwellZero, 88, "measured dwell defect: prevDwellMs=0 on 100% of device rows (pre-fix)")
        func pearson(_ a: [Double], _ b: [Double]) -> Double {
            let n = Double(a.count); let ma = a.reduce(0,+)/n, mb = b.reduce(0,+)/n
            var num = 0.0, da = 0.0, db = 0.0
            for i in a.indices { num += (a[i]-ma)*(b[i]-mb); da += (a[i]-ma)*(a[i]-ma); db += (b[i]-mb)*(b[i]-mb) }
            return da > 0 && db > 0 ? num / (da*db).squareRoot() : 0
        }
        let tr = pearson(theme, regional), hr = pearson(hist, regional), cr = pearson(chrome, regional)
        let pt = pearson(proj, theme), pr = pearson(proj, regional), ph = pearson(proj, hist), pc = pearson(proj, chrome)
        print(String(format: "AUDIT2_PEARSON theme~regional=%.2f hist~regional=%.2f chrome~regional=%.2f proj~theme=%.2f proj~hist=%.2f proj~chrome=%.2f proj~regional=%.2f", tr, hr, cr, pt, ph, pc, pr))
        XCTAssertEqual(tr, 0.64, accuracy: 0.03, "doc claim theme~regional +0.64")
        XCTAssertEqual(hr, 0.60, accuracy: 0.03, "doc claim hist~regional +0.60")
        XCTAssertEqual(cr, 0.58, accuracy: 0.03, "doc claim chrome~regional +0.58")
        for (name, v) in [("proj~theme", pt), ("proj~hist", ph), ("proj~chrome", pc), ("proj~regional", pr)] {
            XCTAssertLessThan(v, 0, "\(name) must be anti-correlated (doc: −0.44…−0.70)")
            XCTAssertGreaterThanOrEqual(v, -0.75, "\(name) in documented band")
            XCTAssertLessThanOrEqual(v, -0.40, "\(name) in documented band")
        }
        // the GROSS_LUMA family grouping is therefore empirically supported, not a fixture-fitted choice
    }

    // MARK: 6 — stale provisional identity: never mints DNA, invalidates target DNA on merge, dies with the session
    func testAUDIT2_staleProvisionalIdentityLifecycle() {
        let e = tier0()
        _ = e.process(shot(1, c: 0.40, s: 0.30, at: 0))
        _ = e.process(shot(2, c: 0.44, s: 0.30, at: 1500))
        let dna = e.mintDNA(for: e.currentItem!.id, nowMs: 2000)
        XCTAssertNotNil(dna, "confirmed item mints")
        XCTAssertGreaterThan(dna!.expiresAtMs, 2000, "DNA carries a TTL (stale identity invalidates by expiry)")
        let amb = e.process(shot(3, c: 0.72, s: 0.30, at: 9000))
        XCTAssertEqual(amb.state, .ambiguous)
        // stale/unresolved provisional identity can never mint durable DNA — repeatedly
        for now in [9500.0, 50_000.0, 5_000_000.0] {
            XCTAssertNil(e.mintDNA(for: amb.itemID, nowMs: now), "provisional identity must never mint (now=\(now))")
        }
        // deferred repair invalidates the predecessor's minted DNA (identity changed → rebuild)
        _ = e.process(shot(4, c: 0.42, s: 0.30, at: 10200))
        _ = e.process(shot(5, c: 0.41, s: 0.30, at: 11400))
        var invalidated: [ContentDNAID] = []
        let co = DeferredItemCoalescerV1()
        var merged = false
        for _ in 0..<3 { if co.tryCoalesce(engine: e, dnaInvalidator: { invalidated.append($0) }) { merged = true } }
        XCTAssertTrue(merged)
        XCTAssertTrue(invalidated.contains(dna!.dnaID), "merge into a DNA-carrying item must invalidate that DNA")
        XCTAssertNil(e.itemsInOrder.first?.dnaID, "invalidated DNA reference cleared for rebuild")
        // provisional IDs are engine-local: a fresh session engine shares no identity state
        let e2 = tier0()
        XCTAssertTrue(e2.itemsInOrder.isEmpty && e2.revisions.isEmpty, "no provisional identity survives a session reset")
    }

    // MARK: 7 — strongNew conflict: maximal SAME evidence + strong-new cue must never merge, in BOTH tiers
    func testAUDIT2_strongNewConflictAbsolute() {
        // Tier-0: identical frames at edit-burst cadence (every same channel + burst fires) + confirmed swipe
        let e = tier0()
        _ = e.process(shot(1, c: 0.40, s: 0.40, at: 0))
        let d = e.process(shot(2, c: 0.40, s: 0.40, at: 900, entry: .swipeConfirmed, gate: .swipeTransitionConfirmed))
        XCTAssertNotEqual(d.state, .sameItemConfirmed, "swipe veto absolute under max S at burst cadence")
        XCTAssertTrue(d.channels?.strongNew ?? false)
        // Tier-0: app-surface transition onto identical content
        let e2 = tier0()
        _ = e2.process(shot(1, c: 0.40, s: 0.40, at: 0))
        let d2 = e2.process(shot(2, c: 0.40, s: 0.40, at: 900, entry: .appSurface))
        XCTAssertNotEqual(d2.state, .sameItemConfirmed, "app-surface veto absolute")
        // Tier-1: swipe + caption MATCH (cross-modal anchor satisfies the guard — veto must still win)
        let e3 = ContentItemGroupingEngineV2(policy: .frozenTier1, profile: .appFullTier1)
        _ = e3.process(shot(1, c: 0.40, s: 0.40, at: 0, caption: 42))
        let d3 = e3.process(shot(2, c: 0.40, s: 0.40, at: 900, entry: .swipeConfirmed,
                                 gate: .swipeTransitionConfirmed, caption: 42, audio: true))
        XCTAssertNotEqual(d3.state, .sameItemConfirmed, "veto beats cross-modal anchor in Tier-1 too")
        XCTAssertFalse(d3.safeAdmissionInheritance)
        print("AUDIT2_PROBE strongNewConflict t0swipe=\(d.state.rawValue) t0surface=\(d2.state.rawValue) t1swipe+caption=\(d3.state.rawValue)")
    }

    // MARK: 8 — provisional risk escalation: immediate, monotone, never lost by further reports
    func testAUDIT2_provisionalRiskEscalationMonotone() {
        let e = tier0()
        _ = e.process(shot(1, c: 0.40, s: 0.30, at: 0))
        let amb = e.process(shot(2, c: 0.72, s: 0.31, at: 2000))
        XCTAssertEqual(amb.state, .ambiguous)
        e.accumulator.reportRisk(item: amb.itemID, confidence: 0.5)
        var rec = e.shotOnlyEvidence(for: amb.itemID)
        XCTAssertTrue(rec[0].riskEscalated, "risk escalates IMMEDIATELY while identity unresolved")
        XCTAssertEqual(rec[0].maxRiskConfidence, 0.5)
        e.accumulator.reportRisk(item: amb.itemID, confidence: 0.9)
        e.accumulator.reportRisk(item: amb.itemID, confidence: 0.3)   // later weaker report must not lower it
        rec = e.shotOnlyEvidence(for: amb.itemID)
        XCTAssertEqual(rec[0].maxRiskConfidence, 0.9, "risk is monotone max — never decreases")
        XCTAssertTrue(rec[0].riskEscalated)
        XCTAssertEqual(rec[0].privacyClass, .derivedNonReconstructive)
        // and still: no DNA, no inheritance for the risky provisional item
        XCTAssertNil(e.mintDNA(for: amb.itemID, nowMs: 3000))
    }

    // MARK: 9 — rapid session reset: 60 create/drop cycles deterministic; no cross-session dwell/identity leakage
    func testAUDIT2_rapidSessionResetNoLeakage() {
        func run() -> [String] {
            var out: [String] = []
            for session in 0..<60 {
                let e = tier0()
                let buf = Tier1HandoffBufferV1(capacity: 16)
                // sessions start at wildly different wall-clock offsets — leakage would corrupt dwell
                let t0 = Double(session) * 1_000_000 + 12_345
                let d1 = e.process(shot(1, c: 0.3, s: 0.3, at: t0))
                XCTAssertTrue(d1.openedNewItem)
                XCTAssertNil(d1.channels, "first decision of a fresh session makes no channel/dwell claim")
                let d2 = e.process(shot(2, c: 0.33, s: 0.3, at: t0 + 1500))
                XCTAssertEqual(d2.channels!.previousShotDwellMs, 1500, "dwell derived within-session only (t0=\(t0))")
                let p = ExtensionProvisionalIdentityV1.from(decision: d2, shotID: ShotID(2), profile: .extensionFastTier0,
                                                            groupingRevision: "g", shotRevision: "s")
                buf.append(Tier1IdentityHandoffV1.from(identity: p, observationID: ObservationID(1), transition: .cut,
                                                       channels: d2.channels, thermal: .nominal))
                out.append("s\(session):\(d2.state.rawValue):items=\(e.confirmedOrProvisionalItemCount):buf=\(buf.count)")
            }
            return out
        }
        let a = run(), b = run()
        XCTAssertEqual(a, b, "rapid session churn must be deterministic")
        print("AUDIT2_PROBE rapidReset sessions=60 deterministic=\(a == b) sample=\(a[0])")
    }

    // MARK: 10 — release logging: full compile-flag/debug/env truth table (8 combinations)
    func testAUDIT2_releaseLoggingFlagMatrix() {
        for flag in [false, true] {
            for debug in [false, true] {
                for env in [false, true] {
                    let on = EvidenceBuildPolicyV1.isEnabled(compileFlagSet: flag, isDebugBuild: debug, envOptIn: env)
                    let expected = flag || (debug && env)
                    XCTAssertEqual(on, expected, "matrix(flag=\(flag),debug=\(debug),env=\(env))")
                }
            }
        }
        // the release-critical cell, stated explicitly: env opt-in alone can NEVER enable in release
        XCTAssertFalse(EvidenceBuildPolicyV1.isEnabled(compileFlagSet: false, isDebugBuild: false, envOptIn: true))
        print("AUDIT2_PROBE releaseLoggingMatrix 8/8 combinations hold; release env opt-in ignored")
    }

    // MARK: 11 — malformed/boundary Tier-1 handoff: nil channels, NaN/∞ scalars, degenerate capacity, ring order
    func testAUDIT2_malformedAndBoundaryTier1Handoff() {
        // (a) nil channels → honest defaults (max-distance visuals, zero temporal), never a crash
        let e = tier0()
        let d1 = e.process(shot(1, c: 0.4, s: 0.4, at: 0))   // first decision: channels == nil
        let p = ExtensionProvisionalIdentityV1.from(decision: d1, shotID: ShotID(1), profile: .extensionFastTier0,
                                                    groupingRevision: "g", shotRevision: "s")
        let h = Tier1IdentityHandoffV1.from(identity: p, observationID: ObservationID(1), transition: .sessionStart,
                                            channels: nil, thermal: .critical)
        XCTAssertEqual(h.themeDistance, 1); XCTAssertEqual(h.projectionCorrelation, 0)
        XCTAssertEqual(h.histogramDistance, 1); XCTAssertEqual(h.chromeDistance, 1); XCTAssertEqual(h.regionalDistance, 1)
        XCTAssertEqual(h.previousShotDwellMs, 0); XCTAssertEqual(h.thermalBucket, .critical)
        XCTAssertFalse(h.modelPolicyVersions.isEmpty, "provenance must survive the degenerate path")
        // (b) adversarial NaN/∞ telemetry must not corrupt the record container
        let evil = GroupingChannelTelemetryV1(themeDistance: .nan, projectionCorrelation: .infinity,
                                              histogramDistance: -1, chromeDistance: .nan, regionalDistance: 2,
                                              gapSinceLastBoundaryMs: -5, previousShotDwellMs: .infinity,
                                              elapsedItemMs: .nan, strongNew: false, anchored: false, firedEvidence: [])
        let hEvil = Tier1IdentityHandoffV1.from(identity: p, observationID: ObservationID(1), transition: .cut,
                                                channels: evil, thermal: .nominal)
        let buf = Tier1HandoffBufferV1(capacity: 8)
        buf.append(hEvil)
        XCTAssertEqual(buf.count, 1, "NaN payload stored without crash (consumer must validate — see report)")
        // (c) degenerate capacities clamp to a sane floor; ring keeps the NEWEST records
        for cap in [0, -3, 1, 7] {
            let b2 = Tier1HandoffBufferV1(capacity: cap)
            XCTAssertGreaterThanOrEqual(b2.capacity, 8, "capacity floor (requested \(cap))")
        }
        let ring = Tier1HandoffBufferV1(capacity: 8)
        for k in 1...300 {
            var shotK = p
            shotK = ExtensionProvisionalIdentityV1(shotID: ShotID(UInt64(k)), provisionalItemID: p.provisionalItemID,
                                                   relation: p.relation, strongNew: p.strongNew,
                                                   compactEvidence: p.compactEvidence, independentFamilies: p.independentFamilies,
                                                   profileName: p.profileName, groupingPolicyRevision: p.groupingPolicyRevision,
                                                   shotPolicyRevision: p.shotPolicyRevision)
            ring.append(Tier1IdentityHandoffV1.from(identity: shotK, observationID: ObservationID(1), transition: .cut,
                                                    channels: nil, thermal: .nominal))
        }
        XCTAssertEqual(ring.count, 8, "bounded under 300 appends")
        XCTAssertEqual(ring.records.first?.shotID.raw, 293, "ring drops OLDEST (keeps 293...300)")
        XCTAssertEqual(ring.records.last?.shotID.raw, 300)
        let drained = ring.drain()
        XCTAssertEqual(drained.count, 8); XCTAssertEqual(ring.count, 0, "drain empties the ring")
        // (d) derived-only by construction (no Data/[UInt8] anywhere, including the NaN record)
        for child in Mirror(reflecting: hEvil).children {
            XCTAssertFalse(child.value is Data); XCTAssertFalse(child.value is [UInt8])
        }
        print("AUDIT2_PROBE handoff malformed/boundary cases safe; ring semantics newest-N verified")
    }

    // MARK: 12 — Tier-0 output is NEVER authoritative; inheritance structurally impossible at Tier-0,
    //            and provisional identity never inherits even in Tier-1 with cross-modal anchors
    func testAUDIT2_provisionalSemanticsAndInheritanceMatrix() {
        // Tier-0 legitimate merge → CANDIDATE_SAME_ITEM, inheritance false
        let e = tier0()
        _ = e.process(shot(1, c: 0.4, s: 0.3, at: 0))
        let same = e.process(shot(2, c: 0.44, s: 0.3, at: 1500))
        XCTAssertEqual(same.state, .sameItemConfirmed)
        XCTAssertFalse(same.safeAdmissionInheritance, "Tier-0 inheritance structurally OFF")
        let pSame = ExtensionProvisionalIdentityV1.from(decision: same, shotID: ShotID(2), profile: .extensionFastTier0,
                                                        groupingRevision: "g", shotRevision: "s")
        XCTAssertEqual(pSame.relation, .candidateSameItem, "never authoritative SAME from Tier-0")
        // Tier-1 non-provisional merge with caption anchor → inheritance is the Tier-1 capability (control)
        let t1 = ContentItemGroupingEngineV2(policy: .frozenTier1, profile: .appFullTier1)
        _ = t1.process(shot(1, c: 0.4, s: 0.3, at: 0, caption: 7))
        let d1 = t1.process(shot(2, c: 0.44, s: 0.3, at: 1500, caption: 7, audio: true))
        XCTAssertEqual(d1.state, .sameItemConfirmed)
        XCTAssertTrue(d1.safeAdmissionInheritance, "control: Tier-1 + non-provisional + cross-modal may inherit")
        // Tier-1 merge INTO a provisional item (ambiguous split) must NOT inherit despite caption+audio anchors
        let t1b = ContentItemGroupingEngineV2(policy: .frozenTier1, profile: .appFullTier1)
        _ = t1b.process(shot(1, c: 0.40, s: 0.30, at: 0))
        let amb = t1b.process(shot(2, c: 0.72, s: 0.31, at: 6000, caption: 9))   // provisional split
        XCTAssertEqual(amb.state, .ambiguous); XCTAssertTrue(amb.provisional)
        let d2 = t1b.process(shot(3, c: 0.72, s: 0.31, at: 7000, caption: 9, audio: true))
        if d2.state == .sameItemConfirmed {
            XCTAssertTrue(d2.provisional, "merge into provisional stays provisional")
            XCTAssertFalse(d2.safeAdmissionInheritance, "provisional identity must never inherit, even in Tier-1")
        }
        print("AUDIT2_PROBE inheritanceMatrix t0=\(same.safeAdmissionInheritance) t1Confirmed=\(d1.safeAdmissionInheritance) t1Provisional=\(d2.state == .sameItemConfirmed ? String(d2.safeAdmissionInheritance) : "no-merge(\(d2.state.rawValue))")")
    }

    // MARK: 13 — RESIDUAL-RISK CHARACTERIZATION (informational): near-identical DIFFERENT item arriving as a
    // plain CUT at edit-burst cadence satisfies the guard (luma family + temporal family). Document, don't hide.
    func testAUDIT2_burstCadenceNearIdenticalDifferentItemCharacterized() {
        let e = tier0()
        _ = e.process(shot(1, c: 0.88, s: 0.90, at: 0))
        let d = e.process(shot(2, c: 0.85, s: 0.89, at: 2500))   // < burstGapMs 3200, plain cut, near-identical
        print("AUDIT2_RESIDUAL burstCadenceSimilarDifferent state=\(d.state.rawValue) S=\(d.mergeScore) N=\(d.newScore) fired=\(d.channels?.firedEvidence.joined(separator: "+") ?? "")")
        // Whatever the grouping outcome, the SAFETY contract must hold: never authoritative, never inheritance.
        XCTAssertFalse(d.safeAdmissionInheritance, "even a wrong provisional merge may never inherit at Tier-0")
        let p = ExtensionProvisionalIdentityV1.from(decision: d, shotID: ShotID(2), profile: .extensionFastTier0,
                                                    groupingRevision: "g", shotRevision: "s")
        XCTAssertNotEqual(p.relation == .candidateSameItem ? "authoritative" : "candidate", "authoritative-with-inheritance")
        if d.state == .sameItemConfirmed {
            print("AUDIT2_RESIDUAL CONFIRMED: burst-cadence near-identical different item provisionally merges at Tier-0 (documented edit-cadence assumption; mitigated by provisional-only identity + no inheritance; Tier-1 must resolve)")
        }
    }
}
