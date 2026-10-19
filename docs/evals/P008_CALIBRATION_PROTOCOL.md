# P008 — Calibration Protocol + Dataset Contract (§20,§21)
`SuitabilityEvalExample` (GuardianCore): id, rightsClass, language, modality, contentType, sourceSurface,
groundTruthDimensions{}, annotatorAgreement, expectedAdmission, sensitiveSliceTags. Dataset `SuitabilityEvalDatasetV1`
starts TR + EN and must span: text-only, image+text, audio-only, speech, short-video, meme, subtitle-conflict,
sarcasm/euphemism, symbol-heavy, mixed-language, incomplete-evidence. **No personal raw cross-app capture may silently
become training data** (§20, §25).
Metrics (`CalibrationMetrics`, tested): classification precision/recall/F1 + false-safe rate; probability ECE + Brier;
ordinal MAE; system abstention/false-safe/disagreement/cross-language-gap/per-modality-gap. A high average score cannot
hide catastrophic false-safe failures (false-safe is measured independently).
## Current calibration STATUS: `UNAVAILABLE_INSUFFICIENT_DATA`.
No rights-clear labeled TR/EN dataset exists yet, so the fusion gate keeps `calibrationValid=false` → the system returns
UNKNOWN instead of an uncalibrated number. The metric CODE exists and is unit-tested; real calibration RESULTS are
pending a rights-clear dataset. We do NOT present uncalibrated 0–100/0.0–10.0 precision as truth.
