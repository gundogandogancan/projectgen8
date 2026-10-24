# GEN8 — PRODUCT EVIDENCE SCORECARD (separate lane from audit throughput)

Date: 2026-10-24. Purpose (mandate §15): let the user distinguish **audit throughput** (the RWC
preregistration security rounds AUDIT14→AUDIT20→R7) from **actual product progress**. States are only:
`MEASURED` / `ENGINEERING-TESTED` / `SIMULATED` / `BLOCKED` / `UNKNOWN`. No simulated result is promoted
to real-device. Evidence paths are REAL repo files (verified by search, not asserted from memory).

> **R7's contribution to THIS lane:** essentially none on product capability. R7 is an audit-security
> round (corpus-entry authorization boundary). It does NOT add perception, calibration, device or
> presentation capability. The rows below are PRIOR historical accomplishments; the "R7 delta" column
> states honestly what this effort changed (almost always "none — audit lane").

## Subsystem scorecard

| # | Subsystem | State | Evidence (device/build) | Limitation | Next admissible test | R7 delta |
|---|---|---|---|---|---|---|
| 1 | iOS capture / perception surfaces | **ENGINEERING-TESTED** (partial) | `docs/platform/ios/P002_APPLE_NATIVE_INTELLIGENCE_CAPABILITY_REPORT.md` — Vision OCR / NaturalLanguage LID / SoundAnalysis integrated + headless-verified | On-device ASR (SFSpeech) + real cross-app OCR not exercised via app UI; cross-app universal capture is NOT an available iOS capability | consented on-device ReplayKit session running the Vision+NL pipeline with Instruments trace | none |
| 2 | Tier-0 shot segmentation | **MEASURED** (real device) | `docs/evals/P008A_DEVICE_SESSION_PROOF_RESULTS.md` — iPhone 14 Pro Max, 73 shots, p50 0.079 ms / p95 0.185 ms; ContentBoundaryPolicyV5 frozen | old aHash detector over-triggered (406 vs ~20 real); ContentBoundaryV2 fix not re-run on device | re-run cross-app device session on ContentBoundaryV2; capture false-positive rate | none |
| 3 | Tier-1 content-item grouping | **MEASURED (negative result)** | `docs/evals/P009A_R2_MEASURED_TIER0_RESULTS.md` — "SAME vs NEW item boundaries materially overlap on every channel; item-grouping economy is NOT achievable from these features" (device: 73 shots→72 items, ratio 3.6, 1 safe merge, 0 false merges) | Tier-0 cheap visual features CANNOT safely group items — BINDING. Safe grouping needs Tier-1 in-process multimodal evidence or a shared-container capability that does not exist | Tier-1 in-process grouping prototype on consented device media | none (binding SAME/NEW finding preserved) |
| 4 | Multimodal classification | **ENGINEERING-TESTED** (synthetic) | `docs/intelligence/P009B_VISION_BRAIN.md`; `docs/implementation/P002_IMPLEMENTATION_EVIDENCE.md` — Apple-native heads only; 59 synthetic pairs | no real-world multi-item accuracy; no proprietary model; derived labels only | labelled real-world eval set (blocked by zero-data / corpus gate — RWC pre-14) | none |
| 5 | Guardian decision / policy engine | **ENGINEERING-TESTED** (deterministic, locked) | `docs/adr/ADR-0007-decision-precedence-chain.md`; `docs/canonical/DECISION_LEDGER.md` — precedence chain LEGAL/SECURITY > CHILD_SAFETY_FLOOR > … locked (D-0015) | arbitration tested on synthetic expert inputs only; no calibrated production thresholds | end-to-end decision over a calibrated score (blocked by ECE gate) | none |
| 6 | Protection output / Presentation / Glyph / Motion | **BLOCKED** | `docs/canonical/RWC_ENTRY_GATE_R1_ENGINEERING_LOCK.md` — Presentation/Glyph/Motion BLOCKED; `ProductionScoreReleaseGateV1 CLOSED`; `productionDisplayAllowed()==false` | no runtime presentation; Dynamic Island BLOCKED_PENDING_PAID_APP_GROUP | unblock only after release gate opens (post-PASS, post-calibration) | none (still BLOCKED) |
| 7 | Real-device latency | **MEASURED** (signal path only) | `docs/evals/P008A_DEVICE_SESSION_PROOF_RESULTS.md` — in-extension first-trustworthy p95 0.185 ms | end-to-end real-media OCR latency = PROTOCOL_ONLY (not on device); no full-pipeline device number | Instruments-traced full-pipeline device run | none |
| 8 | Battery & thermal | **MEASURED (risk) / DEVICE-UNVERIFIED (budgets)** | `docs/evals/P009B_RESOURCE_RESULTS.md`; `docs/resilience/P006_FMEA_AND_CHAOS_PLAN.md` — evidence build THERMAL_SERIOUS driven by 7.8k per-frame MOTION log writes; **`EvidenceBuildPolicyV1` structurally OFF in release** (production thermally nominal); `DEVICE_RESOURCE_BUDGETS.yaml` all fields UNSET | no measured production CPU/GPU/NPU/energy budgets; thermal risk is of the EVIDENCE build only | capture Instruments energy/thermal on a RELEASE build device session | none (risk preserved; see §"Carried risks") |
| 9 | Privacy / data retention | **VERIFIED** | `docs/privacy/P009A_PRIVACY_THREAT_MODEL.md` — raw screen recording retention OFF by default; per-session consent; derived scalars only; device containers verified clean ×5 | consent model tested in lab/device sessions; not an external audit | independent privacy audit of the consent + retention path | reaffirmed (zero-data invariants hold in R7) |
| 10 | Release eligibility | **BLOCKED** | `docs/canonical/RWC_ENTRY_GATE_R1_ENGINEERING_LOCK.md`; `docs/calibration/REAL_WORLD_CALIBRATION_ENTRY_GATE_IMPLEMENTATION_REPORT.md` — release gate CLOSED (6/10 unmet); **ECE 0.250 ≫ 0.05 target UNMET-UNRELAXED**; `supportsRealWorldClaims == false` | no fitting, no real corpus, no held-out selection; engineering-only | the RWC pre-14 PASS path (requires AUDIT21 PASS + lawful closeout + onboarding) | **none** — R7 is a PREREQUISITE security gate on the corpus-entry authorization boundary, NOT a release unblock. R7 does NOT create a PASS or a PASS lock. |
| 11 | `prevDwellMs` correctness issue | **CLOSED / VERIFIED** | `docs/evals/P009A_PHASE_C_DWELL_FIX_RESULTS.md` — prevDwellMs was 0 on 100% of device rows (ShotSegmenterV5 mutated only a value-type copy); fix `prevDwell = max(0, newShot.startMs − prevShot.startMs)` verified in Phase C | — | regression-guard on future segmenter changes | none (remains closed; mandate §15 asked it be preserved until independently evidenced closed — it is closed with device evidence) |

## iOS device demonstration (mandate §15)

**Has an end-to-end perception → preliminary decision → safe response device demo been RUN with measured
output?** — **NO (honest).** What HAS been measured on a real iPhone 14 Pro Max: the **signal-path
infrastructure only** — shot segmentation counts + latency (P008A), Tier-0 grouping attempt + the binding
SAME/NEW overlap finding (P009A R1/R2), privacy container cleanliness. Artifacts are SHA-locked under
`docs/evals/artifacts/` (e.g. `P008A_BEFORE_crossapp_session.log`, `P009A_R1_AFTER_crossapp_device_tier0.log`,
`P009A_R2_MEASURED_tier0_evidence.log`).

**NOT measured on device:** end-to-end content-intelligence scoring, multimodal expert-mesh output
validation, presentation rendering, and production CPU/energy/thermal budgets (one attempt in P008A R1
captured no Instruments trace).

**Blocker for a fuller demo in THIS environment:** the R7 builder sandbox is a macOS headless shell that
cannot `swift test`, cannot drive an iOS device/simulator broadcast-extension session, and cannot run
Instruments. A device demo is therefore **BLOCKED (environment)**, not fabricated.

**Executable test plan (when a device + consent are available), read-only / synthetic / consented only:**
1. Build the GuardianLab harness (internal, D-0011) onto a provisioned iPhone (requires a DEVELOPMENT_TEAM
   — `EXTERNAL_EXECUTION_DEPENDENCY`, D-0014).
2. Start a consented ReplayKit broadcast over a synthetic or user-owned reel; run ShotSegmenter (Tier-0) +
   the Vision/NaturalLanguage heads in-process; log ONLY derived scalars (no raw frames).
3. Emit a PRELIMINARY (uncalibrated, clearly-labelled) decision via the deterministic policy engine — do
   NOT display a production score (gate CLOSED); do NOT enable Presentation/Glyph/Motion.
4. Capture an Instruments energy+thermal trace on a RELEASE build; record CPU/memory/wakeups.
5. Verify the container is clean afterward (privacy). Store the SHA-locked log under `docs/evals/artifacts/`.
This plan ingests NO real data into the blocked corpus, fits NO production model, asserts NO unavailable
cross-app capability, shows NO calibrated production score, and bypasses NO consent requirement.

## Carried risks (preserved until independently evidenced closed)

- **SAME/NEW Tier-0 overlap** (row 3) — safe item grouping is NOT achievable from cheap Tier-0 visual
  features. BINDING.
- **Thermal risk of per-frame evidence logging** (row 8) — real in the evidence build; mitigated in
  release by `EvidenceBuildPolicyV1` OFF, but no release-build device thermal trace yet.
- **ECE 0.250 UNMET** (row 10) — calibration gate unmet; release blocked.
- **Device resource budgets UNSET** (row 8) — no measured production budgets.
- **RWC-REVIEWER-ROOT-ONBOARDING** + **no corpus / no PASS lock** — zero-data invariants; first-asset
  authorization remains BLOCKED.

## Audit-lane vs product-lane (explicit)

The AUDIT14→AUDIT20→R7 rounds are **security hardening of the corpus-entry authorization boundary** — a
prerequisite that must PASS before any real corpus asset may enter, which in turn is a prerequisite for
calibration, which is a prerequisite for release. R7 moved the AUDIT lane forward (closed A20-F1..F4
structurally, ready for AUDIT21). It moved the PRODUCT lane **not at all**. The product remains
engineering-only with device-measured signal-path infrastructure and a binding set of open blockers.

### R7-07 suite evidence (audit lane only — 2026-10-24, measured)

R7-07 completed the AUDIT20 probe inversions (5/5) + the `RWCPreregistrationR7Tests` MAINSESSION stubs
(6/6). Measured in the completion engineer's sandbox (Apple Swift 6.3.3): `swift build` clean;
`swift test --parallel` **1146/1146 tests, 0 failures, run ×2** (two independent runs); targeted
`RWCPreregistrationR7Tests|AUDIT20_RWCPre14R6ReauditProbes` **21/21, 0 failures**. The AUDIT20 inversions
flip five probes from "exploit observed (R6)" to "refusal observed (R7)" while the six residual probes stay
BYTE-IDENTICAL to the frozen original (`0ec33211…`) — verified by extraction + byte compare. This is
AUDIT-lane evidence (authorization boundary); it adds **no** product capability, **no** PASS, **no** PASS
lock, and **no** corpus. Full evidence: `docs/calibration/preregistration/RWC_PREREGISTRATION_R7_CHANGE_LEDGER.md` §14.
