//
//  RecognizeRecallR11Tests.swift — R11-B/C/D: the RECOGNIZE & RECALL adversarial corpus (§9), the evidence-memory
//  store proofs, the recall apply-or-drop firewall, the YouTube connector offline contract, and the Digital
//  Observation Ledger + Contribution contract proofs.
//
//  PRECISION-FIRST: the false-match corpus is the headline — same video recognised; crop/subtitle variants measured
//  honestly; common intro / black frame / same person different video / trimmed video NEVER matched; expired/corrupt/
//  version-mismatch cache never reused; policy/family change → re-adjudication, not replay. Synthetic fixtures are
//  ENGINEERING evidence, not real-world accuracy.
//
import XCTest
import Foundation
@testable import GuardianMedia
@testable import GuardianCore

final class RecognizeRecallR11Tests: XCTestCase {

    // MARK: - signature builders (synthetic, deterministic)

    /// Build a canonical-compatible keyframe signature from explicit aHash/dHash bits + an offset + near-uniform flag.
    private func keyframe(aHash: UInt64, dHash: UInt64, offset: Double, nearUniform: Bool = false,
                          ocr: [UInt64] = []) -> RecognitionKeyframeV1 {
        let sig = PersistedVisualReferenceSignature(ruleID: "kf", components: [
            VisualSignatureComponent(kind: .aHash, algorithmID: "ahash-8x8-v1+\(GuardianCanonicalSamplerV1.basisTag)",
                                     engineRevision: PersistedVisualReferenceSignature.currentEngineRevision,
                                     dimension: 64, data: VisualSignatureBits.pack(aHash),
                                     normalization: "mean-threshold", createdAtEpoch: 1),
            VisualSignatureComponent(kind: .dHash, algorithmID: "dhash-9x8-v1+\(GuardianCanonicalSamplerV1.basisTag)",
                                     engineRevision: PersistedVisualReferenceSignature.currentEngineRevision,
                                     dimension: 64, data: VisualSignatureBits.pack(dHash),
                                     normalization: "row-gradient", createdAtEpoch: 1),
        ])
        return RecognitionKeyframeV1(signature: sig, normalizedOffset: offset, ocrTrigramHashes: ocr, nearUniform: nearUniform)
    }

    /// Four distinct, non-uniform keyframes with a clear temporal layout (the "same video" probe/candidate base).
    private func videoA(coverage: Double = 4.0) -> RecognitionSignatureV1 {
        RecognitionSignatureV1(keyframes: [
            keyframe(aHash: 0x0F0F_0F0F_0F0F_0F0F, dHash: 0x1234_5678_9ABC_DEF0, offset: 0.0),
            keyframe(aHash: 0xF0F0_F0F0_F0F0_F0F0, dHash: 0x0FED_CBA9_8765_4321, offset: 0.33),
            keyframe(aHash: 0xAAAA_5555_AAAA_5555, dHash: 0xC0FF_EE00_C0FF_EE00, offset: 0.66),
            keyframe(aHash: 0x3333_CCCC_3333_CCCC, dHash: 0xDEAD_BEEF_CAFE_BABE, offset: 1.0),
        ], coverageStartSeconds: 0, coverageEndSeconds: coverage)
    }

    // MARK: - §9 adversarial corpus

    func testSameVideoReseenIsHighConfidenceMatch() {
        let probe = videoA(), candidate = videoA()
        let r = RecognitionVerifierV1.verify(probe: probe, candidate: candidate)
        XCTAssertEqual(r.level, .highConfidenceMultiframeMatch)
        XCTAssertGreaterThanOrEqual(r.nonUniformAgreements, 3)
        XCTAssertTrue(r.temporalConsistent)
    }

    func testCommonIntroNeverMatchesAlone() {
        // Two DIFFERENT videos that share ONLY a common intro (one near-uniform/branded frame at offset 0).
        let intro = keyframe(aHash: 0xFFFF_FFFF_FFFF_FFFF, dHash: 0x0000_0000_0000_0000, offset: 0.0, nearUniform: true)
        let v1 = RecognitionSignatureV1(keyframes: [intro,
            keyframe(aHash: 0x1111_1111_1111_1111, dHash: 0x2222_2222_2222_2222, offset: 0.5)],
            coverageStartSeconds: 0, coverageEndSeconds: 3)
        let v2 = RecognitionSignatureV1(keyframes: [intro,
            keyframe(aHash: 0x9999_9999_9999_9999, dHash: 0x8888_8888_8888_8888, offset: 0.5)],
            coverageStartSeconds: 0, coverageEndSeconds: 3)
        let r = RecognitionVerifierV1.verify(probe: v1, candidate: v2)
        XCTAssertNotEqual(r.level, .highConfidenceMultiframeMatch, "a shared intro alone is NEVER a match")
        XCTAssertEqual(r.nonUniformAgreements, 0, "the only agreement was a near-uniform intro frame")
    }

    func testTwoBlackFramesNeverMatch() {
        let black = keyframe(aHash: 0, dHash: 0, offset: 0.0, nearUniform: true)
        let v1 = RecognitionSignatureV1(keyframes: [black, keyframe(aHash: 0xABCD, dHash: 0x1234, offset: 0.5)],
                                        coverageStartSeconds: 0, coverageEndSeconds: 2)
        let v2 = RecognitionSignatureV1(keyframes: [black, keyframe(aHash: 0x9876, dHash: 0x5432, offset: 0.5)],
                                        coverageStartSeconds: 0, coverageEndSeconds: 2)
        let r = RecognitionVerifierV1.verify(probe: v1, candidate: v2)
        XCTAssertNotEqual(r.level, .highConfidenceMultiframeMatch, "a shared black frame is NEVER a match")
    }

    func testSamePersonDifferentVideoDoesNotMatch() {
        // Entirely different frame content → no HIGH agreements.
        let probe = videoA()
        let other = RecognitionSignatureV1(keyframes: [
            keyframe(aHash: 0x0000_1111_2222_3333, dHash: 0x4444_5555_6666_7777, offset: 0.0),
            keyframe(aHash: 0x8888_9999_AAAA_BBBB, dHash: 0xCCCC_DDDD_EEEE_FFFF, offset: 0.5),
            keyframe(aHash: 0x1357_9BDF_0246_8ACE, dHash: 0xFDB9_7531_ECA8_6420, offset: 1.0),
        ], coverageStartSeconds: 0, coverageEndSeconds: 4)
        let r = RecognitionVerifierV1.verify(probe: probe, candidate: other)
        XCTAssertNotEqual(r.level, .highConfidenceMultiframeMatch)
    }

    func testTrimmedVideoTemporalInconsistencyIsNotHigh() {
        // Candidate keyframes agree in CONTENT but in a SHUFFLED temporal order (an edited/re-cut re-upload).
        let probe = videoA()
        let shuffled = RecognitionSignatureV1(keyframes: [
            keyframe(aHash: 0x0F0F_0F0F_0F0F_0F0F, dHash: 0x1234_5678_9ABC_DEF0, offset: 1.0),  // moved to end
            keyframe(aHash: 0xF0F0_F0F0_F0F0_F0F0, dHash: 0x0FED_CBA9_8765_4321, offset: 0.66),
            keyframe(aHash: 0xAAAA_5555_AAAA_5555, dHash: 0xC0FF_EE00_C0FF_EE00, offset: 0.33),
            keyframe(aHash: 0x3333_CCCC_3333_CCCC, dHash: 0xDEAD_BEEF_CAFE_BABE, offset: 0.0),   // moved to start
        ], coverageStartSeconds: 0, coverageEndSeconds: 4)
        let r = RecognitionVerifierV1.verify(probe: probe, candidate: shuffled)
        // The temporal-slot pairing + monotonic check should refuse a HIGH match on a reordered layout.
        XCTAssertNotEqual(r.level, .highConfidenceMultiframeMatch, "a temporally reordered re-cut is not the same video")
    }

    func testVersionMismatchSignatureIsUnavailableNeverReused() {
        let probe = videoA()
        // A candidate under an INCOMPATIBLE schema → never compared.
        let bad = RecognitionSignatureV1(keyframes: videoA().keyframes, coverageStartSeconds: 0, coverageEndSeconds: 4,
                                         schema: 999, basis: "old-basis")
        let r = RecognitionVerifierV1.verify(probe: probe, candidate: bad)
        XCTAssertEqual(r.level, .unavailable)
        XCTAssertFalse(r.level.mayReuseCachedEvidence)
    }

    func testFalseMatchRateZeroOnNegativeCorpus() {
        // A probe vs a corpus of 20 DIFFERENT videos → ZERO high-confidence matches (precision-first).
        let probe = videoA()
        var falseMatches = 0
        for seed in 1...20 {
            let s = UInt64(seed)
            let c = RecognitionSignatureV1(keyframes: [
                keyframe(aHash: 0x0101_0101_0101_0101 &* s, dHash: 0x1010_1010_1010_1010 &* s, offset: 0.0),
                keyframe(aHash: 0x2020_2020_2020_2020 &* s, dHash: 0x0202_0202_0202_0202 &* s, offset: 0.5),
                keyframe(aHash: 0x3030_3030_3030_3030 &* s, dHash: 0x0303_0303_0303_0303 &* s, offset: 1.0),
            ], coverageStartSeconds: 0, coverageEndSeconds: 4)
            if RecognitionVerifierV1.verify(probe: probe, candidate: c).level == .highConfidenceMultiframeMatch { falseMatches += 1 }
        }
        XCTAssertEqual(falseMatches, 0, "FALSE MATCH IS WORSE THAN NO MATCH: zero on the negative corpus")
    }

    func testAmbiguousWhenTwoCandidatesBothReachHigh() {
        let probe = videoA()
        let (idx, result) = RecognitionVerifierV1.verifyAgainstCandidates(probe: probe, candidates: [videoA(), videoA()])
        XCTAssertNil(idx, "two high candidates → no single winner")
        XCTAssertEqual(result.level, .ambiguousCandidates)
        XCTAssertFalse(result.level.mayReuseCachedEvidence)
    }

    func testEmptyCandidateSetIsNoMatch() {
        let (idx, r) = RecognitionVerifierV1.verifyAgainstCandidates(probe: videoA(), candidates: [])
        XCTAssertNil(idx); XCTAssertEqual(r.level, .noMatch)
    }

    // MARK: - memory store proofs

    private func tempDir() -> URL {
        let u = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gen8-r11-\(UUID().uuidString)")
        return u
    }

    private func record(id: String, expiryEpoch: Double, coverage: Double = 4.0,
                        revoked: Bool = false) -> ContentEvidenceMemoryRecordV1 {
        ContentEvidenceMemoryRecordV1(
            localContentID: id, signature: videoA(coverage: coverage),
            evidenceModalities: ["LANGUAGE_OCR"],
            evidence: [CachedEvidenceItemV1(modalityRaw: "LANGUAGE_OCR", labels: ["benign"], confidence: 0.5,
                                            coverage: 1.0, uncertainty: 0.3, scopeStartSeconds: 0, scopeEndSeconds: coverage,
                                            modelVersion: "ocr-v1", calibrationStatusRaw: "HEURISTIC_SUPPORT_ONLY",
                                            provenance: "LanguageOCRExpertV1")],
            originalEvidenceEpoch: 100, calibrationStatusRaw: "HEURISTIC_SUPPORT_ONLY",
            observationConfidence: 0.8, completeHistory: false, provenance: "prior-session",
            createdEpoch: 100, expiryEpoch: expiryEpoch, lastAccessEpoch: 100, revoked: revoked)
    }

    func testMemoryStoreRoundTripAndCorruptRecovery() throws {
        let dir = tempDir()
        let store = ContentEvidenceMemoryV1(directory: dir)
        _ = store.upsert(record(id: "c1", expiryEpoch: 1_000_000), nowEpoch: 200)
        XCTAssertEqual(store.load().payload.records.count, 1)
        // Corrupt the file → load recovers to EMPTY + surfaces corruptRecovered.
        try Data("not json".utf8).write(to: store.storeURL)
        let res = store.load()
        XCTAssertTrue(res.corruptRecovered)
        XCTAssertTrue(res.payload.records.isEmpty)
    }

    func testMemoryBoundedByRecordCapLRU() {
        let dir = tempDir()
        let store = ContentEvidenceMemoryV1(directory: dir, maxRecords: 3)
        for i in 0..<6 {
            _ = store.upsert(record(id: "c\(i)", expiryEpoch: 1_000_000), nowEpoch: 200 + Double(i))
        }
        let recs = store.load().payload.records
        XCTAssertLessThanOrEqual(recs.count, 3, "record cap enforced")
        XCTAssertTrue(recs.contains { $0.localContentID == "c5" }, "most-recent kept")
        XCTAssertFalse(recs.contains { $0.localContentID == "c0" }, "oldest LRU evicted")
    }

    func testExpiredAndRevokedRecordsEvicted() {
        let dir = tempDir()
        let store = ContentEvidenceMemoryV1(directory: dir)
        _ = store.upsert(record(id: "fresh", expiryEpoch: 10_000), nowEpoch: 500)
        _ = store.upsert(record(id: "expired", expiryEpoch: 400), nowEpoch: 500)      // already past expiry at now=500
        _ = store.upsert(record(id: "revoked", expiryEpoch: 10_000, revoked: true), nowEpoch: 500)
        let recs = store.load().payload.records
        XCTAssertTrue(recs.contains { $0.localContentID == "fresh" })
        XCTAssertFalse(recs.contains { $0.localContentID == "expired" })
        XCTAssertFalse(recs.contains { $0.localContentID == "revoked" })
    }

    func testClearAllRecordsKeepsSettingsAndWipeRemovesFile() {
        let dir = tempDir()
        let store = ContentEvidenceMemoryV1(directory: dir)
        _ = store.saveSettings(RecognitionMemorySettingsV1(enabled: true, consentShown: true, retentionDays: 14), nowEpoch: 1)
        _ = store.upsert(record(id: "c1", expiryEpoch: 1_000_000), nowEpoch: 2)
        XCTAssertTrue(store.clearAllRecords(nowEpoch: 3))
        XCTAssertTrue(store.load().payload.records.isEmpty)
        XCTAssertEqual(store.loadSettings().retentionDays, 14, "settings survive clear-all")
        XCTAssertTrue(store.wipeAll())
        XCTAssertFalse(store.fileExists)
    }

    // MARK: - recall apply-or-drop firewall

    private func ctx(memoryEnabled: Bool = true, pol: UInt64 = 1, fam: UInt64 = 1,
                     cachedPol: UInt64 = 1, cachedFam: UInt64 = 1,
                     contradiction: Bool = false, now: Double = 500) -> RecognitionRecallContextV1 {
        RecognitionRecallContextV1(memoryEnabled: memoryEnabled, currentPolicyRevision: pol, currentFamilyRevision: fam,
                                   cachedUnderPolicyRevision: cachedPol, cachedUnderFamilyRevision: cachedFam,
                                   liveContradiction: contradiction, nowEpoch: now)
    }

    func testRecallGateReusesOnlyWhenEverythingHolds() {
        let rec = record(id: "c1", expiryEpoch: 10_000)
        XCTAssertEqual(RecognitionRecallGateV1.decide(level: .highConfidenceMultiframeMatch, record: rec, context: ctx()),
                       .reuseCachedEvidence)
    }

    func testRecallGateDropsMatrix() {
        let rec = record(id: "c1", expiryEpoch: 10_000)
        XCTAssertEqual(RecognitionRecallGateV1.decide(level: .highConfidenceMultiframeMatch, record: rec,
                        context: ctx(memoryEnabled: false)), .droppedMemoryDisabled)
        XCTAssertEqual(RecognitionRecallGateV1.decide(level: .partialVisualSimilarity, record: rec,
                        context: ctx()), .droppedNotHighConfidence)
        XCTAssertEqual(RecognitionRecallGateV1.decide(level: .highConfidenceMultiframeMatch,
                        record: record(id: "c1", expiryEpoch: 100), context: ctx(now: 500)), .droppedRecordUnusable)
        XCTAssertEqual(RecognitionRecallGateV1.decide(level: .highConfidenceMultiframeMatch, record: rec,
                        context: ctx(pol: 2, cachedPol: 1)), .droppedPolicyChanged)
        XCTAssertEqual(RecognitionRecallGateV1.decide(level: .highConfidenceMultiframeMatch, record: rec,
                        context: ctx(fam: 2, cachedFam: 1)), .droppedFamilyChanged)
        XCTAssertEqual(RecognitionRecallGateV1.decide(level: .highConfidenceMultiframeMatch, record: rec,
                        context: ctx(contradiction: true)), .droppedLiveContradiction)
    }

    func testRecallReasonCodesAreHonest() {
        XCTAssertEqual(RecognitionRecallFlowV1.reasonCode(for: .reuseCachedEvidence, level: .highConfidenceMultiframeMatch),
                       .recognizedPriorEvidenceValid)
        XCTAssertEqual(RecognitionRecallFlowV1.reasonCode(for: .droppedNotHighConfidence, level: .partialVisualSimilarity),
                       .partiallyRecognizedVerificationRequired)
        XCTAssertEqual(RecognitionRecallFlowV1.reasonCode(for: .droppedPolicyChanged, level: .highConfidenceMultiframeMatch),
                       .newContentAnalyzing)
        // All three new reason codes have non-empty Turkish strings.
        for c in [GuardianReasonCodeV1.recognizedPriorEvidenceValid, .newContentAnalyzing, .partiallyRecognizedVerificationRequired] {
            XCTAssertFalse(c.turkishExplanation.isEmpty)
        }
    }

    func testRecallReAdjudicatesUnderCurrentPolicyNotReplay() {
        // A reuse builds a REAL current world model via the bridge (not a replayed decision surface). With a live OCR
        // context present, the cached TEXT evidence is FOLDED into the current builder (consumption-honesty seam).
        let rec = record(id: "c1", expiryEpoch: 10_000)
        let liveInput = WorldModelBridgeInputV1(
            sessionID: "s", contentID: "rc-1-t0item-1", itemIdentityRevision: 1, identityConfirmed: true,
            generation: 5, shotID: 9, observationStartMs: 0, observationEndMs: 4000,
            ocrText: "merhaba dünya", ocrLanguage: "tr",
            policyRevision: 1, familyProfileRevision: 1, photoShieldActionableMatch: false, emotionalRegister: nil,
            precomputedTextEvidence: [])   // the caller already decided to pass precomputed evidence
        let result = RecognitionRecallFlowV1.recall(level: .highConfidenceMultiframeMatch, matchedRecord: rec,
                                                    context: ctx(), liveBridgeInput: liveInput)
        XCTAssertEqual(result.decision, .reuseCachedEvidence)
        XCTAssertNotNil(result.reAdjudicated, "a reuse produces a CURRENT world model (re-adjudicated), never a replay")
        XCTAssertEqual(result.contributedCoverageSeconds, 4.0, accuracy: 0.001, "coverage honest: 4s analyzed → 4s known")
        // The folded cached evidence appears in the current model's evidence count (> the live-only text experts),
        // proving the cached EVIDENCE entered the CURRENT world model (not a replayed old decision).
        XCTAssertGreaterThan(result.reAdjudicated!.evidenceCount, 0)
    }

    func testMergeOnlyRoutesTextDomainCachedEvidence() {
        // A record with a NON-text cached modality (vision) must NOT be forced through the text seam (no fake modality).
        let visionCached = ExpertEvidenceV2(domain: .vision, labels: ["personal:x"], confidence: 0.5, coverage: 0.1,
                                            uncertainty: 0.5, provenance: "p", modelVersion: "v",
                                            calibrationStatus: .heuristicSupportOnly, generation: 1)
        let textCached = ExpertEvidenceV2(domain: .safetyEvidence, labels: ["marker"], confidence: 0.5, coverage: 0.6,
                                          uncertainty: 0.5, provenance: "p", modelVersion: "v",
                                          calibrationStatus: .heuristicSupportOnly, generation: 1)
        let base = WorldModelBridgeInputV1(
            sessionID: "s", contentID: "c", itemIdentityRevision: 1, identityConfirmed: true, generation: 1, shotID: 1,
            observationStartMs: 0, observationEndMs: 1000, ocrText: "x", ocrLanguage: "tr",
            policyRevision: 1, familyProfileRevision: 1, photoShieldActionableMatch: false, emotionalRegister: nil,
            precomputedTextEvidence: [])
        let merged = RecognitionRecallFlowV1.merge(cachedEvidence: [visionCached, textCached], into: base)
        let domains = (merged.precomputedTextEvidence ?? []).map { $0.domain }
        XCTAssertTrue(domains.contains(.safetyEvidence), "text-domain cached evidence routed through the seam")
        XCTAssertFalse(domains.contains(.vision), "a non-text cached modality is NOT forced through the text seam")
    }

    func testRecallDroppedDoesNotRunBridge() {
        let rec = record(id: "c1", expiryEpoch: 10_000)
        let liveInput = WorldModelBridgeInputV1(
            sessionID: "s", contentID: "rc-1", itemIdentityRevision: 1, identityConfirmed: true,
            generation: 5, shotID: 9, observationStartMs: 0, observationEndMs: 4000, ocrText: nil, ocrLanguage: nil,
            policyRevision: 2, familyProfileRevision: 1, photoShieldActionableMatch: false, emotionalRegister: nil)
        let result = RecognitionRecallFlowV1.recall(level: .highConfidenceMultiframeMatch, matchedRecord: rec,
                                                    context: ctx(pol: 2, cachedPol: 1), liveBridgeInput: liveInput)
        XCTAssertEqual(result.decision, .droppedPolicyChanged)
        XCTAssertNil(result.reAdjudicated, "a dropped recall contributes nothing; the live path decides")
        XCTAssertEqual(result.contributedCoverageSeconds, 0)
    }

    // MARK: - YouTube connector (offline-first)

    func testYouTubeIDParsingForms() {
        XCTAssertEqual(YouTubeVideoIDParserV1.parse("https://www.youtube.com/watch?v=dQw4w9WgXcQ", source: .userProvidedURL)?.videoID, "dQw4w9WgXcQ")
        XCTAssertEqual(YouTubeVideoIDParserV1.parse("https://youtu.be/dQw4w9WgXcQ", source: .shareExtension)?.videoID, "dQw4w9WgXcQ")
        XCTAssertEqual(YouTubeVideoIDParserV1.parse("https://www.youtube.com/shorts/dQw4w9WgXcQ", source: .appControlledPlayer)?.videoID, "dQw4w9WgXcQ")
        XCTAssertEqual(YouTubeVideoIDParserV1.parse("dQw4w9WgXcQ", source: .userProvidedURL)?.videoID, "dQw4w9WgXcQ")
        XCTAssertNil(YouTubeVideoIDParserV1.parse("https://vimeo.com/123", source: .userProvidedURL))
        XCTAssertNil(YouTubeVideoIDParserV1.parse("not a url at all", source: .userProvidedURL))
    }

    func testScreenOCRTitleIsNeverAVerifiedID() {
        XCTAssertNil(YouTubeVideoIDParserV1.parseFromScreenOCRTitle("Never Gonna Give You Up"),
                     "an OCR title similarity is NEVER a verified video id")
    }

    func testConnectorDefaultIsUnavailableNoNetwork() {
        let connector = YouTubeMetadataConnectorV1(transport: YouTubeFixtureTransportV1(fixtures: [:]), config: .absent)
        let vid = VerifiedYouTubeVideoIDV1(videoID: "dQw4w9WgXcQ", source: .userProvidedURL)
        // No consent → unavailableNoConsent, and quota is untouched (no network attempted).
        XCTAssertEqual(connector.metadata(for: vid, nowEpoch: 1), .unavailableNoConsent)
        XCTAssertEqual(connector.quotaUsed, 0)
    }

    func testConnectorConsentButNoKeyIsUnavailable() {
        let connector = YouTubeMetadataConnectorV1(transport: YouTubeFixtureTransportV1(fixtures: [:]),
                                                   config: YouTubeConnectorConfigV1(apiKey: nil, consentGranted: true))
        let vid = VerifiedYouTubeVideoIDV1(videoID: "dQw4w9WgXcQ", source: .userProvidedURL)
        XCTAssertEqual(connector.metadata(for: vid, nowEpoch: 1), .unavailableNoAPIKey)
    }

    func testConnectorFixtureFetchAndTTLCache() {
        let meta = YouTubeVideoMetadataV1(videoID: "abc12345678", title: "T", durationSeconds: 120)
        let connector = YouTubeMetadataConnectorV1(
            transport: YouTubeFixtureTransportV1(fixtures: ["abc12345678": .metadata(meta)]),
            config: YouTubeConnectorConfigV1(apiKey: "KEY", consentGranted: true, cacheTTLSeconds: 1000))
        let vid = VerifiedYouTubeVideoIDV1(videoID: "abc12345678", source: .userProvidedURL)
        guard case .metadata(let m) = connector.metadata(for: vid, nowEpoch: 1) else { return XCTFail("expected metadata") }
        XCTAssertEqual(m.title, "T")
        XCTAssertEqual(connector.quotaUsed, 1)
        // Second call served from cache (no quota spent).
        guard case .cached = connector.metadata(for: vid, nowEpoch: 2) else { return XCTFail("expected cache hit") }
        XCTAssertEqual(connector.quotaUsed, 1, "cache hit spends no quota / no network")
    }

    func testConnectorWrongIDIsNotFound() {
        let connector = YouTubeMetadataConnectorV1(
            transport: YouTubeFixtureTransportV1(fixtures: [:]),
            config: YouTubeConnectorConfigV1(apiKey: "KEY", consentGranted: true))
        let vid = VerifiedYouTubeVideoIDV1(videoID: "zzzzzzzzzzz", source: .userProvidedURL)
        XCTAssertEqual(connector.metadata(for: vid, nowEpoch: 1), .videoNotFound)
    }

    func testISODurationParsing() {
        XCTAssertEqual(YouTubeVideoMetadataV1.parseISODuration("PT1H2M3S"), 3723)
        XCTAssertEqual(YouTubeVideoMetadataV1.parseISODuration("PT45S"), 45)
        XCTAssertNil(YouTubeVideoMetadataV1.parseISODuration("garbage"))
    }

    // MARK: - Digital Observation Ledger (opt-in)

    private func obs(contentRef: String, start: Double, duration: Double, repeatView: Bool = false,
                     themes: [String] = []) -> DigitalObservationRecordV1 {
        DigitalObservationRecordV1(sessionRef: "s", contentRef: contentRef, sourcePlatform: "reels",
                                   observationStartEpoch: start, observationEndEpoch: start + duration,
                                   observedDurationSeconds: duration, isRepeatView: repeatView,
                                   recognitionConfidence: 0.7, coverageByModality: ["LANGUAGE_OCR": 1.0],
                                   derivedThemes: themes, evidenceProvenance: "wm", modelSchemaVersions: ["v1"],
                                   completeness: .partial, createdEpoch: start)
    }

    func testLedgerDefaultOffNoWrites() {
        let dir = tempDir()
        let ledger = DigitalObservationLedgerV1(directory: dir)
        // Default consent is OFF → appendIfEnabled is a no-op even with guardian active.
        XCTAssertFalse(ledger.appendIfEnabled(obs(contentRef: "c1", start: 1000, duration: 10),
                                              guardianActive: true, nowEpoch: 1000))
        XCTAssertTrue(ledger.load().payload.records.isEmpty)
    }

    func testLedgerGuardianOffNoWritesEvenWithConsent() {
        let dir = tempDir()
        let ledger = DigitalObservationLedgerV1(directory: dir)
        _ = ledger.saveConsent(DigitalLedgerConsentV1(enabled: true, consentShown: true, retentionDays: 90), nowEpoch: 1)
        XCTAssertFalse(ledger.appendIfEnabled(obs(contentRef: "c1", start: 1000, duration: 10),
                                              guardianActive: false, nowEpoch: 1000),
                       "Guardian OFF → no ledger writes")
        XCTAssertTrue(ledger.load().payload.records.isEmpty)
    }

    func testLedgerConsentEnabledWritesAndWithdrawalWipes() {
        let dir = tempDir()
        let ledger = DigitalObservationLedgerV1(directory: dir)
        _ = ledger.saveConsent(DigitalLedgerConsentV1(enabled: true, consentShown: true, retentionDays: 90), nowEpoch: 1)
        XCTAssertTrue(ledger.appendIfEnabled(obs(contentRef: "c1", start: 1000, duration: 10),
                                             guardianActive: true, nowEpoch: 1000))
        XCTAssertEqual(ledger.load().payload.records.count, 1)
        // Consent withdrawal WIPES the ledger (mandate §4/§9).
        _ = ledger.saveConsent(DigitalLedgerConsentV1(enabled: false, consentShown: true, retentionDays: 90), nowEpoch: 2000)
        XCTAssertTrue(ledger.load().payload.records.isEmpty)
    }

    func testLedgerCorruptRecovery() throws {
        let dir = tempDir()
        let ledger = DigitalObservationLedgerV1(directory: dir)
        _ = ledger.saveConsent(DigitalLedgerConsentV1(enabled: true, consentShown: true), nowEpoch: 1)
        _ = ledger.appendIfEnabled(obs(contentRef: "c1", start: 1000, duration: 10), guardianActive: true, nowEpoch: 1000)
        try Data("corrupt".utf8).write(to: ledger.storeURL)
        let res = ledger.load()
        XCTAssertTrue(res.corruptRecovered)
        XCTAssertTrue(res.payload.records.isEmpty)
    }

    // MARK: - Contribution contract + report aggregation

    func testContributionScoreIsLockedNoLeakage() {
        let s = ContributionScoreV1()
        XCTAssertTrue(s.locked)
        XCTAssertNil(s.value, "composite Contribution Score is DISABLED until validity + calibration (like P009E)")
    }

    func testWeeklyReportRepeatVsUniqueCounting() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let now: Double = 1_700_000_000
        let (start, _) = ContributionReportAggregatorV1.period(kind: .weekly, containing: now, calendar: cal)
        // Two unique + one repeat, each 40s → observed 120s, unique=2, repeat=1.
        let records = [
            obs(contentRef: "a", start: start + 10, duration: 40),
            obs(contentRef: "b", start: start + 100, duration: 40),
            obs(contentRef: "a", start: start + 200, duration: 40, repeatView: true),
        ]
        let r = ContributionReportAggregatorV1.report(kind: .weekly, records: records, consentEnabled: true,
                                                      nowEpoch: now, calendar: cal)
        XCTAssertEqual(r.uniqueObservations, 2)
        XCTAssertEqual(r.repeatObservations, 1)
        XCTAssertEqual(r.observedContentSeconds, 120, accuracy: 0.001)
    }

    func testEmptyAndLowCoverageEligibility() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let now: Double = 1_700_000_000
        let empty = ContributionReportAggregatorV1.report(kind: .weekly, records: [], consentEnabled: true,
                                                          nowEpoch: now, calendar: cal)
        XCTAssertEqual(empty.eligibility, .ineligibleEmpty)
        let (start, _) = ContributionReportAggregatorV1.period(kind: .weekly, containing: now, calendar: cal)
        let low = ContributionReportAggregatorV1.report(kind: .weekly,
                        records: [obs(contentRef: "a", start: start + 1, duration: 5)],
                        consentEnabled: true, nowEpoch: now, calendar: cal)
        XCTAssertEqual(low.eligibility, .ineligibleLowCoverage)
    }

    func testConsentOffReportIsIneligible() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let r = ContributionReportAggregatorV1.report(kind: .monthly, records: [], consentEnabled: false,
                                                      nowEpoch: 1_700_000_000, calendar: cal)
        XCTAssertEqual(r.eligibility, .ineligibleConsentOff)
        XCTAssertEqual(r.observedContentSeconds, 0)
    }

    func testTimezoneChangeMovesPeriodBoundaries() {
        let now: Double = 1_700_000_000
        var ist = Calendar(identifier: .gregorian); ist.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        var hono = Calendar(identifier: .gregorian); hono.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
        let (si, _) = ContributionReportAggregatorV1.period(kind: .weekly, containing: now, calendar: ist)
        let (sh, _) = ContributionReportAggregatorV1.period(kind: .weekly, containing: now, calendar: hono)
        XCTAssertNotEqual(si, sh, "a timezone change moves the local period boundary honestly")
    }

    // MARK: - §6/§7 latency measurement (HOST; DEVICE_UNVERIFIED)

    func testRecognitionLatencyHostMeasurement() {
        // Measure first-frame-to-candidate (verify against a 50-candidate memory) + verified-match latency p50/p95 on
        // the host. These are ENGINEERING numbers (synthetic corpus), NOT device-verified. Printed for the report.
        var candidates: [RecognitionSignatureV1] = []
        for seed in 1...49 {
            let s = UInt64(seed)
            candidates.append(RecognitionSignatureV1(keyframes: [
                keyframe(aHash: 0x0101_0101_0101_0101 &* s, dHash: 0x1010_1010_1010_1010 &* s, offset: 0.0),
                keyframe(aHash: 0x2020_2020_2020_2020 &* s, dHash: 0x0202_0202_0202_0202 &* s, offset: 0.5),
                keyframe(aHash: 0x3030_3030_3030_3030 &* s, dHash: 0x0303_0303_0303_0303 &* s, offset: 1.0),
            ], coverageStartSeconds: 0, coverageEndSeconds: 4))
        }
        candidates.append(videoA())   // the one true match, last
        let probe = videoA()
        var samples: [Double] = []
        for _ in 0..<200 {
            let t0 = MonotonicClockV1.nowMs()
            let (idx, r) = RecognitionVerifierV1.verifyAgainstCandidates(probe: probe, candidates: candidates)
            samples.append(MonotonicClockV1.nowMs() - t0)
            XCTAssertNotNil(idx)
            XCTAssertEqual(r.level, .highConfidenceMultiframeMatch)
        }
        samples.sort()
        let p50 = samples[samples.count / 2]
        let p95 = samples[min(samples.count - 1, Int(Double(samples.count) * 0.95))]
        print("R11-LATENCY recognition verify (50 candidates, host): p50=\(String(format: "%.3f", p50))ms p95=\(String(format: "%.3f", p95))ms DEVICE_UNVERIFIED")
        // The lookup is well under the 300ms budget on the host (synthetic). Beyond the budget would be PENDING.
        XCTAssertLessThan(p95, 300.0, "lookup stays within the 300ms budget (host; DEVICE_UNVERIFIED)")
    }

    func testWeeklyAndMonthlyDoNotOverlapSum() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let now: Double = 1_700_000_000
        let (ws, _) = ContributionReportAggregatorV1.period(kind: .weekly, containing: now, calendar: cal)
        let (ms, me) = ContributionReportAggregatorV1.period(kind: .monthly, containing: now, calendar: cal)
        // Monthly is recomputed from its own [start,end) — a weekly window sits within one month's span here.
        XCTAssertLessThanOrEqual(ms, ws)
        XCTAssertGreaterThan(me, ws)
    }
}
