# RECOGNIZE & RECALL R11 — Recognition Identity Contract + Evidence Memory + Observation Ledger

Status: IN PROGRESS (R11). Base HEAD `ff8efc5`. Branch `product/device-evidence-slice`.
Test baseline before this round: **GuardianMediaTests = 590 tests, 0 failures** (measured 2026-10-27, host macOS/swift).

This document records the DECISIONS (add-only) for R11-A/B/C/D. It is engineering evidence, not device-verified accuracy.

---

## R11-A — AUDIT

### R10 async-audio integrity
- Re-ran full `GuardianMediaTests`: **590 / 0 failures** including `AsyncAudioInferenceR10Tests`, `LiveAudioInferenceR9Tests`, `LiveAudioEvidenceR8Tests`, `RapidSwipeGateTests`, `WorldModelBridgeR5/R6Tests`. The R10 apply-or-drop firewall (`AudioAsyncRevalidatorV1`) + ownership store (`AudioHandoffStoreV1`) remain green. No regression introduced by R11 (re-measured at the end).

### RPBroadcastSampleHandler deprecation status (honest)
- Direct read of the installed ReplayKit SDK interface headers under `/Applications/Xcode.app` was attempted; the agent sandbox blocks/limits reading deep SDK framework interfaces.
- Per the canonical capture doctrine `docs/progress/APPLE_CAPTURE_STRATEGY_R3.md` (relied upon, as instructed): the broadcast-upload extension architecture built on `RPBroadcastSampleHandler.processSampleBuffer(_:with:)` is the SUPPORTED iOS screen-broadcast path and is NOT recorded as deprecated as of that document. R11 introduces NO new ReplayKit surface and does NOT replace any platform API. Any deprecation verification against live SDK headers is DEVICE/SDK-gated and remains an open check (not silently resolved).

---

## R11-B — RECOGNIZE & RECALL V1 — THE IDENTITY CONTRACT

### Core epistemic law (mandate §1)
Three states are NEVER interconverted:
- `OBSERVED_NOW` — part of the content actually seen on the permitted screen feed right now.
- `PREVIOUSLY_ANALYZED` — parts of the *same* content that were genuinely analyzed in a prior session, with a VALID cached evidence record.
- `UNOBSERVED_FUTURE` — not yet seen and with no valid prior analysis record. NEVER predicted.

PARTIAL HISTORY ≠ FULL VIDEO KNOWLEDGE. CONTENT RECOGNIZED ≠ CONTENT FULLY ANALYZED.
METADATA RETRIEVED ≠ VIDEO UNDERSTOOD. PREVIOUS SCORE ≠ CURRENT CALIBRATED SUITABILITY.

### No second identity brain
Recognition reuses the EXISTING canonical visual signature components only:
- `VisualSignatureComponent` (aHash64 / dHash64 / normVector256) from `GuardianCore/VisualSignature.swift` (frozen), built via the canonical area-average sampler `GuardianCanonicalSamplerV1`.
- `VisualSignatureComparator` (frozen) for per-keyframe Hamming/L2 distances.
- OCR trigram Jaccard (`Tier1TextSimilarityV1`) as an OPTIONAL per-keyframe text corroboration (salt `.none` for cross-session comparability — the memory store is device-local so cross-session linkage is intended within the device only).

A `RecognitionSignatureV1` = an explicitly versioned, ordered list of keyframe signatures (several temporal keyframes) + relative temporal layout (normalized keyframe offsets) + a coverage interval. It is NOT a new identity engine; it is a MULTI-KEYFRAME wrapper over the existing per-frame signature.

### Fingerprint schema version + collision model
- `RecognitionSignatureV1.schemaVersion = 1`; `basisTag = GuardianCanonicalSamplerV1.basisTag` carried through each component's `algorithmID`. A signature whose basis/engine revision is incompatible is NEVER compared (treated UNAVAILABLE / version-mismatch → no reuse).
- Collision model: a single aHash collision (64-bit perceptual hash) is CHEAP to collide on near-uniform frames (black frame, common intro). THEREFORE a match requires MULTIPLE keyframe agreements AND temporal-layout consistency. A single-frame agreement, a black/near-uniform frame agreement, or a common-intro agreement is structurally rejected (see verification ladder). FALSE MATCH IS WORSE THAN NO MATCH.

### Verification ladder (recognition levels; mandate §2.1)
Levels, from the pure `RecognitionVerifierV1`:
- `highConfidenceMultiframeMatch` — ≥ `minAgreeingKeyframes` keyframes agree at HIGH perceptual tier AND temporal layout is consistent AND at least one keyframe is NOT near-uniform (anti common-intro / anti black-frame). This is the only level that may contribute cached evidence.
- `partialVisualSimilarity` — some agreement but below the multiframe/temporal bar → surfaced as "kısmen tanındı", NO cached evidence reuse.
- `ambiguousCandidates` — multiple candidates compete / no clear winner → UNKNOWN, NO reuse.
- `noMatch` — nothing agreed.
- `unavailable` — signature incompatible / corrupt / probe could not be built.
(`verifiedPlatformId` is reserved for the YouTube connector path, R11-C — a lawful verified ID, not a visual match.)

Recognition level ≠ automatic decision authority. ONLY `highConfidenceMultiframeMatch` passes cached evidence forward, and even then through current-policy re-adjudication (never republished).

### Recognition hit → CURRENT decision (mandate §3.1 / §5)
Flow: fresh item resolved (`Tier1IdentityResolverV1`) → build probe `RecognitionSignatureV1` → `ContentEvidenceMemoryV1` candidate lookup (bounded) → `RecognitionVerifierV1` ladder → if `highConfidenceMultiframeMatch` AND the cached record is VALID under the CURRENT context (`RecognitionRecallGateV1` — a pure apply-or-drop mirroring `AudioAsyncRevalidatorV1`): the cached POLICY-INDEPENDENT evidence enters the CURRENT `WorldModelEvidenceBridgeV1` as provenance-marked CACHED evidence, with its ORIGINAL coverage intervals (4s analyzed → 4s known) → `WorldModelEvidenceBridgeV1.build` runs current experts/policy → CURRENT decision. The old surface/decision is NEVER republished.
- Ambiguous/partial → UNKNOWN; no cached influence.
- Contradiction with live observation → cache authority drops; the live resolver/current evidence decides (cache never overrides a contradicting live signal).
- Cache stale / policy or family revision changed / version-mismatch / expired / corrupt → NOT reused; re-adjudicate from live evidence (`RecognitionRecallDecisionV1` reasons are counted).

### What the memory stores / never stores (mandate §3 / §4)
`ContentEvidenceMemoryRecordV1` carries ONLY derived data: opaque local id, fingerprint schema+version/basis, observed coverage intervals, evidence modalities + model versions, POLICY-INDEPENDENT evidence payloads (the derived expert labels/coverage/calibration — NOT a decision), original evidence timestamps, calibration status, observation confidence, provenance, created/expiry epochs, deletion state.
NEVER stored: raw frames, OCR text, audio, screenshots, transcripts. Only the perceptual hash bytes + trigram HASHES (salted-none, device-local) + derived evidence scalars.

### User-visible states (Turkish — mandate §2 / §B4)
- `recognizedPriorEvidenceValid` → "Tanınan içerik — önceki kanıt geçerli."
- `newContentAnalyzing` → "Yeni içerik — analiz sürüyor."
- `partiallyRecognizedVerificationRequired` → "Kısmen tanındı — doğrulama gerekli."
- plus honest coverage string, e.g. "Önceden analiz edilen bölüm: ilk 4 sn."
These are new `GuardianReasonCodeV1` cases (exhaustive switches updated: `turkishExplanation`, `GuardianLabModel.confidence(for:)`).

### Memory controls (product shell; mandate §5)
`RecognitionMemorySettingsV1` (persisted via the same store): ON/OFF toggle (default ON, LOCAL-ONLY), record-type visibility, clear-all, retention choice (days). The extension RESPECTS the toggle: when OFF, no lookup, no write. Surfaced in the privacy/settings shell.

### Performance (mandate §6 / §7)
- Measured host p50/p95 for first-frame-to-candidate + verified-match latency (synthetic corpus) — recorded in the final report tables; DEVICE_UNVERIFIED.
- Lookup is bounded and OFF the video callback (the recognition probe/lookup pattern mirrors the R10 async coordinator; a `300ms` budget → PENDING beyond it, never a wrong match).
- No per-frame archive writes: the memory record is written at ITEM END / on a confidence threshold, never per frame.

---

## R11-C — YOUTUBE METADATA CONNECTOR (offline-first)
`YouTubeMetadataConnectorV1` (GuardianMedia): protocol-based transport (`YouTubeMetadataTransportV1`) so tests inject fixtures; a real `URLSession` transport exists behind an API-key config that is ABSENT by default → honest `UNAVAILABLE`.
- Verified-ID intake ONLY: `YouTubeVideoIDParserV1` validates `youtube.com/watch?v=`, `youtu.be/`, `shorts/` URL forms from a USER-PROVIDED URL / share contract / app-controlled context. Screen-OCR title similarity is NEVER a `VERIFIED_VIDEO_ID` (pinned by test).
- Response model mirrors `videos.list(part=snippet,contentDetails)` (id/channelId/title/description/tags/publishedAt/duration/caption availability/restrictions).
- Metadata enters the bridge as `PLATFORM_METADATA_EVIDENCE` — a context hint; coverage is UNAFFECTED (metadata ≠ video understood; duration known ≠ duration's content known).
- quota/TTL/unavailable/wrong-ID handling present.
- PRIVACY: an external call is a USER CONSENT GATE (documented; default OFF/absent key → no network).

NO live YouTube network call is made in this round (no API key infrastructure present). The connector is OFFLINE-testable via the fixture transport.

---

## R11-D — DIGITAL OBSERVATION LEDGER V1 + CONTRIBUTION CONTRACT
`DigitalObservationLedgerV1` (GuardianMedia, app-private store, OPT-IN, default OFF, consent flag; file-protection; bounded; full deletion; never uploaded).
- Per-item observation records: monotonic duration + calendar-aware local period stamps; repeated-view counting SEPARATE from unique items; coverage by modality honest; unobserved time NEVER counted.
- Writes OUTSIDE the video callback (aggregate at item end). Guardian OFF → no ledger writes.
`ContributionEvidenceContractV1` (pure types + this doc): three evidence classes CONTENT_SIGNAL / USER_OUTCOME / UNKNOWN_IMPACT; weekly (calendar week) + monthly (calendar month recomputed from eligible days, not overlapping weekly sums) report field contract; eligibility + partial-coverage declarations; a composite `ContributionScoreV1` type EXISTS but is LOCKED/DISABLED (same discipline as the P009E numeric lock; pinned by test). NO leakage between the P009E suitability score and the Contribution constructs (pinned by test). NO report UI this round (R12).

Contribution Score ≠ P009E Personal Suitability — separate constructs, labels, calibration, release gates. Educational-looking ≠ learning. Negative emotion ≠ harm. Longer watching ≠ more benefit. Entertainment/rest ≠ wasted time. No inferred mental-health/attention/learning-outcome claims.

---

## MEASURED RESULTS (host; synthetic; DEVICE_UNVERIFIED)
- `GuardianMediaTests`: **627 tests, 0 failures** (590 baseline + 37 new R11 tests; 1 pre-existing skip). Full package `swift build` complete, 0 errors.
- `GuardianCoreTests` census: 1110 tests, 18 failures, **(0 unexpected)** — the known lawful stale pins (frozen root; untouched by R11; never chased/edited).
- Recognition verify latency (probe vs 50-candidate memory, 200 iterations, host): **p50 = 1.75 ms, p95 = 2.16 ms** — far under the 300 ms budget (DEVICE_UNVERIFIED; synthetic signatures).
- False-match rate on the 20-item negative corpus: **0** (precision-first; a probe vs 20 different videos produced ZERO high-confidence matches).
- Common-intro / black-frame / same-person-different-video / temporally-reordered-recut: NONE reached `highConfidenceMultiframeMatch` (pinned).
- Version-mismatch / expired / revoked / corrupt records: never reused (pinned).
- Policy/family revision change: recall DROPS (re-adjudication path), NEVER a replay (pinned).

## FILES
New (GuardianMedia, pure/stores): RecognitionSignatureV1.swift, ContentEvidenceMemoryV1.swift, RecognitionRecallFlowV1.swift, YouTubeMetadataConnectorV1.swift, DigitalObservationLedgerV1.swift, ContributionEvidenceContractV1.swift.
New (app shell, auto-synced): Gen8/RecognitionMemoryModel.swift, Gen8/RecognitionMemoryView.swift.
Edited: Tier1IdentityResolutionV1.swift (3 new GuardianReasonCodeV1 cases + Turkish strings), Gen8/GuardianLabModel.swift (exhaustive confidence switch updated), Gen8.xcodeproj/project.pbxproj (6 GuardianMedia files added; recognition trio in BOTH app + broadcast-extension Sources phases; YouTube/ledger/contribution app-only), Tests/GuardianMediaTests/RecognizeRecallR11Tests.swift (36 tests).

## BUILD STATUS
- `swift build` (full GuardianKit package): COMPLETE, 0 errors.
- `swift test --filter GuardianMediaTests`: 626 / 0 failures.
- Full Xcode scheme build: `BUILD_UNVERIFIED_BY_AGENT` — `xcodebuild` and `plutil` are blocked by this agent's sandbox permission policy (denied). The pbxproj edits were structurally self-verified: each new file reference has the correct count (recognition trio = fileRef + group child + 2 buildFiles + 2 Sources-phase entries across app+broadcast-extension; app-only files = fileRef + group child + 1 buildFile + 1 Sources entry). Transitive deps for the extension-referenced recognition trio (WorldModelEvidenceBridgeV1, GuardianCanonicalSamplerV1, Tier1IdentityResolutionV1, Tier1ItemIdentityV1) are all already present in the broadcast-extension Sources phase. A human must run the Xcode scheme build + `plutil -lint` to confirm.

## NOT DONE / NEXT (R12 entry conditions)
- SampleHandler end-to-end wiring of the recognition flow (probe build at item end → memory lookup → recall gate → bridge re-adjudication → memory upsert) is DESIGNED + unit-proven but NOT yet called from the live broadcast SampleHandler. The pure engines + stores are complete and compiled into the extension target; the final call-site integration is the first R12 item.
- Real device experiment (same Reels twice; measured recognition accuracy/coverage/latency on-device) is BLOCKED (no device) — physical proof gate.
- Live YouTube API call is OUT OF SCOPE (no key infrastructure) — connector is offline-testable only; UNAVAILABLE by default.
- Weekly/monthly report UI is R12 (contract only this round).

## HONEST TIERS
All R11 work is `compiles` + `synthetic-tested` only. NO claim is `DEVICE_VERIFIED`. UNKNOWN never → CLEAR. Child fail-closed preserved. 3rd-party WARN-only preserved. Mic never opened. No raw media persisted. P009E numeric lock untouched; Contribution Score locked.
