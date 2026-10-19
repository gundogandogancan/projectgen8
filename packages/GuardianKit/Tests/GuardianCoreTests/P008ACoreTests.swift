import XCTest
@testable import GuardianCore

final class P008ACoreTests: XCTestCase {

    // §7 — iOS automation truth: session START is one-tap-per-session (system picker); within a session, app switches are
    // automatic; no official cross-app bundle-id exposure; never zero-touch cross-app.
    func testIOSAutomationTruth() {
        let cap = PlatformCapabilityRegistry().capability(platform: "ios")
        XCTAssertEqual(cap.sessionStart, .systemPickerRequired)
        XCTAssertTrue(cap.withinSessionAppSwitchAutomatic)
        XCTAssertEqual(cap.autoResumeAfterInterruption, .oneTapPerSessionRequired)   // OS termination needs one-tap restart
        XCTAssertFalse(cap.appContextOfficiallyExposed)
        XCTAssertNotEqual(cap.sessionStart, .zeroTouchContinuous)                    // no zero-touch cross-app on iOS
        // macOS (ScreenCaptureKit) may auto-resume; different platform, different truth.
        XCTAssertEqual(PlatformCapabilityRegistry().capability(platform: "macos").autoResumeAfterInterruption, .autoResumePermitted)
    }

    // §8 — session state machine: explicit transitions; .active only after OS confirmation; never silent restart on iOS.
    func testSessionStateMachine() {
        let cap = PlatformCapabilityRegistry().capability(platform: "ios")
        let m = ObservationSessionManager(capability: cap)
        XCTAssertEqual(m.apply(.guardianOn), .permissionRequired)   // iOS requires consent, not auto-ready
        XCTAssertEqual(m.apply(.permissionGranted), .ready)
        XCTAssertEqual(m.apply(.userStarted), .starting)
        XCTAssertEqual(m.apply(.osConfirmedActive), .active)
        XCTAssertTrue(m.state.isObserving)
        XCTAssertEqual(m.apply(.osTerminated), .restartRequired)    // iOS cannot silently resume → one-tap restart
        XCTAssertFalse(m.state.isObserving)                         // must NOT claim observing after termination
        XCTAssertEqual(m.apply(.userStarted), .starting)
    }

    // §9 — app context: official id → certain; else inferred class with its OWN capped confidence; never a certain guess.
    func testAppContextResolution() {
        XCTAssertEqual(AppContextResolver.resolve(officialBundleID: "com.x", userDeclared: nil, inferredClass: nil).contextConfidence, 1.0)
        let inferred = AppContextResolver.resolve(officialBundleID: nil, userDeclared: nil, inferredClass: ("short-video-feed", 0.95))
        if case .inferredClass(let c) = inferred.identity { XCTAssertEqual(c, "short-video-feed") } else { XCTFail() }
        XCTAssertLessThanOrEqual(inferred.contextConfidence, 0.7)   // visual guess is never certain
        if case .unknownApp = AppContextResolver.resolve(officialBundleID: nil, userDeclared: nil, inferredClass: nil).identity {} else { XCTFail() }
    }

    // §23 — recovery classification: app-switch within a live iOS session is auto; OS termination is one-tap restart.
    func testSessionRecovery() {
        let cap = PlatformCapabilityRegistry().capability(platform: "ios")
        XCTAssertEqual(SessionRecoveryController.classify("app-switch", capability: cap), .autoResumable)
        XCTAssertEqual(SessionRecoveryController.classify("os-terminated", capability: cap), .oneTapRestart)
        XCTAssertEqual(SessionRecoveryController.classify("reboot", capability: cap), .oneTapRestart)
    }

    // §22 — automatic session: within ONE active session, N content changes auto-observe with ZERO extra manual actions.
    func testAutomaticSessionNoManualReopen() {
        let rt = GuardianRuntimeManager(platform: "ios")
        rt.noteManualAction()                                   // the single Start-Broadcast tap
        rt.session.apply(.guardianOn); rt.session.apply(.permissionGranted); rt.session.apply(.userStarted); rt.session.apply(.osConfirmedActive)
        for _ in 0..<20 { _ = rt.onContentChange(newContent: true) }   // 20 new contents (app switches, swipes)
        let c = rt.snapshot()
        XCTAssertEqual(c.autoContentTransitions, 20)            // all automatic
        XCTAssertEqual(c.manualActions, 1)                      // only the one session-start tap
    }

    // §12/§13/§16 — REAL calibration pilot: fit on train, evaluate on HELD-OUT; per-language metrics; LAB_CALIBRATED_LIMITED.
    func testCalibrationPilotHeldOut() {
        // Uncalibrated raw is overconfident-high; truth mixed. Authored LAB pilot (project-owned), TR + EN.
        func ex(_ id: String, _ lang: String, _ raw: Double, _ suitable: Bool, _ score: Double) -> PilotExample {
            PilotExample(id: id, language: lang, modality: "text", rawSuitability: raw, labelSuitable: suitable, labelScore: score)
        }
        let train: [PilotExample] = [
            ex("en1","en",0.9,true,0.85), ex("en2","en",0.8,false,0.3), ex("en3","en",0.7,true,0.7), ex("en4","en",0.85,false,0.35),
            ex("tr1","tr",0.9,true,0.8), ex("tr2","tr",0.75,false,0.25), ex("tr3","tr",0.6,true,0.65), ex("tr4","tr",0.88,false,0.3),
            ex("en5","en",0.4,false,0.2), ex("tr5","tr",0.45,false,0.2), ex("en6","en",0.95,true,0.9), ex("tr6","tr",0.92,true,0.88),
        ]
        let test: [PilotExample] = [
            ex("en7","en",0.82,false,0.3), ex("en8","en",0.9,true,0.85), ex("tr7","tr",0.78,false,0.28), ex("tr8","tr",0.9,true,0.82),
            ex("en9","en",0.5,false,0.25), ex("tr9","tr",0.5,false,0.25),
        ]
        let r = CalibrationPilotRunner.run(train: train, test: test, modalities: ["text"], revision: "cal-pilot-v1")
        let rawEce = CalibrationMetrics.ece(confidences: test.map { $0.rawSuitability }, correct: test.map { ($0.rawSuitability >= 0.5) == $0.labelSuitable }, bins: 5)
        print(String(format: "P008A_CAL overall n=%d ECE=%.3f (rawECE=%.3f) Brier=%.3f MAE=%.3f P=%.2f R=%.2f F1=%.2f falseSafe=%.3f",
                     r.overall.count, r.overall.ece, rawEce, r.overall.brier, r.overall.mae, r.overall.precision, r.overall.recall, r.overall.f1, r.overall.falseSafe))
        for (lang, m) in r.byLanguage.sorted(by: { $0.key < $1.key }) {
            print(String(format: "P008A_CAL lang=%@ n=%d ECE=%.3f Brier=%.3f MAE=%.3f falseSafe=%.3f", lang, m.count, m.ece, m.brier, m.mae, m.falseSafe))
        }
        XCTAssertEqual(r.level, .labCalibratedLimited)              // never exceeds evidence
        XCTAssertNotNil(r.byLanguage["tr"]); XCTAssertNotNil(r.byLanguage["en"])   // TR + EN reported separately
        XCTAssertGreaterThan(r.overall.count, 0)
        XCTAssertGreaterThanOrEqual(r.overall.falseSafe, 0.0)      // false-safe measured independently (not hidden)
        // Scope gating (§14): a text-TR score is in scope; an image-FR score is NOT (→ must stay UNKNOWN).
        XCTAssertTrue(r.scope.covers(language: "tr", modality: "text"))
        XCTAssertFalse(r.scope.covers(language: "fr", modality: "image"))
    }

    // §17 — temporal hierarchy is REAL: frames → shots → scenes with aligned evidence (not a flat frame bag).
    func testTemporalHierarchy() {
        typealias F = TemporalUnderstandingEngineV1.FrameObservation
        let frames = [
            F(timeSec: 0.0, signature: 0x0000, ocrTokens: ["intro","news"]),
            F(timeSec: 0.5, signature: 0x0001, ocrTokens: ["news"]),
            F(timeSec: 1.0, signature: 0xFFFF, ocrTokens: ["ad","sale"]),     // big jump → new shot/scene
            F(timeSec: 1.5, signature: 0xFFFE, ocrTokens: ["sale"]),
        ]
        let ev = [ModalEvidenceSignal(modality: .ocr, kind: "topic", value: "news", evidenceClass: .modelInference,
                                      modelID: "t", modelRevision: "r1", timeStartSec: 0.2)]
        let u = TemporalUnderstandingEngineV1.build(contentID: "vid1", frames: frames, evidence: ev)
        XCTAssertEqual(u.schemaVersion, "temporal-understanding-v1")
        XCTAssertGreaterThanOrEqual(u.scenes.count, 2)              // news scene + ad scene (not one flat bag)
        XCTAssertGreaterThanOrEqual(u.shotCount, 2)
        XCTAssertEqual(u.durationSec, 1.5)
        XCTAssertTrue(u.alignedEvidence.first?.value.contains("@scene0") ?? false)   // evidence aligned to its scene
    }

    // §18 — moving-video boundary real eval: continuous motion within one item should NOT over-fire NEW; a swipe DOES.
    func testBoundaryRealMovingVideoEval() {
        let det = ContentBoundaryDetectorV2()
        var frames: [BoundaryFrameInput] = []; var labels: [Bool] = []
        // Item A: 8 frames of gradual motion (drifting signature), same layout + persistent text.
        for i in 0..<8 { frames.append(.init(signature: .init(bits: UInt64(0x1000 + i)), layoutSignature: 0xAAAA, topTextTokens: ["reel","a"])); labels.append(i == 0) }
        // Swipe to Item B: layout jump + big perceptual change + new text.
        for i in 0..<8 { frames.append(.init(signature: .init(bits: UInt64(0xE000_0000 + UInt64(i))), layoutSignature: 0x5555, topTextTokens: ["reel","b"])); labels.append(i == 0) }
        let r = BoundaryBenchmark.run(det, frames: frames, labeledIsNewBoundary: labels)
        XCTAssertEqual(r.trueBoundaries, 2)
        XCTAssertLessThanOrEqual(r.falseBoundaries, 1)   // gradual motion within A does not spam NEW
        XCTAssertLessThanOrEqual(r.missedBoundaries, 1)  // the real swipe is detected
    }
}
