# P006 — FMEA & Chaos Plan

**Doc status:** `CANONICAL` · **Phase:** 6 · **Date:** 2026-10-18 · PROMPT 006 §31. Prioritized by severity × likelihood × detectability × blast radius (RPN-style).

## Top failure modes (RPN-ranked)
| Mode | Severity | Likelihood | Detectability | Blast radius | Mitigation (implemented/planned) |
|---|---|---|---|---|---|
| False "Protected" when runtime can't operate | **Critical** | low | high | user trust | `canClaimProtection=false` unless enabled; never stale-safe (impl) |
| Wrong auto-skip on alternate cut | Critical | med | high | playback | identity/version gate refuses (impl, tested) |
| Corrupt/poisoned model activated | High | low | high | decisions | checksum + rollback gate (impl, tested) |
| Stale ContentDNA reused unsafely | High | med | med | decisions | version/TTL invalidation (impl, tested) |
| Memory growth on long media | High | med | med | device | ephemeral frames + bounded caches (impl) |
| Cancellation storm leaves stale work | Med | med | med | device | Task.isCancelled between units; discard stale (impl) |
| Unsupported language inherits EN threshold | Med | med | high | correctness | registry UNASSESSED; no inheritance (impl, tested) |
| Thermal/low-power ignored | High | low | high | device | budget → ECO degrade (impl, tested) |

## Automated fault injection (chaos) — implemented as tests / planned
- **Implemented (tests):** model checksum mismatch → reject; stale/version-mismatch cache → miss; thermal/low-power → ECO; extension/process relaunch → activation persists; cancellation → no stale/crash; corrupt/missing media → safe failure; disagreement → lower confidence.
- **Planned (device/real-media):** provider timeout injection, language-asset-missing injection, memory-pressure simulation, speech-asset-missing, live-stream coverage-lag.

## Shield durability failure modes (006B)
- **Store file corrupt / torn write:** SHA-256 payload checksum mismatch → `ShieldStoreError.corrupted` (load throws,
  does not silently return empty/"safe"); atomic writes prevent torn files. Tested.
- **Incompatible derived-feature engine revision:** rule marked `referenceReauthoringRequired` → inactive until
  re-authored — never a silent stale match. Tested.
- **Deleted rule in stale index cache:** reverse-map removal purges all token/source entries → cannot match. Tested.
- **Paused / expired rule:** excluded from shortlist (`isActive`). Tested.
- **Shield matcher unavailable (e.g. music/speech):** Shield ABSTAINS (`NO_SHIELD_DECISION`); strict HOLD only via
  `GlobalAdmissionController` under opt-in `STRICT_NO_EXPOSURE_IF_UNVERIFIED` — never a blanket warn/hold. Tested.
- **Large rule set at launch:** O(N) cold load, O(tokens) incremental ops (reverse-map index); a prior O(N²) rebuild
  regression (13.9 s @10k) was fixed to ~67 ms. Load runs off the main actor. See P006B_SHIELD_DURABILITY_BENCHMARK.

## Visual reference durability failure modes (006C)
- **Process death / relaunch:** the visual matcher reconstructs its reference from a persisted serializable signature
  (Strategy A) — no in-memory Vision object required. Proven by a true teardown-boundary test.
- **Incompatible engine revision / format / checksum fail:** rule → REFERENCE_REAUTHORING_REQUIRED (or CORRUPT); it
  stays in the store, does NOT silently match, and the UI shows "Update reference". Never a stale safe/blocked decision.
- **Startup work on MainActor:** `loadAndRebuild` is non-`@MainActor` and proven to complete off-main; index rebuild is
  O(N), bounded, once per launch (not persisted/trusted from disk → no torn-index repair needed).
- **Adversarial fixture (sparse/near-blank image):** perceptual hashing cannot reliably discriminate near-blank images;
  documented limitation (not hidden) — real logo/photo structure is the supported case.

## Native-surface & device failure modes (007)
- **Live Activity stale / out-of-order / content mismatch:** `LiveActivityUpdatePolicy` + `GlyphSurfaceController`
  reject or suppress → never a stale positive/safe glyph (tested).
- **Guardian OFF mid-analysis:** future work cancelled; results that can't be cancelled immediately are discarded.
- **Speech asset/auth missing:** `SpeechTranscriberV3` returns explicit `BLOCKED_*` + `.unavailable` (no fake transcript).
- **Model checksum failure / pressure:** `ModelLifecycleV2` → failedChecksum / unload+lazy-reload / rollback (tested).
- **H1 unavailable:** sensitive-visual stays UNAVAILABLE (non-determinable), never stale-safe; shield≠safety.
- **Device run blocked:** signing team unset → device metrics NOT_MEASURED; never fabricated.
- **Sustained churn:** task/media ledger returns to baseline; no index/cache growth (soak test).

## Principle
On any failure: UNKNOWN / CAUTION / HOLD(strict) / capability-limited — **never silent safe**, never crash (observed in tests: safe failures, no crashes after the continuation fix). 006B adds: **the Shield may ABSTAIN, and abstention is never auto-hold — strict HOLD is a global-admission policy decision, not a matcher side effect.** 007 adds: **native surfaces are never stale-safe; device-only claims are NOT_MEASURED, never fabricated.**

## P008A-R2 — content-boundary failure modes (boundary-policy-v3)

| failure mode | cause | effect | mitigation (V3) | evidence |
|--------------|-------|--------|-----------------|----------|
| Over-detection / false-new spam | motion/overlay crosses a fixed threshold | duplicate commits, wasted analysis, battery | center-centric gates: chromeOnly→OVERLAY, centerContentFloor, soft refractory, region agreement | held-out FP=0, dup=0 across all 18 slices |
| Under-detection (the R1 regression) | thresholds too conservative | real item changes missed (recall ≈0.25) | multi-region + adaptive dynThr + strong-jump refractory bypass | held-out R=0.917 (vs R1 0.25) |
| Subtle adjacent-item miss | next item visually near previous (bright-to-bright, same-theme, cut inside high motion) | missed boundary (fails SAFE, no spam) | documented limitation; no tune-to-fit; FN not FP | held-out 3 FN, 0 FP |
| Burst after strong cut | strong jump bypasses refractory repeatedly | commit burst | confirm + refractory still apply to non-strong; strong requires D>=0.30 AND >=3 regions | testRapidSwipeDistinctCommits, testHighMotionSameItemNoFalseBoundary |
| Unbounded memory on long session | retaining history | extension killed (~50MB) | bounded: prev sig + <=12 window + counters only | 253-test suite, in-place sampling |

## P008A-R3 — content-segmentation failure modes (boundary-policy-v4, ContentSegmenterV4)

| failure mode | cause | effect | mitigation (V4) | evidence |
|--------------|-------|--------|-----------------|----------|
| Over-detection on real motion (the V3 disaster) | absolute change floor + baseline excluded motion frames | 477 commits / ~20 items | robust baseline LEARNS motion; discontinuity measured RELATIVE to motion; PRE/POST persistence | held-out 0 false segments; stress extreme/long high-motion = 0 false commits |
| Overlay / chrome change read as boundary | localized chrome change | false segment | isOverlay (center stable + localized) + centerTransitionFloor + temporal region reliability | all overlay slices FP=0 (held-out + stress) |
| Motion excursion / pan burst read as cut | short directional burst | false segment | PRE-window vs POST-window: discontinuity must exceed BOTH within-window motions; continuity filter | panning handled; no FP |
| Double-commit after a real cut | stale pre-cut anchor | duplicate segment | ring reset to post-rep on commit + refractory minSegmentFrames | held-out dup=0; maxRun 0 |
| High-motion→high-motion cut missed | frame clouds overlap (gap < 2·amp) | missed boundary (fails SAFE) | documented error budget (§28); precision stays 1.000; telemetry | held-out high-motion-sport/panning FN (2), 0 FP |
| Rapid 2-frame-dwell swipes missed | POST can't persist before next swipe | missed boundaries under extreme cadence | known stress limit; degrades SAFE (no spam) | stress-rapid-5-swipe 0/4, maxRun 0 |
| Unbounded memory on long session | retaining history | extension killed | bounded ring (≤40) + baseline (≤40) + POST (≤8); no raw retention | testResourceBoundedness (5000 frames) |

## P008A-R4 — content-segmentation failure modes (boundary-policy-v5, ContentSegmenterV5)

| failure mode | cause | effect | mitigation (V5) | evidence |
|--------------|-------|--------|-----------------|----------|
| Swipe cue over-fires (the V4 disaster) | coherent-translation + swipeConfirmRelief lowered the bar | 73/~20 device over-detect | REMOVED relief → TemporalSwipeGateV1 supporting only; swipe needs replacement+persistence | held-out panning 0 false; swipe-cue-without-replacement test 0 commits |
| Pan read as new segment | long pan replaces content gradually | false segments | spike-based OPEN (pan smooth → no spike) + replacement/settle confirm → PAN_SAME_SEGMENT | panning-continuous 0, pan-then-cut exactly 1; stress-long-pan 0 |
| Cadence-dependent behavior | frame-count dwell fragile under variable FPS | commit count varies with capture rate | TIME-based dwell/persistence/transition-timeout (ms) from PTS | cadence 60/30/20/jitter/drop = 14/15/15/15/15 (≤7%) |
| Single-cut double-commit | cut aftermath (chrome settle) re-triggers | duplicate segment | 220ms time dwell + ring reset to post-rep on commit | held-out dup=0, maxRun 0 |
| On-device scale lower than profile | bootstrap from biased commit telemetry | inflated normalized jump → over-commit | DeviceMotionProfileV2 uses real on-device scale (0.067); evidence build enables unbiased per-frame calibration | held-out P=1.000 (no over-commit) |
| High-motion→high-motion cut missed | frame clouds overlap | missed boundary (fails SAFE) | documented error budget (§23); precision 1.000 | held-out high-motion-sport FN, 0 FP |
| Unbounded memory | retaining history | extension killed | bounded ring/baseline/POST; no raw retention | testResourceBoundedness (5000 frames) |

## P009A — identity-brain failure modes (item-grouping-policy-v1)

| failure mode | cause | effect | mitigation | evidence |
|--------------|-------|--------|------------|----------|
| FALSE CROSS-ITEM MERGE (safety-critical) | similar adjacent items read as one | safe admission leaks across identity boundary | precision-first merge (confirmSame 0.50) + strongNew veto + §7 no-inheritance on uncertainty | held-out mergeP 1.000, xMerge 0.0000; protection test |
| Item-count explosion on edited video | internal cuts read as items | compute waste, wrong item economy | caption/audio/theme/burst merge evidence; maxShotsPerItem guard | 24-cut montage → 1 item, 0 FP |
| Rapid items collapse | short dwell misread as burst | missed items | swipe/interaction evidence outweighs cadence | 8 rapid items: 7/7 boundaries, 0 merges |
| Ambiguity guessed | no cross-modal evidence (Tier 0) | wrong identity either way | AMBIGUOUS provisional split; late-evidence versioned merge; DNA uncertainty 0.8 | ambiguous slice → AMBIGUOUS (labeled-acceptable) |
| Cache collision reuse | coarse identity key | wrong DNA reused | full-signature verification; degrade to re-analysis | testCacheCollisionReanalysis |
| Graph growth on long session | per-shot nodes/edges | extension memory kill | bounded graph + compaction summaries; bounded evidence/cache | testBoundedGraphMemory (200→≤16, 0 lost) |
| Duplicate deep inference | re-escalation per shot | battery/thermal waste | ResourceGovernor dedupe per (item, domain) | testResourceGovernorDedupesDeepInference |
| Pack tamper / downgrade | bad checksum/signature/engine | corrupted intelligence | VERIFY → QUARANTINED; single-step declared rollback | pack contract tests |

## P009A-R1 — profile-transfer failure modes (item-grouping-policy-v2)

| failure mode | cause | effect | mitigation | evidence |
|--------------|-------|--------|------------|----------|
| Tier-0 merge unreachable (the P009A bug) | global threshold > profile evidence ceiling | 73/73 zero merges on device | profile-normalized scores (S=raw/ceiling); per-profile frozen policies; reachability test | testTier0SameDecisionReachable; T0 heldout mergeR 0.873 |
| Lab→device profile gap | gate run only in Tier-1 | failure invisible pre-freeze | §3 acceptance matrix: every runnable profile needs its own TUNE/HELDOUT/STRESS/DEVICE-LIKE before freeze | all four T0 gates run + passed |
| Style-similar different item merges | style channels or burst anchoring a merge | cross-item admission leak | anchor rule: content/cross-modal anchors only; strong/weak theme two-level (weak blocked after long dwell); strong-new veto absolute | T0+devicelike xM=0.0000 |
| Missing modality punished | absent caption/audio read as negative | Tier-0 under-merges | missing evidence contributes 0, never negative; ceiling normalization | testAbsentEvidenceNotNegative |
| Forced coalescing to hit counts | economy pressure | unsafe merges | coalescer content-anchored only, provisional-only, never strong-new, versioned + DNA invalidation | coalescer tests; §10 honored |
| Thermal creep (FAIR 45/73 on P009A run) | per-shot brain work | sustained FAIR | ThermalAwareDegradationV1 (FAIR defers optional deep work); grouping only on shot commits | contract test; device capture pending |

## P009A Phase C — identity-safety failure modes (post-C6)

| failure mode | cause | effect | mitigation | evidence |
|--------------|-------|--------|------------|----------|
| Near-identical different items merge (C6 family) | correlated luma channels counted as many proofs; strong-theme dwell immunity | safe-state leak across items | EvidenceIndependenceGuardV1: luma=ONE family; SAME needs cross-modal OR ≥2 families incl. burst | C6 probe passes untouched; 10 adversarial variants 0 unsafe SAME |
| Dead dwell features | end-time never propagated to stored descriptors | long-dwell evidence + weak-theme gate dead on device | monotonic start-difference dwell | PHASEC dwell tests; long-dwell fires |
| Tier-0 inheritance leak | provisional identity treated as resolved | positive state crosses unresolved identity | inheritance requires APP_FULL_TIER1 + non-provisional (structural) | testTier0NeverInheritsSafeAdmission |
| Durable DNA on unresolved identity | provisional item minted DNA | stale identity contaminates cache | mintDNA nil for provisional; SHOT_ONLY record w/ immediate risk escalation | testNoDurableDNAWhileProvisional |
| Release thermal from telemetry | per-frame evidence writes in release | THERMAL_SERIOUS in production | EvidenceBuildPolicyV1 structurally OFF in release (env ignored) | testReleaseDisablesEvidenceLogging |

## P009B — expert-mesh failure modes

| failure mode | cause | effect | mitigation | evidence |
|--------------|-------|--------|------------|----------|
| Stale evidence attaches to new identity | identity change mid-inference | wrong semantic state on wrong item | generation stamp on every evidence record; Meta-Brain discards mismatches; EvidenceBusV2.markStale | testStaleResultCannotCrossIdentity |
| Malformed handoff poisons state | NaN/∞/negative-ts/malformed-id/stale-session from extension | crash or false positive identity | InputSanitizerV1 → QUARANTINED, counted, never processed | testHandoffSanitization (7 variants) |
| Benefit evidence averages away safety signal | majority-vote fusion | risky content looks neutral | CrossModalExpertGraphV1: risk-vs-positive => CONTRADICTS, safety dominates, no vote | testSafetyVsBenefitConflictRepresented + corpus |
| Later benign content suppresses earlier risk | naive latest-wins temporal state | escalation hidden | TemporalExpertV1 monotone-max risk | testTemporalEscalationLaw |
| Absence of weak evidence read as "safe" | no-signal mapped to safe verdict | false allow | safety:no-lexical-signal (NOT a safe verdict), conf 0; H1-UNAVAILABLE label on every record | testSafetyDimensionTagsAndH1Open |
| Unsupported input interpreted anyway | ja text / unknown audio class / noisy OCR | fabricated topics | UNSUPPORTED_LANGUAGE / unsupported-classes counted / OOD low-conf abstention | OOD corpus seed 3 failures=0 |
| Heavy expert storms under load | repeat requests per item | thermal/battery burn | confirmed-item cache + deep dedupe + thermal gates (FAIR/SERIOUS laws) | thermal + dedupe + cache tests |
| Provisional identity finalizes durable state | Tier-0 CANDIDATE treated as resolved | cross-item contamination | no cache, no DNA mint, temporal:identity-provisional marker | testUnderstandingStateAndDNAMintRules |
| Unbounded evidence growth | long sessions | memory creep | bounded bus/ledger/rings | testBoundedRuntimeContainers (3000 inserts) |
| Unclear-license model ships | integration pressure | legal/provenance violation | ExternalIntelligenceAssetAuditV1 law + pack VERIFY quarantine | testAssetAuditLedgerLawful + testExternalAssetAuditRejection |
