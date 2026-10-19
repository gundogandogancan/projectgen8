# GEN8 — INDEPENDENT P009E CALIBRATION / REAL SCORE RED-TEAM AUDIT
## Clean-session audit of calibration, selective prediction, and internal Personal Suitability score

**RECOMMENDED MODEL:** Claude Fable
**SESSION:** NEW CLEAN SESSION
**MODE:** READ-ONLY FIRST
**EFFORT:** High / maximum practical reasoning

Audit exact `gen8-p009e-audit-candidate` tag/SHA.

Do not trust builder report.

# 1. ENTRY / P009D REGRESSION

Verify:
- P009D locked state preserved
- F-5 teen-band contradiction genuinely closed before calibration
- H1 truth preserved
- score/glyph production display still OFF

# 2. F-5 TEEN-BAND ADVERSARIAL

Reproduce original audit case:
- declared teen profile around age 14
- sentinel-class sexual-theme/high-risk context
- relevant dimension unavailable

It must not produce `AGE_ALIGNED + NEUTRAL`.

Author nearby variants:
- age 13
- age 17
- educational sexual-health
- mild romance
- severe sexual content
- missing jurisdiction
- H1 unavailable

# 3. SCORE SEMANTICS

Verify numeric score is Personal Suitability/Admission Alignment only.

Check code cannot conflate:
- score
- confidence
- coverage
- safety probability
- policy state

# 4. DATA PROVENANCE

Classify every calibration item source:
PROJECT_OWNED_REAL / LICENSED_RIGHTS_CLEAR / SYNTHETIC_DERIVED / STRUCTURAL_ONLY.

If builder claims real-world calibration from synthetic-only data:
FAIL.

# 5. ANNOTATION METHODOLOGY

Verify:
- rubric versioned
- subjective labels independently annotated where claimed
- disagreement retained
- adjudication trace exists
- child/policy sources explicit
- no circular labels derived from the model's own output

# 6. SPLIT LEAKAGE

Check:
- exact duplicates
- near duplicates
- translations
- same clip/frame variants
- authored-template leakage
- calibration/held-out contamination
- sentinel tuning contamination

# 7. DIMENSION CALIBRATION

Verify calibrators:
- are actually fitted on allowed split
- are monotonic where required
- are versioned
- abstain if insufficient data
- do not use held-out final for tuning

# 8. COMPOSITE SCORE

Attempt:
- benefit flood against severe risk
- high score with low coverage
- high score with OOD
- high score under age restriction
- high score under strong protection
- profile mismatch

Policy veto must dominate.

# 9. SELECTIVE PREDICTION

Fresh probes:
- low confidence
- missing modalities
- unsupported language
- unsupported age slice
- H1 required/unavailable
- unresolved conflict
- stale calibration version
- OOD

Expected: score NIL / UNKNOWN or REVIEW where appropriate.

# 10. CALIBRATION METRICS

Recompute independently:
- ECE
- Brier
- reliability bins
- coverage vs accuracy
- selective risk
- false-safe
- false-warning
- abstention
- slice metrics

Do not rely on builder summaries.

# 11. SENTINEL LAW

Re-run all curated sentinels.
Sentinel false-safe must be 0 for release candidate.

Check no threshold/special-case memorization of sentinel IDs.

# 12. SLICE AUDIT

TR / EN
adult / teen / child supported slices
Shield match/non-match
high-risk / high-benefit
OOD / low coverage

Identify underpowered slices.

# 13. CACHE / PROFILE ISOLATION

Same ContentDNA, multiple profiles:
- score changes correctly
- expensive understanding reused
- no cross-user leakage
- calibration/profile version invalidates correct cache entries

# 14. PRIVACY

No private user raw content used for calibration.
No raw child/Shield profile data persisted in evidence logs.
No network/raw-media regression.

# 15. DEVICE / HUD

If physical proof claimed:
- verify internal score is from real in-app pipeline
- verify HUD distinguishes NIL/UNKNOWN
- production display remains OFF
- only exercised paths are device-proven

# 16. RELEASE GATE

Verify `ProductionScoreReleaseGateV1` remains CLOSED if any required condition is unmet.

Do not accept a "green" release gate with:
- H1 unresolved without explicit fail-closed block
- insufficient real calibration data
- failing slice
- sentinel false-safe
- no device proof
- unresolved critical audit finding

# 17. FRESH AUDITOR PROBES

At minimum:
- teen sentinel unavailable
- benefit flood
- low-coverage 95-score attempt
- OOD high-confidence attempt
- stale calibrator version
- profile cache contamination
- synthetic-only calibration overclaim
- duplicate leakage
- translation leakage
- held-out tuning leak
- score/confidence field swap
- sentinel-ID hardcode search
- release-gate bypass attempt

# FINAL REPORT

1. AUDITOR SESSION
2. GIT / REPO INTEGRITY
3. P009D REGRESSION
4. F-5 TEEN-BAND VERDICT
5. SCORE SEMANTICS
6. DATASET / PROVENANCE
7. ANNOTATION QUALITY
8. SPLIT INDEPENDENCE
9. DIMENSION CALIBRATION
10. COMPOSITE SCORE
11. SCORE / CONFIDENCE / COVERAGE
12. SELECTIVE PREDICTION
13. METRIC RECOMPUTATION
14. SENTINEL FALSE-SAFE
15. TR / EN SLICES
16. AGE / SHIELD SLICES
17. CACHE / PROFILE ISOLATION
18. PRIVACY
19. DEVICE / HUD
20. PRODUCTION SCORE RELEASE GATE
21. AUDITOR PROBES
22. OPEN LIMITATIONS
23. VERIFIED PROGRESS
24. GO / NO-GO

Final verdict exactly one:

`PASS — P009E CALIBRATION LOCKED; INTERNAL REAL SCORE VERIFIED; GO TO PRESENTATION PHASE`

or

`PASS WITH LIMITATION — ENGINEERING CALIBRATION ONLY; PRODUCTION SCORE REMAINS BLOCKED`

or

`FIX CRITICAL P009E FINDINGS`

or

`BLOCKED — CALIBRATION DATA INSUFFICIENT`

Then STOP.
Do not implement glyph/motion in audit session.
