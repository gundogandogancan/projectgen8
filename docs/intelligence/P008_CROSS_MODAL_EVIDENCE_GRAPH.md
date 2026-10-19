# P008 — Cross-Modal Evidence Graph
`CrossModalEvidenceGraphV1` / `CrossModalEvidenceFuser` (§14). Links evidence by concept across modalities.
NOT a confidence average: agreement across ≥2 modalities BOOSTS (diminishing gap-closing, bounded ≤1); a conflicting
concept pair PENALIZES BOTH (×0.4, ambiguous content); missing modality is tracked, never treated as agreement/zero.
Example proven in tests: OCR+speech "earthquake" → fused > single-modality base; caption "funny-cats" vs visual
"political-rally" → conflict recorded + both penalized. Provenance preserved per concept (supporting modalities).
