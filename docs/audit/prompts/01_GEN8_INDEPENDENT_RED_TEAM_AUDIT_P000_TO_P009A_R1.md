# GEN8 — INDEPENDENT RED-TEAM AUDIT OF THE ENTIRE PROJECT
## From P000 through P009A-R1
## Read-only evidence audit before further architecture claims

**RECOMMENDED MODEL:** Claude Fable
**SESSION REQUIREMENT:** NEW CLEAN CLAUDE CODE SESSION. Do not use the implementation session's conversational context.
**EFFORT:** High / maximum practical reasoning
**MODE:** AUDIT FIRST. NO SOURCE-CODE CHANGES UNTIL THE AUDIT REPORT IS COMPLETE.
**SWITCH:** `/model` → Fable
**VERIFY:** `/status`

# PURPOSE

The project has accumulated many self-reported implementation, test, lab, and device claims.
The same agent often implemented, tested, and summarized the work.

This audit exists to independently answer:

1. What is actually implemented in the repository?
2. What is only documented/planned?
3. What claims are supported by raw evidence?
4. What claims rely only on synthetic fixtures or self-authored tests?
5. What claims are contradicted by real-device evidence?
6. Are test/eval splits genuinely independent?
7. Are privacy/resource/platform-capability claims actually true?
8. Are there mocks, dead code, debug-only paths, or target-membership mistakes that make a reported feature non-production?
9. Are metrics recomputable from immutable artifacts?
10. Is the architecture internally coherent enough to continue to P009A-R2/P009B?

# NON-NEGOTIABLE AUDIT RULES

- Do not trust previous markdown reports merely because they exist.
- Recompute metrics from source artifacts/logs where possible.
- Inspect production target wiring, not only library code.
- Inspect Xcode target membership/build settings/entitlements.
- Run tests yourself.
- Inspect whether tests execute production code or parallel fake implementations.
- Distinguish:
  - VERIFIED
  - VERIFIED_WITH_LIMITATIONS
  - PLAUSIBLE_NOT_PROVEN
  - UNSUPPORTED
  - CONTRADICTED
  - BLOCKED_BY_PLATFORM
  - NOT_TESTABLE_IN_THIS_SESSION
- Do not "fix while auditing".
- Do not silently change thresholds, fixtures, or policies.
- Do not rewrite historical evidence.
- Do not use the prior final reports as ground truth.
- Treat real-device evidence as stronger than synthetic evidence when they conflict.
- Treat `UNKNOWN` as correct when evidence is insufficient.
- No "god level", "production ready", "self-improving", "zero impact", or "proven" language unless evidence supports it.

# A. REPOSITORY / BUILD INTEGRITY

Verify:
- actual repository root and current branch
- git status
- relevant commit history if available
- Xcode project targets/schemes
- GuardianCore / GuardianKit package wiring
- Broadcast Upload Extension target membership
- Widget/Live Activity target membership
- bundle IDs / signing / entitlements
- App Group reality
- `NSSupportsLiveActivities`
- ReplayKit extension build/install path
- no private API or unsupported hidden capture path
- no stale duplicate implementation bypassing the claimed canonical engine

Record exact commands and results.

# B. CLAIM LEDGER — P000 THROUGH CURRENT

Discover all project prompts/reports/docs for:
- P000 / architecture baseline
- P001 core
- P002 real Vision/text/identity
- P003 semantic/safety/shield
- P004 temporal/video
- P005 media E2E
- P006 universal multimodal runtime
- P006A/B/C Shield/Glyph/reference system
- P007 native surfaces / ReplayKit / Live Activity
- P008 multimodal understanding/calibrated score
- P008A automatic guardian/calibration
- P008A-R1/R2/R3/R4/V5 segmentation history
- P009A hierarchy/item identity
- P009A-R1 profile-aware grouping

For each milestone create a ledger row:
- claim
- implementation file(s)
- production wiring
- test evidence
- real-device evidence
- synthetic-only?
- current truth status
- contradiction/limitation
- verdict class

# C. TEST SUITE AUDIT

Run all current tests.

Verify:
- total test count
- failures
- skipped tests
- conditional compilation that hides tests
- debug-only behavior
- test target source dependencies
- whether fixtures call the same production classes used by the extension
- whether production code has separate branches not exercised by tests
- whether acceptance tests can pass through hardcoded fixture-specific logic

Sample and inspect at least:
- boundary/shot segmentation tests
- cadence tests
- Tier-0 grouping tests
- Tier-1 grouping tests
- cache/ContentDNA tests
- pack lifecycle tests
- learning-signal tests
- privacy tests
- resource boundedness tests

# D. DATA LEAKAGE / EVAL METHODOLOGY AUDIT

For every Tune/Held-out/Stress/Device-like corpus:
- identify generator source
- identify seeds
- check train/tune vs held-out leakage
- check shared templates/parameters that make held-out trivial
- check whether thresholds were selected after observing held-out
- check whether device-like fixtures were constructed after seeing device failures
- classify each dataset:
  - independent enough for engineering evidence
  - weakly independent
  - contaminated/overfit risk
  - invalid

Pay special attention to the historical pattern:
synthetic PASS → physical-device FAIL.

# E. DEVICE EVIDENCE RECOMPUTATION

Locate immutable device logs and SHA-lock records.

At minimum verify/recompute where artifacts exist:
- old aHash over-detection
- R1 under-detection
- V3 over-detection
- V4 residual over-detection
- V5 shot-level run
- P009A item-group run
- P009A-R1 Tier-0 item-group run

Recompute from raw derived logs:
- frames
- shot/segment counts
- grouped item counts
- candidate counts
- SAME/NEW/AMBIGUOUS
- cache reuse
- p50/p95 latency where the raw log supports it
- memory high-water where logged
- thermal state distribution
- broadcast start/finish/interruption
- score UNKNOWN counts

Do NOT accept copied summary numbers if the raw artifact is available.

# F. LATEST P009A-R1 ROOT-CAUSE CLAIM — SPECIAL AUDIT

The latest report says:
- real Tier-0 same evidence is weak
- projection/histogram/theme continuity are "essentially absent"
- but `evidence=false` and per-channel evidence-build telemetry was not captured

Audit this carefully.

Answer separately:
1. Which channel values are actually present in the device log?
2. Which channel-specific conclusions are directly measured?
3. Which are inferred from aggregate S/N scores?
4. Is the statement "projection/histogram/theme are absent" proven, partially supported, or unsupported?
5. Does the proposed evidence-build run genuinely close this gap?

No hand-waving.

# G. PRIVACY AUDIT

Inspect production code for:
- file writes
- UserDefaults
- caches
- app-group/shared-container writes
- network requests
- URLSession
- analytics SDKs
- raw frame/image/video/audio serialization
- OCR transcript persistence
- speech transcript persistence
- content-title/history persistence

Verify device-container sweep claims if artifacts exist.

Classify:
- raw observation lifetime
- retained derived state
- local persistence
- cloud behavior
- telemetry behavior

Do not infer privacy solely from docs.

# H. RESOURCE / PERFORMANCE AUDIT

Verify source and evidence for:
- cheap-path p50/p95
- firstTrustworthyMs semantics
- memory high-water
- thermal
- queue depth
- dropped frames/samples
- CPU
- energy
- model load/unload
- pack size
- bundle size

Flag every metric that is:
- directly measured
- proxy measured
- synthetic only
- not captured

Explicitly verify that `firstTrustworthyMs` is not being misrepresented as semantic-understanding latency.

# I. PLATFORM CAPABILITY AUDIT

Verify current implementation truth for:
- ReplayKit user-consented cross-app observation
- automatic session continuity
- inability to silently start ReplayKit
- Dynamic Island / Live Activity rendering
- App Group / cross-process state transfer
- app/window identity exposure
- OCR/speech/audio availability in the extension
- Control Center / native surfaces if claimed

Classify each as:
- implemented + physically proven
- implemented but not physically proven
- blocked
- planned
- unsupported by platform

# J. OCTOPUS / THIN-APP AUDIT

Verify:
- GuardianMetaBrain skeleton actually exists
- ExpertRegistry
- router
- evidence bus
- provenance ledger
- capability resolver
- model pack registry
- pack manifest
- lifecycle manager
- resource governor
- learning signal bus
- bundle-size measurement

Check whether these are:
- functional runtime paths
- contract-only skeletons
- docs only

Do not call contracts "implemented intelligence" if they do not execute meaningful inference.

# K. SELF-IMPROVING / NETWORK INTELLIGENCE AUDIT

Determine exact current evidence class:

- LOCAL_LEARNING_IMPLEMENTED
- GLOBAL_SIGNAL_COLLECTION_IMPLEMENTED
- FEDERATED_OR_AGGREGATE_LEARNING_EXPERIMENTAL
- GLOBAL_MODEL_IMPROVEMENT_PROVEN

Verify:
- whether any user experience currently updates a local model/policy
- whether any global learning signal is actually collected
- whether consent gates are functional or contract-only
- whether any federated/DP process exists
- whether any model/policy is actually improved from user data

Do not let "interfaces exist" become "the intelligence learns".

# L. SAFETY / CALIBRATION AUDIT

Verify:
- score-confidence separation
- UNKNOWN gating
- numeric score suppression
- calibration datasets and current ECE/false-safe status
- H1 violence/gore/explicit visual safety gap
- ChildAgePolicy status
- Shield behavior
- semantic glyph status
- whether any positive state can leak across ambiguous identity

# M. CODE QUALITY / DEAD PATH AUDIT

Search for:
- TODO/FIXME/HACK
- fatalError
- placeholder implementations
- synthetic-only paths
- unused classes
- duplicate policies
- stale versions
- unreachable code
- debug flags that alter behavior
- hardcoded acceptance constants
- "pass" tests that do not assert production behavior

# N. INDEPENDENT ADVERSARIAL TESTS

Without modifying production code, add a separate audit test target or temporary audit harness only if needed.

Try to break:
- shot vs internal cut
- same-looking different item
- different-looking same item
- rapid swipes
- high-motion pan
- long montage
- crossfade
- app switch
- ambiguous same/new
- missing modality
- corrupted cache key
- stale ContentDNA
- pack checksum/signature
- no-consent global signal
- thermal FAIR degradation
- repeated session start/stop

Clearly label these as auditor-authored tests.

# O. FINAL EVIDENCE MATRIX

Produce a compact top-level matrix:

| Subsystem | Implementation | Lab Evidence | Physical Device Evidence | Independent Audit Verdict | Blocking Issue |

At minimum:
- observation
- privacy
- shot segmentation
- item grouping
- temporal hierarchy
- ContentDNA
- cache
- Shield
- multimodal perception
- speech
- audio
- score calibration
- Dynamic Island
- model packs
- local learning
- global learning
- family/child
- cross-platform

# P. PROJECT PROGRESS — RECOMPUTE, DO NOT REUSE OLD PERCENTAGES

Give two percentages with uncertainty bands:
1. iOS Guardian beta path
2. full Universal Gen8 vision

Base them on independently verified subsystems, not documentation volume.

Explain exactly what is counted and excluded.

# Q. GO / NO-GO FOR NEXT STEP

The audit must end with one of:

`GO — CONTINUE TO MEASURED TIER-0 EVIDENCE CALIBRATION`

`FIX CRITICAL AUDIT FINDINGS BEFORE CONTINUING`

`BLOCKED — REQUIRED EVIDENCE UNAVAILABLE`

If GO:
do NOT implement the next revision in this same audit session.
Only identify the exact next evidence task:
a scripted `GEN8_EVIDENCE_BUILD` session measuring real per-channel Tier-0 cross-cut distributions.

# REQUIRED AUDIT OUTPUT

Create:
- `docs/audit/GEN8_INDEPENDENT_RED_TEAM_AUDIT_P000_TO_P009A_R1.md`
- `docs/audit/GEN8_CLAIM_EVIDENCE_LEDGER.csv`
- `docs/audit/GEN8_DEVICE_EVIDENCE_RECOMPUTATION.md`
- `docs/audit/GEN8_TEST_METHODOLOGY_AUDIT.md`
- `docs/audit/GEN8_PRIVACY_RESOURCE_CAPABILITY_AUDIT.md`
- `docs/audit/GEN8_OPEN_BLOCKERS.md`

FINAL REPORT HEADINGS:

## 1. AUDITOR SESSION / MODEL
## 2. REPO / BUILD INTEGRITY
## 3. CLAIM LEDGER SUMMARY
## 4. TEST SUITE INDEPENDENT RUN
## 5. EVAL METHODOLOGY / LEAKAGE
## 6. DEVICE EVIDENCE RECOMPUTATION
## 7. LATEST ROOT-CAUSE CLAIM AUDIT
## 8. PRIVACY
## 9. RESOURCE / PERFORMANCE
## 10. PLATFORM CAPABILITY TRUTH
## 11. OCTOPUS / THIN-APP TRUTH
## 12. SELF-IMPROVING INTELLIGENCE TRUTH
## 13. SAFETY / CALIBRATION
## 14. CODE QUALITY / DEAD PATHS
## 15. ADVERSARIAL TEST RESULTS
## 16. EVIDENCE MATRIX
## 17. VERIFIED PROJECT PROGRESS
## 18. CRITICAL FINDINGS
## 19. NON-CRITICAL FINDINGS
## 20. GO / NO-GO

Then STOP.
