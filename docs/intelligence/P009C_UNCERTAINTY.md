# P009C — Semantic Uncertainty (`SemanticUncertaintyModelV1` + `EvidenceWeigherV1`)

## Evidence weighting (§10 laws — tested `testCorrelatedEvidenceNotOvercounted`)

- Per-record weight = calibration class (uncalibrated 0.8 / heuristic 0.5 / unavailable 0) × confidence ×
  coverage × OOD(0.4) × contradiction(0.7) × identity-stability(0.6) discounts.
- **Correlated evidence never multiplies certainty:** all text-lexicon-derived evidence (OCR, speech
  transcript, safety/benefit/attention/symbol lexicon hits) is ONE independence family — within a family
  only the MAX survives; across families combination is bounded (max + 0.15 per extra family, capped 1).
  OCR+speech floods of the same words provably collapse to one family.
- Confidences are never averaged.

## Uncertainty axes (§11)

epistemic · missing modality · identity (provisional 0.6) · temporal (stale/deadline discards) ·
language (UNSUPPORTED 0.8) · contradiction · OOD · provider unavailability. `overall = max(axes)`.

## Knowledge states

`UNAVAILABLE` (no evidence) → `CONFLICTING` (unresolved contradiction) → `UNKNOWN` (overall ≥ 0.8) →
`AMBIGUOUS` (≥0.5 or weak) → `LIKELY` → `KNOWN` (strong + low uncertainty). UNKNOWN is a first-class
result (tested: empty-segment scenario yields UNKNOWN/UNAVAILABLE and blocks DNA).
