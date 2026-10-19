# PROMPT P009E — CALIBRATION + REAL PERSONAL SUITABILITY SCORE
## From policy evidence to a calibrated, selective, explainable score
## INTERNAL SCORE ONLY UNTIL ALL RELEASE GATES PASS
## GLYPH / MOTION STILL OFF

**RECOMMENDED MODEL:** Claude Fable
**EFFORT:** High / maximum practical reasoning
**MODEL SWITCH:** `/model` → Fable
**VERIFY:** `/status`

# 0. HARD ENTRY GATE

DO NOT START unless the independent P009D audit verdict is exactly:

`PASS — P009D POLICY INTELLIGENCE LOCKED; GO TO P009E CALIBRATION`

Treat as immutable entry truth:
- P009A identity locked
- P009B multimodal expert mesh locked
- P009C Content World Model locked
- P009D policy intelligence locked
- score/glyph/motion are still OFF
- H1 high-risk visual safety remains unavailable unless separately proven
- device proof exists only for actually exercised paths
- no raw private media centralization

# 1. P009E ENTRY CONDITION — CLOSE P009D AUDIT F-5 FIRST

Before any numeric calibration work, close the independent-audit carry-forward:

## F-5 MEDIUM
A declared teen profile (13–17; audit example age 14) plus sentinel-class sexual-theme evidence can reach:
`AGE_ALIGNED + NEUTRAL`
while the relevant safety dimension is UNAVAILABLE and only H1-unavailable marks the evidence gap.

This contradicts the sentinel doctrine that high-risk/sentinel child cases must never become neutral/false-safe.

### Mandatory entry fix
Create a WRITTEN, VERSIONED teen-band fail-closed policy.

At minimum:
- sentinel/high-risk child-policy cases with a relevant UNAVAILABLE dimension cannot resolve to `AGE_ALIGNED + NEUTRAL`
- outcome must be `AGE_CAUTION`, `AGE_RESTRICTED`, `REVIEW`, or `UNKNOWN` according to explicit policy/source truth
- do NOT fabricate detection; this is a policy response to evidence unavailability in a sentinel-relevant context
- document why the fallback exists
- keep legal rating vs developmental policy separate
- preserve H1 honesty

Also close audit hygiene findings where safe:
- correct parent-overlay caution reason-code labeling
- include advisory inputs in policy-cache fingerprint OR explicitly prove they cannot affect cached output
- preserve secondary child reason codes under OOD-dominant UNKNOWN where semantically appropriate
- correct any HUD static-label mismatch

Run focused tests and commit before calibration.

# 2. SCORE SEMANTICS — DEFINE BEFORE FITTING

The score is:

`Personal Suitability / Admission Alignment`

It is NOT:
- objective goodness
- morality
- truthfulness
- happiness
- "healthy frequency"
- safety probability
- confidence
- evidence coverage

Define explicitly:

## Internal score
`0–100` continuous internal engineering score.

## Optional future UI
`0–10` MAY be derived later only after calibration/release gates.
P009E does not enable production display.

## Required companion values
Every score candidate must carry:
- `score`
- `scoreConfidence`
- `evidenceCoverage`
- `calibrationStatus`
- `OODStatus`
- `policyState`
- `reasonCodes`
- `profileVersion`
- `modelVersion`
- `calibrationVersion`

Score may be `nil`.
`UNKNOWN` is valid.

# 3. SCORE DISPLAY GATE

Create `ScoreDisplayGateV1`.

A numeric score may exist internally only if:
- identity authoritative enough
- required policy engines resolved
- required modality coverage for that domain/profile is sufficient
- calibration exists for relevant language/profile/domain slice
- OOD is acceptable
- no unresolved critical contradiction
- no stale evidence
- no sentinel false-safe condition
- no age-restricted / strong-protection conflict with a positive score interpretation

Production display remains OFF in P009E.

# 4. POLICY VETOES REMAIN ABOVE SCORE

Hard law:

`STRONG_PROTECTION / AGE_RESTRICTED / required REVIEW`
cannot be overridden by a high numeric score.

Numeric score is subordinate to categorical safety/policy state.

No weighted average may "wash out" a severe-risk dimension with positive benefit.

# 5. CALIBRATION TARGET DEFINITION

Build an annotation rubric for item × profile pairs.

The target is not "is this content good?"
The target is:
"Given this explicit user/family profile and this observed content evidence, how suitable is exposure under the Gen8 policy rubric?"

Use an ordinal rubric first, e.g.:
- 0 = strongly unsuitable / protect
- 1 = unsuitable
- 2 = caution / mixed
- 3 = generally suitable
- 4 = strongly aligned

Convert to expected 0–100 only after calibrated modeling.

Preserve:
- annotator disagreement
- policy-source distinctions
- child vs adult profiles
- Shield differences
- safety/benefit tradeoffs

# 6. MULTI-ANNOTATOR GROUND TRUTH

Create `CalibrationAnnotationV1`.

For subjective suitability labels:
- at least 2 independent annotations where feasible
- adjudication only when required
- preserve original labels
- compute agreement
- do not hide disagreement

For safety sentinel labels:
- use stricter explicit rubric
- sentinel no-false-safe gate is categorical

Track:
- annotator ID pseudonym
- rubric version
- locale
- profile
- item ID
- label
- confidence
- disagreement flag
- adjudication if any

# 7. DATASET PROGRAM

Build / expand a rights-clear or project-owned calibration corpus.

Required slices:
- TR
- EN
- adult
- child/teen age bands
- Shield match / non-match
- educational
- humor/satire
- sensitive news
- explicit/sexual
- violence/severe injury candidate
- self-harm
- drugs/alcohol
- gambling
- dangerous behavior
- profanity
- manipulation/attention
- calm/nature
- music
- high-benefit + high-risk conflict
- low-information
- missing modality
- OOD
- unsupported language
- H1 unavailable
- policy conflict
- visually similar but semantically different
- temporal escalation

Do not calibrate production claims on synthetic-derived-only data.

Classify corpus sources:
- PROJECT_OWNED_REAL
- LICENSED_RIGHTS_CLEAR
- SYNTHETIC_DERIVED
- STRUCTURAL_ONLY

Only the first two may support real-world accuracy/calibration claims.
Synthetic may support structural tests.

# 8. DATA SPLITS

Create non-overlapping:
- TRAIN/TUNE
- CALIBRATION
- HELD_OUT_FINAL
- STRESS
- OOD
- SAFETY_SENTINEL

Rules:
- no template leakage
- no translation-equivalent duplication across splits
- no creator/clip near-duplicate leakage where known
- calibration set is used only for calibration
- final held-out is untouched until frozen
- sentinel set is never tuned to

Use leakage auditor from prior phases plus calibration-specific duplicate checks.

# 9. DIMENSION CALIBRATION

Calibrate individual dimensions before composite score.

Candidates:
- safety dimensions
- benefit
- manipulation pressure
- emotional/sensitive load
- Shield match confidence
- age-policy confidence where labels support it

Use transparent methods appropriate to data:
- logistic / Platt scaling
- isotonic regression
- monotonic ordinal calibration
- temperature scaling where justified

Do not use complex model simply to improve headline metric.

Every calibrator:
- versioned
- slice-aware
- monotonic where semantics require
- reject if data insufficient

# 10. COMPOSITE SCORE MODEL

Create `PersonalSuitabilityScoreV2`.

Preferred architecture:
1. calibrated dimension estimates
2. explicit policy veto layer
3. transparent monotonic fusion
4. selective-abstention gate
5. final internal 0–100 score

The fusion model may be:
- constrained monotonic logistic/ordinal model
- interpretable generalized additive model
- carefully justified weighted model only if weights are learned/validated and stable

Forbidden:
- arbitrary hand-picked weights presented as truth
- hidden nonlinear black box without auditability
- benefit canceling severe safety
- one universal model if slices materially differ

# 11. SCORE CONFIDENCE ≠ SCORE

Create separate:
- `PersonalSuitabilityScore`
- `ScoreConfidence`
- `EvidenceCoverage`
- `CalibrationReliability`
- `OODRisk`

A score of 85 with low confidence is not equivalent to a reliable 85.

# 12. CALIBRATION METRICS

Required:
- ECE
- Brier score
- reliability diagram data
- calibration slope/intercept where applicable
- coverage vs accuracy
- selective risk
- false-safe
- false-warning
- abstention rate
- AUROC/AUPRC for relevant binary safety dimensions
- ordinal agreement / MAE for suitability target
- slice metrics by TR/EN, age band, Shield, content family

No single vanity metric.

# 13. ENGINEERING TARGETS

Treat these as provisional gates, not universal truths.

Candidate initial gates:
- overall ECE ≤ 0.05
- major TR and EN slices ECE ≤ 0.07
- sentinel false-safe = 0
- high-risk false-safe below a predeclared low threshold
- OOD → UNKNOWN rather than forced high-confidence score
- no age-restricted/strong-protection item can display a positive/neutral score state
- calibration coverage reported, not hidden

If data volume is too small:
do NOT relax the standard silently.
Return `BLOCKED — CALIBRATION DATA INSUFFICIENT`.

# 14. SELECTIVE PREDICTION

Create `SelectivePredictionGateV1`.

The system should abstain when:
- low confidence
- low coverage
- OOD
- language slice unsupported
- age slice unsupported
- H1 required/unavailable
- unresolved policy conflict
- model/calibrator mismatch
- identity instability

Output:
`score=nil, state=UNKNOWN/REVIEW`

Abstention is success when evidence is insufficient.

# 15. SENTINEL NO-FALSE-SAFE LAW

SafetySentinelRegistry remains supreme.

For every sentinel:
- final categorical state cannot be NEUTRAL/positive when sentinel policy says protect/restrict/review
- numeric score cannot bypass that state
- if detection evidence is unavailable, fail-closed according to written policy
- measure false-safe explicitly

Do not tune sentinel thresholds to memorize sentinel examples.

# 16. TEEN-BAND POLICY VALIDATION

After fixing F-5, create dedicated teen-band adversarial bank:
- sexual themes with unavailable visual classifier
- explicit lexical evidence
- educational sexual-health context
- mild romance
- severe sexual content
- fear/violence unavailable
- manipulation-targeted-to-minors
- missing jurisdiction
- age 13 boundary
- age 17 boundary

Verify:
- no sentinel-class case becomes AGE_ALIGNED+NEUTRAL solely because detector unavailable
- educational context may qualify but not erase unavailable high-risk evidence
- source/reason codes remain truthful

# 17. EXPLANATION MODEL

Create `ScoreExplanationV1`.

Internal explanation contains:
- top supporting calibrated dimensions
- policy vetoes
- uncertainty
- coverage
- OOD
- reason codes
- version provenance

No natural-language hallucinated rationale.
Later UI can map structured reasons to copy.

# 18. PROFILE SIMULATION

To calibrate personalization without using private user data, build explicit synthetic policy profiles:
- adult neutral
- adult with Shield
- parent profile with age bands
- strict/lenient parent preference variants within safe policy bounds

Profiles are policy fixtures, not representations of real people.

Use same ContentDNA with multiple profiles to prove:
`one expensive understanding → many cheap personal decisions`.

# 19. CACHE / RECOMPUTE

Score cache key must include:
- ContentDNA/world-model version
- profile ID/version
- Shield version
- age-policy version
- calibration version
- model/taxonomy version

Policy/profile change:
- recompute score cheaply
- do not rerun content understanding if DNA valid

No cross-user leakage.

# 20. PRIVACY

Calibration development:
- use rights-clear/project-owned data
- no private user screen/audio uploads
- no raw personal Shield/age dataset
- no hidden telemetry

Production:
- score computed locally where possible
- only derived metrics in debug/evidence logs
- no raw content persistence

# 21. DEVELOPER SCORE HUD

DEBUG only.

Show:
- internal score or NIL
- policy state
- confidence
- coverage
- calibration version
- OOD
- abstention reason
- top calibrated dimensions
- sentinel gate
- teen-band fail-closed status
- source mode REAL/LAB
- `PRODUCTION SCORE DISPLAY: OFF`

No user-facing glyph.

# 22. REAL-WORLD VALIDATION

A calibration model is not "real" merely because synthetic corpus passes.

Required before claiming production-calibrated:
- rights-clear/project-owned real media
- TR + EN
- multiple content families
- multiple profiles
- independently annotated labels
- held-out final evaluation
- device/in-app score pipeline proof where applicable

If this evidence is not available in this phase:
classify as `ENGINEERING_CALIBRATION_ONLY`.
Do not overclaim.

# 23. PHYSICAL / IN-APP VALIDATION

User-gated after freeze:
- at least one real rights-clear item with internal score
- one UNKNOWN/no-score
- one Shield profile change using same DNA
- one child/teen policy change
- one sentinel/fail-closed example
- one OOD/unsupported example

Capture:
- score/state/confidence/coverage
- policy veto
- cache reuse
- latency
- privacy
- HUD

Production display still OFF.

# 24. RELEASE SCORE GATE

Create `ProductionScoreReleaseGateV1`.

Must remain CLOSED unless all are true:
- adequate rights-clear calibration corpus
- held-out metrics pass
- TR/EN required slices pass
- age slices pass where supported
- sentinel false-safe = 0
- H1 requirements satisfied or fail-closed policy explicitly blocks score
- no unresolved critical audit finding
- physical device/in-app proof
- privacy/resource gates pass
- independent P009E audit PASS

P009E may finish with internal score calibrated while production display remains OFF.

# 25. GITHUB DISCIPLINE

Use branch:
`phase/p009e`

Atomic commits:
- P009D F-5 teen fail-closed closeout
- dataset/annotation
- dimension calibrators
- composite score
- selective gate
- metrics/eval
- HUD/docs

Before audit:
- full suite green
- clean tree
- push
- tag `gen8-p009e-audit-candidate`
- record exact SHA

If no Git remote is configured:
report `PUSH_BLOCKED_REMOTE_UNCONFIGURED`.
Do not falsely claim GitHub-backed evidence.

# 26. REQUIRED ARTIFACTS

Code:
- TeenBandFailClosedPolicyV1
- CalibrationAnnotationV1
- CalibrationDatasetRegistryV1
- DimensionCalibratorV1
- PersonalSuitabilityScoreV2
- ScoreConfidenceV1
- EvidenceCoverageV1
- SelectivePredictionGateV1
- ScoreExplanationV1
- ProductionScoreReleaseGateV1
- CalibrationMetricsV1
- CalibrationRegistryV2

Docs:
- docs/calibration/P009E_SCORE_SEMANTICS.md
- docs/calibration/P009E_ANNOTATION_RUBRIC.md
- docs/calibration/P009E_DATASET_PROVENANCE.md
- docs/calibration/P009E_DIMENSION_CALIBRATION.md
- docs/calibration/P009E_COMPOSITE_SCORE.md
- docs/calibration/P009E_SELECTIVE_PREDICTION.md
- docs/calibration/P009E_SENTINEL_GATES.md
- docs/calibration/P009E_TEEN_BAND_FIX.md
- docs/evals/P009E_TUNE.md
- docs/evals/P009E_CALIBRATION.md
- docs/evals/P009E_HELDOUT_FINAL.md
- docs/evals/P009E_STRESS_OOD.md
- docs/evals/P009E_DEVICE_VALIDATION.md
- docs/privacy/P009E_PRIVACY.md
- docs/implementation/P009E_IMPLEMENTATION_EVIDENCE.md

# 27. TEST FAMILIES

All previous tests remain green.

Add:
- P009D F-5 reproduction and fix
- teen sentinel unavailable
- teen educational sexual-health context
- score != confidence
- score != coverage
- veto cannot be overridden
- nil score under insufficient evidence
- OOD abstention
- TR/EN calibration slices
- age-band slices
- Shield profile recomputation
- same DNA / multiple profiles
- sentinel false-safe
- calibration version invalidation
- cache isolation
- reliability metrics
- score monotonicity
- low-coverage high-score prevention
- release gate closed when H1/calibration/device proof incomplete
- no raw private data
- production UI score still OFF

# 28. EXECUTION ORDER

1. verify P009D lock
2. close F-5 teen-band policy contradiction
3. close low audit hygiene findings
4. define score semantics
5. build annotation rubric
6. build/verify rights-clear dataset provenance
7. split dataset
8. calibrate dimensions
9. build monotonic composite
10. selective prediction
11. sentinel gates
12. profile simulation
13. cache/versioning
14. TUNE
15. freeze
16. CALIBRATION split
17. HELD_OUT_FINAL once
18. STRESS/OOD
19. Developer Score HUD
20. user-gated physical validation
21. privacy/resource recheck
22. ProductionScoreReleaseGate evaluation
23. final report
24. STOP
25. independent clean-session P009E audit

Do not start glyph/motion phase automatically.

# 29. FINAL REPORT

Return exactly:

1. ACTIVE MODEL / EFFORT
2. ENTRY P009D LOCK
3. GITHUB BRANCH / COMMITS / PUSH
4. P009D F-5 TEEN-BAND CLOSEOUT
5. LOW AUDIT FINDINGS CLOSEOUT
6. SCORE SEMANTICS
7. ANNOTATION RUBRIC
8. DATASET PROVENANCE
9. SPLIT INDEPENDENCE
10. DIMENSION CALIBRATION
11. COMPOSITE SCORE MODEL
12. SCORE / CONFIDENCE / COVERAGE SEPARATION
13. SELECTIVE PREDICTION
14. SENTINEL NO-FALSE-SAFE
15. TEEN-BAND VALIDATION
16. PROFILE SIMULATION
17. CACHE / VERSIONING
18. TUNE
19. FROZEN POLICIES / CALIBRATORS
20. CALIBRATION RESULTS
21. HELD_OUT_FINAL RESULTS
22. STRESS / OOD
23. TR / EN SLICES
24. AGE / SHIELD SLICES
25. DEVELOPER SCORE HUD
26. PHYSICAL / IN-APP VALIDATION
27. PRIVACY
28. RESOURCE / LATENCY
29. PRODUCTION SCORE RELEASE GATE
30. CARRIED BLOCKERS
31. TESTS
32. KNOWN LIMITATIONS
33. FILES CHANGED
34. AUDIT-CANDIDATE TAG / SHA
35. STATUS

Status exactly one:

`READY FOR INDEPENDENT P009E AUDIT`

or

`BLOCKED — CALIBRATION DATA INSUFFICIENT`

or

`FIX REQUIRED`

or

`BLOCKED`

Then STOP.

Do not enable production score display.
Do not start semantic glyph/motion.
