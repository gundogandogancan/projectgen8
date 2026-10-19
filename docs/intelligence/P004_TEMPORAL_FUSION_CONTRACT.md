# P004 — Temporal Fusion Contract (V2)

**Doc status:** `CANONICAL` · **Phase:** 4 · **Date:** 2026-10-18 · PROMPT 004 §13. Implemented in `TemporalFusionV2` (`temporal-fusion-v2`).

## Rules (deterministic, versioned)
1. **Visual graphic signal may dominate exposure safety** even when the transcript is neutral.
2. **Text context may disambiguate** a text-only category (e.g. neutral medical-education downgrades a DISEASE text match when no graphic visual is present).
3. **Modality conflict lowers confidence** (one available modality flags, the other doesn't → confidence ×0.6).
4. **Missing modality stays UNKNOWN** (both absent → no categories, confidence ≤0.15) — never counted as safe or bad.
5. **Time-local risk ≠ condemning the whole video** — a single flagged window doesn't auto-block the video.
6. **Repeated local risk influences whole-video admission** (≥3 flagged windows → `repeatedLocalRisk`).

## Whole-video output
`WholeVideoFusion`: per-segment `FusedSegment` (categories + confidence + modalityConflict) + `flaggedFraction` + `repeatedLocalRisk` + `anyUnknown`. Downstream the deterministic `ScoreAdmissionFusionV1` + `PersonalProjectionLayer` consume these with the evidence-coverage gate (no score when coverage insufficient). No averaging of probabilities.
