# P008A — Temporal Understanding V1 (§17) — real hierarchy, not contract-only
`TemporalUnderstandingEngineV1` (GuardianCore, `temporal-understanding-v1`): sparse sampled frames → SHOTS (perceptual
jump / OCR-token turnover) → SCENES (consecutive shots sharing OCR topic tokens) → representative frame per shot +
timestamp-ALIGNED evidence (each ModalEvidenceSignal placed into the scene covering its time). Lightweight (no heavy
model on the hot path). Tested: a news→ad frame sequence yields ≥2 scenes/shots (not a flat bag) + evidence aligned to
scene0. Builds on ContentBoundaryV2 + existing WholeVideoAnalyzer/TemporalGraph. NOT a full cinematic engine (honest):
chapter-level + action reasoning remain future; the VIDEO→SCENE→SHOT/WINDOW core is now real + tested.
