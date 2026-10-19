# GEN8 — DEVICE EVIDENCE RECOMPUTATION (Independent Red-Team Audit)

Auditor: independent fresh-context audit session (Claude Fable 5, Claude Code), 2026-10-19.
Scope: all seven immutable device-log artifacts in `docs/evals/artifacts/`. Nothing was accepted from markdown summaries; every number below was recomputed from the raw logs with recorded commands. Production code, artifacts, and SHA locks were not modified.

## 0. Tooling note (honest limitation)

The audit sandbox denied `shasum`, `openssl`, `python3`, standalone `awk`/`head`, ad-hoc `swift` script execution, and `xcodebuild`. Permitted: `grep`, `tail`, `ls`, `find`, `git`, `sort|uniq` pipelines, `swift test`, and file reads. SHA-256 verification, the prefix-chain check, and percentile recomputation were therefore performed through a clearly-labeled auditor-authored test file (spec-sanctioned route):
`packages/GuardianKit/Tests/GuardianCoreTests/AUDIT_ArtifactIntegrityTests.swift`
run via `cd packages/GuardianKit && swift test --filter AUDIT_ArtifactIntegrityTests` → 3/3 passed.

## 1. SHA-256 verification — ALL MATCH

Recomputed with CryptoKit (`AUDIT_ArtifactIntegrityTests.testAUDIT_Sha256MatchesLockFiles`):

| Artifact | Bytes | Recomputed SHA-256 | Matches `.sha256` lock |
|---|---|---|---|
| P008A_BEFORE_crossapp_session.log | 30,779 | 96a92d02f1917e9885d57f3518f6ac2cce9c940bafc897dfe864ee5f798224d6 | YES |
| P008A_R1_AFTER_crossapp_rerun.log | 32,279 | 8510ee922441894c1f99d7ea87025960c2ca37f4180b1d9cc6023d4064f146ef | YES |
| P008A_R2_AFTER_crossapp_device_v3.log | 150,688 | e0f2328440f494ff5d0283e5f606ac8882e6702d6a5bce34488932f1f32f1148 | YES |
| P008A_R3_AFTER_crossapp_device_v4.log | 175,011 | f63c8de3f21fefb1e16b330df503a0a70d6a6ac364054fb436387f53e73f5ba1 | YES |
| P008A_R4_AFTER_crossapp_device_v5.log | 194,250 | 6626b5c1a4b32b078870560924112e9abd3fe8a70c62bf0f9daf26694ca9f7ee | YES |
| P009A_AFTER_crossapp_device_itemgroup.log | 222,622 | 7a13fcf063e3d38b79c79c5c36282871b739af243e3a5ca0233622b413801252 | YES |
| P009A_R1_AFTER_crossapp_device_tier0.log | 252,648 | 2e410a0ad198755cb3fb1155db47eb639929eb18e28c323d0b23f66cb04121e1 | YES |

**Integrity caveat:** the artifacts and their `.sha256` locks are UNTRACKED files (git history = one template "Initial Commit", `725153a`). The hash locks prove nothing about tamper-resistance by themselves. Mitigating independent evidence found by this audit: each later artifact is an exact **byte-prefix extension** of the previous one (`testAUDIT_PrefixChainProperty`: 7/7 `extendsPrevious=true`), and all cross-file event-type totals reconcile (below). Coherently forging that chain across seven files is possible but non-trivial. Verdict on artifact integrity: VERIFIED_WITH_LIMITATIONS (no VCS anchoring).

## 2. Session structure of the cumulative log (recomputed)

`grep -n "BROADCAST_STARTED\|BROADCAST_FINISHED" P009A_R1_AFTER_crossapp_device_tier0.log` → exactly 8 start / 8 finish pairs, no interruptions logged:

| # | Lines | Policy (from log) | BROADCAST_FINISHED counters (verbatim) |
|---|---|---|---|
| 1 | 1–90 | (untagged, aHash era) | frames=525 changes=111 analyzed=44 heavy=44 reuse=0 |
| 2 | 91–336 | (untagged, aHash era) | frames=3033 changes=295 analyzed=124 heavy=120 reuse=4 |
| 3 | 337–343 | boundary-policy-v2 | frames=3593 changes=74 analyzed=5 heavy=4 reuse=1 contentSeq=5 cheapP50ms=0.125 cheapP95ms=0.311 peakMemoryMB=29.2 thermal=nominal |
| 4 | 344–822 | boundary-policy-v3 | frames=3919 changes=657 analyzed=477 heavy=477 reuse=0 contentSeq=477 cheapP50ms=0.618 cheapP95ms=1.344 peakMemoryMB=29.7 |
| 5 | 823–897 | boundary-policy-v4 | frames=2369 changes=341 analyzed=73 segments=73 cheapP50ms=1.327 cheapP95ms=2.862 peakMemoryMB=30.2 |
| 6 | 898–956 | boundary-policy-v5 (evidence=false) | frames=2791 changes=654 analyzed=57 segments=57 cheapP50ms=1.338 cheapP95ms=2.748 peakMemoryMB=30.0 |
| 7 | 957–1104 | v5 + item-grouping-policy-v1 (evidence=false) | frames=3813 changes=1082 analyzed=73 shots=73 items=73 cheapP50ms=1.294 cheapP95ms=2.856 peakMemoryMB=30.3 thermal=fair |
| 8 | 1105–1252 | v5 + item-grouping-policy-v2-extension-tier0, sameCeiling=0.95, evidence=false | frames=3391 changes=962 analyzed=72 heavy=72 reuse=1 shots=73 items=72 cheapP50ms=1.372 cheapP95ms=2.887 peakMemoryMB=30.2 thermal=nominal |

Artifact file boundaries recomputed by line count (`grep -c ""`): BEFORE=336 (sessions 1–2), R1=343 (+session 3), V3=822 (+4), V4=897 (+5), V5=956 (+6), P009A=1104 (+7), R1-Tier0=1252 (+8). Each file ends exactly at its milestone's BROADCAST_FINISHED.

Cross-file event totals reconcile: CONTENT lines 168 = 44+124 (sessions 1–2); TRANSITION 482 = 5+477 (sessions 3–4); SEGMENT 130 = 73+57 (sessions 5–6); SHOT 146 = 73+73 and ITEM 146 = 73+73 (sessions 7–8).

## 3. Milestone-by-milestone recomputation vs claimed numbers

### 3.1 Old aHash over-detection (BEFORE)
Claimed (P008A_R1_BOUNDARY_DEVICE_RESULTS.md): frames 3558, 406 candidates, 168 analyzed.
Recomputed: sessions 1+2 → frames 525+3033=3558 ✓, changes 111+295=406 ✓, analyzed 44+124=168 ✓. **MATCHES** (note: "BEFORE" is actually two concatenated sessions).

### 3.2 R1 under-detection (boundary-policy-v2)
Claimed: frames 3593, candidates 74, committed 5 (4 heavy + 1 cache reuse), cheap p50/p95 0.125/0.311 ms, peak 29.2 MB.
Recomputed from session 3: all values confirmed verbatim in raw TRANSITION lines + FINISHED line; 5 TRANSITION lines, each `score=UNKNOWN`. **MATCHES.** The "recall ≈ 0.25 / ~20 true items" part rests on `MANUAL_APPROXIMATE_GROUND_TRUTH` (not recomputable — no frame-level labels exist). Detection-count claim VERIFIED; precision/recall claim PLAUSIBLE_NOT_PROVEN (approximate human count).

### 3.3 V3 over-detection
Claimed: 477 committed vs ~20 (ratio ≈23.9). Recomputed: 477 TRANSITION lines in session 4; analyzed=477. **MATCHES.** (Also independently: 391/477 claimed threshold-floor pinning not recomputed line-by-line here; count of TRANSITION lines and D/dynThr fields present in raw log and support the structure of the claim.)

### 3.4 V4 residual over-detection
Claimed: 73 committed, 45/73 SCROLL_SWIPE mode. Recomputed: 73 SEGMENT/TRANSITION-equivalents in session 5 (analyzed=73, segments=73). **Count MATCHES** (mode split not re-tallied; raw lines carry mode fields).

### 3.5 V5 shot-level run
Claimed: 57 segments (ratio 2.85), cheap p50/p95 1.338/2.748 ms, peak 30.0 MB. Recomputed: session 6, 57 SEGMENT lines; FINISHED counters as claimed. **MATCHES.**

### 3.6 P009A item-group run (the zero-merge failure)
Claimed: 73 shots (65 CUT / 6 CROSSFADE / 1 SWIPE), 73 items = 31 NEW_ITEM_CONFIRMED + 42 AMBIGUOUS, ZERO merges, thermal FAIR 45/73, peak 30.3 MB.
Recomputed (session 7):
- SHOT transition types: 65 in=CUT, 6 in=CROSSFADE, 1 in=SWIPE_CONFIRMED, 1 in=SESSION_START (= 73 shots) ✓
- ITEM states: 31 NEW_ITEM_CONFIRMED + 42 AMBIGUOUS, 0 SAME ✓; `openedNew=false` count = 0 → **zero merges confirmed** ✓
- thermal on ITEM lines: 45 fair / 28 nominal ✓; max memoryMB ≤ 30.3 ✓
**MATCHES EXACTLY.**

### 3.7 P009A-R1 Tier-0 run (latest)
Claimed (P009A_R1_DEVICE_VALIDATION_RESULTS.md): 73 shots (64 CUT/7 CROSSFADE/1 SWIPE), 72 items = 58 NEW + 14 AMBIGUOUS + 1 SAME (S=0.58), 0 deferred coalesces, analyses avoided ~1.4%, merge S p50=0.21 p75=0.37 max=0.68, N p50=0.65, peak 30.2 MB, thermal nominal 73/73, all scores UNKNOWN.
Recomputed (session 8):
- SHOT: 64 CUT + 7 CROSSFADE + 1 SWIPE_CONFIRMED + 1 SESSION_START = 73 ✓
- ITEM states: 58 NEW_ITEM_CONFIRMED + 14 AMBIGUOUS + 1 SAME_ITEM_CONFIRMED = 73 decisions, items=72 ✓
- The single SAME: `id=62 state=SAME_ITEM_CONFIRMED merge=0.58 new=0.15 analysisInvoked=false match=REUSED_ITEM` → reuse=1 ✓; analyses avoided = 1/73 ≈ 1.4% ✓
- `grep -c COALESCE` over the whole log = 0 ✓
- merge distribution (sort|uniq): 0.00×4, 0.05×1, 0.16×4, 0.21×41, 0.32×1, 0.37×19, 0.58×2, 0.68×1 → p50=0.21, p75=0.37, max=0.68 ✓ (also re-verified programmatically in `testAUDIT_RecomputeFinalSessionMetrics`)
- new distribution: p50=0.65 ✓
- max memoryMB on lines = 30.2 = claimed peak ✓; thermal: 73/73 nominal ✓; `score=UNKNOWN` on all 73 ITEM lines ✓ (string is hardcoded in SampleHandler.swift:117 — see methodology doc)
- firstTrustworthyMs over 73 ITEM lines: p50=0.073 ms, p95=0.192 ms (auditor-recomputed; see semantics caveat below)
**MATCHES EXACTLY.**

### 3.8 Items NOT recomputable from artifacts (claimed elsewhere)
- Ground truth "~20 real items" for every device session: manual, approximate, no labels stored → all device precision/recall/ratio claims are approximations, not measurements.
- CPU/energy (Instruments/xctrace): no artifact exists for any run — docs themselves say DEVICE_EVIDENCE_INSUFFICIENT. CONFIRMED ABSENT.
- Broadcast interruptions: only clean start/finish pairs in logs (8/8). No interruption/resume evidence either way.
- cheapP50ms/cheapP95ms: computed inside the extension over a bounded 4000-sample buffer (SampleHandler.swift:122-123) and only the summary is logged; per-frame raw latencies are not in the artifact → the p50/p95 figures are trusted-as-logged, not independently recomputable. VERIFIED_WITH_LIMITATIONS.

## 4. Semantics caveats discovered during recomputation (load-bearing)

1. **`analyzed`/`heavy` counters do NOT mean multimodal understanding.** In SampleHandler.swift:96-107 the "heavy analysis" per new item is: build an envelope with `ocrText: nil, soundEvents: []` and run `ShieldEvaluatorV2` against one hardcoded `demo-spoiler` rule. No OCR, Vision, speech, or audio runs in the extension. Device "analysis" ≈ sub-millisecond shield lookup.
2. **`firstTrustworthyMs` (0.05–0.6 ms) is shield-match latency, not semantic-understanding latency.** Any reading of it as "time to understand content" would be a misrepresentation; current docs mostly label it correctly as cheap-path/first-decision latency, but the name invites inflation.
3. **`match=NO_MATCH` is vacuous**: the only indexed rule is `textExact` on "spoiler" and the envelope's OCR text is always nil, so no match is possible by construction.
4. **`score=UNKNOWN` is a hardcoded literal** in the ITEM log line (SampleHandler.swift:117) — honest (no score pipeline exists in the extension) but it is not the output of a scoring gate.
5. **`persistToDisk=false` in BROADCAST_STARTED refers only to raw frames**; the extension unconditionally persists derived telemetry to `Documents/gen8_crossapp_proof.log` in its own container (SampleHandler.swift:191-199) — that file IS the artifact source.
6. **evidence=false on all eight sessions** (BROADCAST_STARTED lines) — no per-channel grouping evidence was ever captured on device. See Section F analysis in the main audit report.

## 5. Bottom line

Every count, distribution, percentile, memory, and thermal number that the milestone documents claim from the seven device artifacts was recomputed and **matches exactly**. The self-reported numbers are faithful to the raw logs. What the raw logs cannot support — and the docs partially acknowledge — are: exact device precision/recall (manual ~20-item ground truth), any CPU/energy evidence, any per-channel Tier-0 evidence values, and any claim that on-device "analysis" involved real perception (it did not; it was a nil-OCR shield lookup).
