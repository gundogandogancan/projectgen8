# P008 — Personal Suitability Score Contract
`PersonalSuitabilityScoreV1` (`suitability-score-v1`): score?(0–100, nil when insufficient), scoreBand, confidence
(evidence confidence — SEPARATE), evidenceCoverage, admissionState, reasonCodes[SuitabilityReason], dimensionScores{},
calibrationRevision, policyRevision, contentDNARevision, modelPackRevision.
# SCORE ≠ CONFIDENCE. UNKNOWN beats a fake number.
Dimensions (§17): SAFETY_ALIGNMENT, TOPIC_ALIGNMENT, BENEFIT, ATTENTION_PRESSURE(penalty), EMOTIONAL_LOAD(penalty),
POSITIVE_EXPOSURE, CHILD_POLICY(optional). EVIDENCE_QUALITY is meta (gates display, not meaning).
Fusion `SuitabilityFusionV1` (§18): Phase-1 deterministic, transparent weighted fusion over AVAILABLE dims (renormalized),
explicit floors/caps (safety<0.3 caps ≤39; child<0.5 caps ≤39), hard precedence safetyFloor>hardShield>numeric.
**Seed weights = `seed-weights-v1-UNCALIBRATED` — expert-set, explicitly NOT claimed scientific/calibrated.**
GATE: a numeric score is returned ONLY when `evidenceCoverage ≥ minCoverage` AND `calibrationValid`; else score=nil,
band=UNKNOWN. Since no rights-clear calibration dataset exists yet, `calibrationValid=false` in production → the system
shows UNKNOWN rather than an uncalibrated number. Color bands (§35) derive from band; a hard Shield/safety decision overrides color.
