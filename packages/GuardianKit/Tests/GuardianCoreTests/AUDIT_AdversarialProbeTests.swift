// AUDITOR-AUTHORED adversarial probes (independent red-team audit, 2026-10-19).
// Not part of the project's own suite. Safe to delete after audit.
//
// Probes 1 and 2 are INFORMATIONAL ONLY (print AUDIT_PROBE lines, no correctness assertion).
// All other probes assert documented contracts. A failing assertion is reported honestly, not weakened.

import XCTest
import Foundation
@testable import GuardianCore

final class AUDIT_AdversarialProbeTests: XCTestCase {

    // MARK: helpers (copied construction pattern from P009AR1Tier0Tests.t0shot — not production code)

    private func shot(_ raw: UInt64, content: Double, style: Double, at: Double, dur: Double = 2000,
                      entry: ShotTransitionInV1 = .cut, gate: SwipeGateStateV1 = .noSwipe,
                      chromeTop: Double = 0.9, chromeBottom: Double = 0.1) -> ShotDescriptorV1 {
        let rep = Tier0CorpusV1.frame(content: content, style: style, chromeTop: chromeTop,
                                      chromeBottom: chromeBottom, projShift: 0)
        return ShotDescriptorV1(shotID: ShotID(raw), observationID: ObservationID(1), startMs: at, endMs: at + dur,
                                representative: rep, transitionIn: entry, swipeGate: gate,
                                replacementRatioIn: 0.85, confidenceIn: 0.7,
                                captionFingerprint: nil, audioContinuityWithPrevious: nil)
    }

    // MARK: Probe 1 — SAME-LOOKING DIFFERENT ITEM (informational, no correctness assertion)
    // A different feed item that happens to be pixel-identical in every Tier-0 channel arrives over a plain CUT
    // after a long dwell. All same channels fire; the engine has no cross-modal evidence to distinguish it.
    func testAUDIT_sameLookingDifferentItem() {
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        _ = e.process(shot(1, content: 0.40, style: 0.30, at: 0, dur: 5000))          // user watches item A
        // ground truth: a DIFFERENT item, but its derived frame is IDENTICAL (same hashes/projections/histogram)
        let d = e.process(shot(2, content: 0.40, style: 0.30, at: 5000, dur: 2000, entry: .cut))
        print("AUDIT_PROBE sameLookingDifferentItem decision=\(d.state.rawValue) S=\(d.mergeScore) N=\(d.newScore) openedNew=\(d.openedNewItem) inherit=\(d.safeAdmissionInheritance)")
        // Also probe the sensor layer: ShotSegmenterV5 fed a hard "cut" to an IDENTICAL frame sees no boundary at all.
        let seg = ShotSegmenterV5(observationID: ObservationID(9))
        var boundaries = 0; var t = 0.0
        let f = SegmentFrameFactoryV4.frame(base: 0.4, motionOffset: 0, chromeTop: 0.9, chromeBottom: 0.1, chromeEdge: nil, bins: 16, shift: 0)
        for _ in 0..<20 { if seg.process(f, timestampMs: t).boundary != nil { boundaries += 1 }; t += 33 }
        print("AUDIT_PROBE sameLookingDifferentItem segmenterBoundariesOnIdenticalCut=\(boundaries) (first=session start)")
        XCTAssertTrue(true) // informational probe — no correctness assertion by audit design
    }

    // MARK: Probe 2 — DIFFERENT-LOOKING SAME ITEM (informational, no correctness assertion)
    // One item whose internal cuts break EVERY Tier-0 channel (content + style + histogram + projections).
    func testAUDIT_differentLookingSameItem() {
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        // ground truth: all shots belong to ONE item, but each cut changes everything the extension can see
        let specs: [(Double, Double)] = [(0.10, 0.10), (0.85, 0.90), (0.20, 0.75), (0.90, 0.15)]
        var t = 0.0; var states: [String] = []
        for (i, s) in specs.enumerated() {
            let d = e.process(shot(UInt64(i + 1), content: s.0, style: s.1, at: t, dur: 4500,
                                   entry: i == 0 ? .sessionStart : .cut))
            if i > 0 {
                states.append(d.state.rawValue)
                print("AUDIT_PROBE differentLookingSameItem shot=\(i + 1) decision=\(d.state.rawValue) S=\(d.mergeScore) N=\(d.newScore)")
            }
            t += 4500
        }
        let allNew = states.allSatisfy { $0 == ItemGroupingStateV1.newItemConfirmed.rawValue }
        print("AUDIT_PROBE differentLookingSameItem allBoundariesBecameNEW=\(allNew) items=\(e.confirmedOrProvisionalItemCount) (expected Tier-0 behavior: all NEW — over-split, never false-merge)")
        XCTAssertTrue(true) // informational probe — no correctness assertion by audit design
    }

    // MARK: Probe 3 — AMBIGUOUS never inherits safe admission state
    func testAUDIT_ambiguousNeverInheritsSafeState() {
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        _ = e.process(shot(1, content: 0.40, style: 0.30, at: 0, dur: 1500))
        _ = e.process(shot(2, content: 0.44, style: 0.30, at: 1500, dur: 1500))
        // long gap + mid-distance content over a plain cut → AMBIGUOUS provisional split (same recipe as project test)
        let d = e.process(shot(3, content: 0.72, style: 0.30, at: 9000, dur: 1200))
        print("AUDIT_PROBE ambiguousNoInheritance decision=\(d.state.rawValue) provisional=\(d.provisional) inherit=\(d.safeAdmissionInheritance) S=\(d.mergeScore) N=\(d.newScore)")
        XCTAssertEqual(d.state, .ambiguous, "probe construction must land AMBIGUOUS")
        XCTAssertFalse(d.safeAdmissionInheritance, "AMBIGUOUS must never inherit a safe admission state")
        XCTAssertTrue(d.provisional, "AMBIGUOUS split must be provisional")
    }

    // MARK: Probe 4 — global-scope learning signal without opt-in consent must be rejected
    func testAUDIT_noConsentGlobalSignalRejected() {
        let bus = LearningSignalBusV1()
        let bad = LearningSignalV1(signalType: "correction", derivedFeatureClass: "class-only", scope: .globalAggregate,
                                   consent: .defaultLocal, privacyClass: "DERIVED_NON_RECONSTRUCTIVE",
                                   modelVersion: "m1", policyVersion: "p1", outcome: "fp", correctionLabel: nil,
                                   confidence: 0.9, latencyMs: nil, locale: "en", deviceCapabilityBucket: "A",
                                   retentionDays: 7, aggregationEligible: true)
        let accepted = bus.submit(bad)
        print("AUDIT_PROBE noConsentGlobalSignal accepted=\(accepted) rejectedConsent=\(bus.rejectedConsent) stored=\(bus.signals.count)")
        XCTAssertFalse(accepted, "globalAggregate without optInGlobal consent must be rejected")
        XCTAssertEqual(bus.rejectedConsent, 1)
        XCTAssertTrue(bus.signals.isEmpty, "rejected signal must not be stored")
        // control: local-scope default consent is allowed
        var ok = bad; ok.scope = .local
        XCTAssertTrue(bus.submit(ok), "local scope with default consent is the allowed path")
    }

    // MARK: Probe 5 — pack checksum tamper: activation/verify refused
    func testAUDIT_packChecksumTamperRefused() {
        // (a) ModelPack.swift gate: wrong checksum fails verify; empty checksum fails activation eligibility
        let entry = ModelPackEntry(task: "t", modelId: "m1", checksum: "abc123", sizeBytes: 10, runtime: "swift-linear",
                                   minOS: "17.0", resourceClass: "TINY", calibrationVersion: nil,
                                   license: "MIT", rollbackArtifact: "m0")
        let manifest = ModelPackManifest(packId: "pack1", version: "1.0", models: [entry])
        let verifyTampered = manifest.verify(modelId: "m1", actualChecksum: "TAMPERED")
        let noRollback = ModelPackEntry(task: "t", modelId: "m2", checksum: "abc", sizeBytes: 1, runtime: "r",
                                        minOS: "17.0", resourceClass: "TINY", calibrationVersion: nil,
                                        license: "MIT", rollbackArtifact: "")
        print("AUDIT_PROBE packChecksumTamper verifyTampered=\(verifyTampered) activationNoRollback=\(manifest.activationEligible(noRollback))")
        XCTAssertFalse(verifyTampered, "tampered checksum must fail verification")
        XCTAssertTrue(manifest.verify(modelId: "m1", actualChecksum: "abc123"), "control: correct checksum verifies")
        XCTAssertFalse(manifest.activationEligible(noRollback), "no rollback artifact → activation refused")
        // (b) IntelligencePackLifecycleManagerV1 verify gate: payload/checksum mismatch → QUARANTINED, never INSTALLED
        let payload: [UInt8] = [1, 2, 3, 4, 5]
        let m = IntelligencePackManifestV1(packID: "ip1", semanticVersion: "1.0.0", engineCompatibility: "e1",
                                           minimumOS: "17.0", deviceCapabilityRequirements: [], sizeBytes: 5,
                                           checksum: IntelligencePackManifestV1.fnv1a(payload) &+ 1,   // wrong on purpose
                                           signature: "sig", assetTypes: [.model], privacyClassification: "derived",
                                           localeScope: ["en"], evictionPriority: 1, rollbackVersion: "0.9", dependencies: [])
        let mgr = IntelligencePackLifecycleManagerV1()
        let state = mgr.install(m, payload: payload, engineVersion: "e1", signatureValid: true)
        print("AUDIT_PROBE packChecksumTamper lifecycleInstallState=\(state.rawValue)")
        XCTAssertEqual(state, .quarantined, "checksum mismatch must quarantine, never install")
    }

    // MARK: Probe 6 — thermal degradation contract
    func testAUDIT_thermalDegradationContract() {
        XCTAssertTrue(ThermalAwareDegradationV1.allowOptionalDeepWork(.nominal))
        XCTAssertFalse(ThermalAwareDegradationV1.allowOptionalDeepWork(.fair))
        XCTAssertFalse(ThermalAwareDegradationV1.allowOptionalDeepWork(.serious))
        XCTAssertFalse(ThermalAwareDegradationV1.allowOptionalDeepWork(.critical))
        XCTAssertTrue(ThermalAwareDegradationV1.allowSafetyCriticalDeepWork(.nominal))
        XCTAssertTrue(ThermalAwareDegradationV1.allowSafetyCriticalDeepWork(.fair))
        XCTAssertFalse(ThermalAwareDegradationV1.allowSafetyCriticalDeepWork(.serious))
        XCTAssertFalse(ThermalAwareDegradationV1.allowSafetyCriticalDeepWork(.critical))
        print("AUDIT_PROBE thermalDegradation contract holds for all four buckets")
    }

    // MARK: Probe 7 — corrupted shield store: garbage bytes + tampered checksum both rejected safely
    func testAUDIT_corruptedShieldStoreFailsSafely() throws {
        let dir = URL(fileURLWithPath: "/tmp/audit-shield-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileName = "personal-shield.store.json"
        // (a) garbage bytes → load must throw (not crash, not return bogus data)
        let store = FileBackedPersonalShieldStore(directory: dir, fileName: fileName, protectData: false)
        let garbage = Data((0..<257).map { _ in UInt8.random(in: 0...255) })
        try garbage.write(to: dir.appendingPathComponent(fileName))
        var garbageOutcome = "no-throw"
        do {
            _ = try store.load()
        } catch let e as ShieldStoreError {
            garbageOutcome = "\(e)"
        }
        print("AUDIT_PROBE corruptShieldStore garbageLoad=\(garbageOutcome)")
        XCTAssertNotEqual(garbageOutcome, "no-throw", "garbage bytes must be rejected with a typed error")
        // (b) valid snapshot, then tamper the envelope's payloadChecksum → load must throw corrupted
        try store.save(ShieldStoreSnapshot())
        let fileURL = dir.appendingPathComponent(fileName)
        var obj = try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as! [String: Any]
        XCTAssertNotNil(obj["payloadChecksum"], "envelope format changed — probe needs updating")
        obj["payloadChecksum"] = String(repeating: "0", count: 64)   // wrong SHA-256
        try JSONSerialization.data(withJSONObject: obj).write(to: fileURL)
        var tamperOutcome = "no-throw"
        do {
            _ = try store.load()
        } catch let e as ShieldStoreError {
            tamperOutcome = "\(e)"
        }
        print("AUDIT_PROBE corruptShieldStore tamperedChecksumLoad=\(tamperOutcome)")
        guard case .some = tamperOutcome.range(of: "corrupted") else {
            return XCTFail("tampered payload checksum must throw ShieldStoreError.corrupted (got \(tamperOutcome))")
        }
        // (c) missing file is the safe empty path (first launch), never a crash
        let fresh = FileBackedPersonalShieldStore(directory: dir, fileName: "never-written.json", protectData: false)
        let snap = try fresh.load()
        XCTAssertTrue(snap.rules.isEmpty && snap.features.isEmpty, "missing store loads as safe empty snapshot")
    }

    // MARK: Probe 8 — cache: version mismatch and expired TTL must not be returned
    func testAUDIT_cacheCorruptionAndStaleness() async {
        func decision(_ id: String) -> AdmissionDecision {
            AdmissionDecision(contentID: .init(id), state: .approve, confidence: .high,
                              reason: .personalAlgorithmThreshold,
                              score: PBSResult(value: 7.9, state: .verifiedFast, provenance: .heuristicV0, formulaVersion: "v"),
                              explanation: "ok", identityState: .i4_verified)
        }
        let clock = ManualClock()
        let cache = LocalAdmissionCache(clock: clock, capacity: 8, ttlNanos: 1_000)
        await cache.store(CacheEntry(decision: decision("c1"), heuristicVersion: "h1",
                                     policyVersion: "p1", storedAtNanos: clock.nowNanos))
        // engine (heuristic) version changed → must be a miss
        let hMismatch = await cache.lookup(.init("c1"), heuristicVersion: "h2", policyVersion: "p1")
        // policy version changed → must be a miss
        let pMismatch = await cache.lookup(.init("c1"), heuristicVersion: "h1", policyVersion: "p2")
        XCTAssertNil(hMismatch, "stale heuristic-version entry must not be returned")
        XCTAssertNil(pMismatch, "stale policy-version entry must not be returned")
        // control: exact match within TTL hits
        let hit = await cache.lookup(.init("c1"), heuristicVersion: "h1", policyVersion: "p1")
        XCTAssertNotNil(hit)
        // expired TTL → must be a miss
        clock.advance(nanos: 2_000)
        let expired = await cache.lookup(.init("c1"), heuristicVersion: "h1", policyVersion: "p1")
        XCTAssertNil(expired, "expired-TTL entry must not be returned")
        print("AUDIT_PROBE cacheStaleness versionMismatchMiss=\(hMismatch == nil && pMismatch == nil) ttlExpiredMiss=\(expired == nil)")
    }

    // MARK: Probe 9 — rapid swipes + long montage stress (Tier0 corpus seed 2, ground truth available)
    func testAUDIT_rapidSwipeAndMontageStressNoFalseMerge() {
        let r = Tier0EvalV1.evaluate(.frozenTier0, profile: .extensionFastTier0,
                                     fixtures: Tier0CorpusV1.corpus(seed: 2, stress: true))
        let montage = r.perSlice["stress-long-montage"]
        let rapid = r.perSlice["stress-rapid-8"]
        print(String(format: "AUDIT_PROBE stressSeed2 overall mergeFP=%d newFP=%d xM/item=%.4f ambRate=%.3f items=%d shots=%d",
                     r.overall.mergeFP, r.overall.newFP, r.overall.falseCrossItemMergePerItem, r.overall.ambiguousRate,
                     r.overall.items, r.overall.shots))
        if let m = montage, let q = rapid {
            print("AUDIT_PROBE stressSeed2 montage(mergeTP=\(m.mergeTP)/\(m.trueMerges) newFP=\(m.newFP)) rapid(newTP=\(q.newTP)/\(q.trueBoundaries) mergeFP=\(q.mergeFP))")
        }
        for (name, m) in r.perSlice.sorted(by: { $0.key < $1.key }) where m.mergeFP > 0 {
            print("AUDIT_PROBE stressSeed2 OFFENDING_SLICE \(name) mergeFP=\(m.mergeFP) mergeTP=\(m.mergeTP) newTP=\(m.newTP) amb=\(m.ambiguous)")
        }
        // AUDIT NOTE: the project's own documented gates are per-slice for seed 2 (montage newFP=0, rapid mergeFP=0,
        // both asserted below and passing) and xM/item <= 0.005 on the seed-1 held-out corpus only. There is NO
        // documented overall gate for seed 2, so the auditor's stricter zero-false-merge assertion below is kept
        // as specified by the audit brief; its failure is a genuine red-team finding, reported honestly.
        XCTAssertEqual(r.overall.mergeFP, 0, "zero cross-item false merges across the full seed-2 stress corpus")
        XCTAssertEqual(rapid?.mergeFP ?? -1, 0, "rapid-swipe items must never cross-merge")
        XCTAssertEqual(montage?.newFP ?? -1, 0, "long montage must not explode into false new items")
    }

    // MARK: Probe 10 — 50 session start/stop cycles: no crash + deterministic outputs across identical runs
    func testAUDIT_repeatedSessionStartStopDeterministic() {
        func oneRun() -> [String] {
            var fingerprints: [String] = []
            for session in 0..<50 {
                let seg = ShotSegmenterV5(observationID: ObservationID(UInt64(session + 1)))
                let engine = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
                var t = 0.0
                var states: [String] = []
                // a few stable frames, a hard cut to a new base, a few more stable frames — deterministic per session
                let baseA = 0.1 + 0.015 * Double(session % 20)
                let baseB = min(0.95, baseA + 0.55)
                for k in 0..<18 {
                    let base = k < 9 ? baseA : baseB
                    let jitter = 0.015 * (2 * SegmentFrameFactoryV4.rnd(session, k) - 1)
                    let f = SegmentFrameFactoryV4.frame(base: base, motionOffset: jitter, chromeTop: 0.9,
                                                        chromeBottom: 0.1, chromeEdge: nil, bins: 16, shift: 0)
                    let (_, boundary) = seg.process(f, timestampMs: t)
                    if let b = boundary {
                        let d = engine.process(b.newShot)
                        states.append(d.state.rawValue)
                    }
                    t += 33
                }
                fingerprints.append("s\(session):shots=\(seg.shotCount):items=\(engine.confirmedOrProvisionalItemCount):\(states.joined(separator: ","))")
                // instances discarded here — session "stop"
            }
            return fingerprints
        }
        let a = oneRun()
        let b = oneRun()
        XCTAssertEqual(a, b, "two identical runs of 50 start/stop sessions must be byte-identical")
        XCTAssertEqual(a.count, 50)
        print("AUDIT_PROBE sessionChurn runs=2x50 deterministic=\(a == b) sample[0]=\(a[0]) sample[49]=\(a[49])")
    }
}
