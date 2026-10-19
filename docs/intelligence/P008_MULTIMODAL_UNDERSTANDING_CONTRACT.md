# P008 — Multimodal Understanding Contract
`MultimodalContentUnderstandingV1` (GuardianCore, `mmu-v1`, Codable) — produced BEFORE any score; NON-personal.
Every signal = `ModalEvidenceSignal` with provenance: modality, kind, value, rawConfidence, calibratedConfidence
(nil ⇒ UNAVAILABLE, never fabricated), evidenceClass (OBSERVED_FACT/MODEL_INFERENCE/LEXICON_RULE/WEAK_SIGNAL/
PROVIDER_METADATA/UNAVAILABLE), modelID, modelRevision, language, timeRange, rawMediaRetention. **No naked unproven label.**
Separation (§15, enforced in code): Content CHARACTER (humor/learning/music/…) ≠ Protection/Risk ≠ Personal Suitability.
Modalities A–I (§3–§11): structured-text/caption/transcript/OCR/visual/audio/speech/music/symbol/temporal/metadata.
`evidenceCoverage` (fraction of expected modalities that produced determinable evidence) + `uncertainty` are first-class.
