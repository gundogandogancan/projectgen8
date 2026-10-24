# RWC PREREGISTRATION R6 — CHANGE LEDGER (AUDIT19 remediation)

NO REAL DATA USED. NO production reviewer root was fabricated. Zero corpus / annotator / fit /
heldout. No PASS lock created. R6 is BUILDER READY FOR AUDIT20 — NOT a PRE-14 PASS.

Starting point: branch `phase/rwc-preregistration-r6` at HEAD
`48f91565f494f7125e9c4947369443fb5b0fc8f6` (the AUDIT19 commit). Audited R5 candidate
`f30b39322500da6e9e8602645e287cd41a61018e`. Methodology anchor
`31267a4e34e6639fcca0448694425dfabfc025a2`. AUDIT19 verdict FIX REQUIRED 1 CRITICAL / 2 HIGH /
2 MEDIUM.

Strategy: SUPERSESSION NOT MUTATION. All five findings close in NEW versioned surfaces; the R5
surfaces stay byte-frozen SUPERSEDED_ENGINEERING_HISTORY. Exactly two existing test/auditor files are
edited, both declared in `docs/audit/AUDIT19_R6_INVERSION_LOCK.md` (committed FIRST).

## New source surfaces

| file | finding | what it does |
|---|---|---|
| `packages/GuardianKit/Sources/GuardianCore/RWCRightsV6.swift` | F2, F3 | trust-root loader V2 (no public mint; capability-gated; fail-closed) + verified root V2; current-registry head witness `RWCReviewerRegistryCurrentnessStoreV1`; registry verifier V2 `verifyCurrent`; review authority V6 → verified grant V6; pre-acquisition evaluator/authorization V3 |
| `packages/GuardianKit/Sources/GuardianCore/RWCRightsV6Store.swift` | F1 | asset-rights ledger store V4: `register` requires grant V6; ledger-resident `RWCAcquisitionAuthorizationRecordV1` via `authorizeAcquisition`; crash roll-forward carried from V3 |
| `packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV4.swift` | F1 | lawful `acquire` (writes the authorization marker) + `reconcileV4` (promotes only authorized sessions) |
| `packages/GuardianKit/Sources/RWCAcquisition/RWCAcquisitionReceiptStoreV2.swift` | F4, F5 | strict scalar validation + authority-bound `prepare` + strict typed `intendedUse` parse |

## New test / evidence / tooling

- `packages/GuardianKit/Tests/GuardianCoreTests/RWCPreregistrationR6Tests.swift` — fresh R6 family
  (8 tests): lawful acquire end-to-end, crash-before-promote recovery (reconcileV4), forged
  quarantine refusal, revoked asset never promoted, F2 fail-closed + lawful synthetic chain, F3
  currentness monotonic/rollback laws + durable reopen, F4/F5 strict receipt store.
- `docs/audit/AUDIT19_R6_INVERSION_LOCK.md` — the inversion/supersession lock + frozen originals.
- `docs/audit/AUDIT19_RWCPre14R5ReauditProbes_ORIGINAL_LOCKED.swift.txt`
  (`b5232e52…`) and `docs/audit/RWCPreregistrationR5Tests_ORIGINAL_LOCKED.swift.txt`
  (`be8db856…`) — frozen originals of the two edited files.
- `docs/calibration/preregistration/RWC_FROZEN_GATES_V7.yaml` — gates V7.
- `docs/calibration/preregistration/tools/generate_freeze_manifest_v7.py` — freeze V7 generator
  (run by the main session at the R6 anchor).
- `docs/calibration/preregistration/RWC_PREREGISTRATION_R6_SECURITY_DESIGN.md` — threat model,
  trust boundaries, requirement→code→test matrix, residual-risk register, rollback procedure.
- `docs/audit/audit19_tools/a19consumer_r6/` — F2 ordinary-consumer SwiftPM package (no @testable).

## Declared edits to existing files (see the inversion lock)

- `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT19_RWCPre14R5ReauditProbes.swift` — custody
  re-anchor (test_A19_01) + 12 finding-evidence inversions (07, 08, 11, 12, 14, 17, 20, 21, 22, 23,
  24) to assert the R6 typed refusal; shared R6 fixtures added. All other probes byte-unchanged.
- `packages/GuardianKit/Tests/GuardianCoreTests/RWCPreregistrationR5Tests.swift` — absence-pin
  supersession (R5 result now EXISTS, FIX_REQUIRED 1/2/2, absent in candidate tree) + freeze V6
  census re-anchored to the candidate blobs (historical).

## Master manifest

`RWC_PREREGISTRATION_MASTER_MANIFEST.yaml` gains r6 keys (`r6_candidate_generation`, `r6_status`,
`r6_strategy`, `r6_superseded_engineering_history`, `r6_outputs`). Pinned historical keys and the
five zero-data counters are untouched. The master manifest is MUTABLE_BY_LAW / hash-exempt in the
freeze manifest.

## Evidence (builder self-measured; NOT an independent verdict)

Baseline before implementation (R6 branch at AUDIT19 commit): two pre-existing lawful
phase-transition failures — RWCPreregistrationR5Tests:844 (declared R5 absence-pin) and
AUDIT19 test_A19_01 custody (HEAD advanced past candidate on the R6 branch). Both are declared
supersessions.

After implementation + lock-listed edits: the FULL suite is GREEN. `swift test --parallel` run twice,
0 failures both runs; 1125 XCTest tests (1117 R5 baseline + 8 new R6). AUDIT19 probe family = 45
(12 inverted). R5 builder family = 11 (2 superseded). The F2 ordinary-consumer package compiles
against the public GuardianCore API with no @testable.

Ending state: all R6 content in the working tree on `phase/rwc-preregistration-r6`; the MAIN SESSION
commits in the lawful order (lock first) and performs the R6 anchor + freeze V7 regeneration + tag.
