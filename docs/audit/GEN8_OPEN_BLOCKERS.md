# GEN8 — OPEN BLOCKERS (Independent Red-Team Audit, P000 → P009A-R1)

Audit completed 2026-10-19 by a fresh-context continuation auditor (Claude Fable 5, Claude Code) finishing a prior clean-context auditor's partial run. Companion docs: `GEN8_INDEPENDENT_RED_TEAM_AUDIT_P000_TO_P009A_R1.md`, `GEN8_CLAIM_EVIDENCE_LEDGER.csv`, `GEN8_DEVICE_EVIDENCE_RECOMPUTATION.md`, `GEN8_TEST_METHODOLOGY_AUDIT.md`, `GEN8_PRIVACY_RESOURCE_CAPABILITY_AUDIT.md`.

Severity classes:
- **B (BLOCKER-NEXT-STEP)** — must be resolved inside/at the start of the very next evidence session.
- **C (CRITICAL-BEFORE-BETA)** — does not block the Tier-0 evidence calibration step, but blocks any beta/external build.
- **H (HYGIENE / EVIDENCE INTEGRITY)** — weakens the evidence chain; cheap to fix; should be fixed immediately.

## B — blockers for the next step (GEN8_EVIDENCE_BUILD Tier-0 calibration)

1. **B1 — Per-channel Tier-0 grouping telemetry does not exist.** `GuardianBroadcastExtension/SampleHandler.swift:75-78` emits only segmenter MOTION scalars under `GEN8_EVIDENCE_BUILD`; no code anywhere emits per-decision `theme distance / projection corr / histogram L1 / chrome delta / regional / cadence / fired-evidence list`. The proposed evidence run CANNOT close the root-cause gap until derived-only per-channel emission is added (the repo's own plan, P009A_R1_DEVICE_VALIDATION_RESULTS.md step 1, acknowledges this). All eight recorded device sessions have `evidence=false`.
2. **B2 — Root-cause channel attribution is currently inference, not measurement.** "Projection/histogram/theme essentially ABSENT" is under-determined from aggregate S values (S=0.21 ⇒ raw≈0.20 decomposes into ≥5 distinct channel subsets under the frozen Tier-0 weights). No re-tuning decision should be made from this inference; measure first (B1), then tune.

## C — critical before any beta / external build (not blocking the evidence step)

3. **C1 — Always-on derived proof logs in production code paths.** `SampleHandler.emit` (extension container `gen8_crossapp_proof.log`) and `GuardianLiveActivityController.emit` (app container `gen8_la_proof.log`) write unconditionally, and the unified log mirrors with `privacy: .public`. The `persistToDisk=false` label in BROADCAST_STARTED is true only for raw frames — misleading as written. Build-gate the writers; fix the label.
4. **C2 — App Group is broken and silently faked.** Stale suite id `group.com.aymedo.Gen8` (NativeSurfaces.swift:15, GuardianControlState.swift:10) vs bundle family `com.gen8.guardian.dev`; no `.entitlements` files exist; both call sites fall back silently to `UserDefaults.standard`, so cross-process state transfer does not actually function while appearing to.
5. **C3 — Extension shield evaluation is vacuous.** One hardcoded `demo-spoiler` textExact rule against an envelope whose `ocrText` is always nil (SampleHandler.swift:50, 104-106). `match=NO_MATCH` and `firstTrustworthyMs` (~0.07 ms) are therefore near-meaningless; must be re-based (real read-only shield store, and real inputs) before any protection claim.
6. **C4 — Calibrated trustworthy score NOT achieved.** Calibration pilot honestly FAILED (false-safe 0.50, verdict POOR); every device decision is `score=UNKNOWN` (hardcoded literal in the extension). UNKNOWN-first gating is correctly enforced; no numeric score may be surfaced until a calibration gate passes.
7. **C5 — H1 visual safety (violence/gore/explicit) is an honest stub** (`sensitive-visual-unavailable-v0`, returns `.unavailable`). No child/family capability exists (no ChildAgePolicy implementation found in production sources). These are declared gaps, but they cap any safety claim.
8. **C6 — Tier-0 can false-merge under stress.** Auditor probe (AUDIT_AdversarialProbeTests, seed-2 stress corpus, slice `bright-to-bright`) produced 1 cross-item false merge (overall xM/item 0.0189 on that corpus vs the 0.005 target that is only gated on seed-1 held-out). A false merge can inherit a safe-admission state across distinct items — safety-relevant; fold into the post-evidence re-tune and extend the documented gates to the stress corpus.

## H — hygiene / evidence integrity

9. **H1 — Git anchoring absent.** Repo has exactly one template commit (`725153a Initial Commit`, branch `main`); all engine code, docs, artifacts, and `.sha256` locks are UNTRACKED (plus 3 modified tracked files). The SHA locks prove nothing about tamper-resistance without VCS anchoring (mitigated only by the recomputed byte-prefix chain across the seven artifacts). Commit the tree; commit artifacts + locks.
10. **H2 — Gate-softening debt in the test suite** (see GEN8_TEST_METHODOLOGY_AUDIT.md §5): recall carve-out reported as 1.000 vs raw 0.850; assert floors below stated §14 targets; cadence comment ≤10% vs gate ≤0.20; tautological assertion P009AR1Tier0Tests.swift:197 (`|| true`); print-only tune scans inside the 323 "passing tests".
11. **H3 — `TrainingRunTests` mutates the working tree** (`ml/training/runs/`) at test time.
12. **H4 — No CPU/energy artifact exists for any device run** (docs admit DEVICE_EVIDENCE_INSUFFICIENT). Capture one Instruments/xctrace trace per device milestone from the next run onward.
13. **H5 — Stale env facts in CLAUDE.md** (old bundle id `com.aymedo.Gen8`, "no DEVELOPMENT_TEAM") contradicted by the pbxproj (team `47XQMQZLF6`, `com.gen8.guardian.dev`). Update to prevent future-agent confusion.

## Explicitly NOT blockers

- Device under-performance of Tier-0 grouping (economy 1.4% vs lab 43-48%) is an honestly reported FAIL and precisely what the next evidence step addresses.
- GuardianMedia shipping nowhere (lab-only) is by design at this phase.
- Octopus/thin-app files being contract-only skeletons is self-declared and correctly not claimed as implemented intelligence.
