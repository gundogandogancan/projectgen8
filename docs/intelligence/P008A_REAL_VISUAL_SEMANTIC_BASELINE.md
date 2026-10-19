# P008A — Real Visual Semantic Baseline V1 (§3)
`VisualSemanticBaselineV1` (GuardianIntelligence): Apple public Vision only — VNClassifyImageRequest (categories),
VNGenerateImageFeaturePrintRequest (similarity capability), VisionOCRProvider (OCR concepts). Output
`VisualSemanticEvidenceV1` → provenance-bearing `ModalEvidenceSignal`s (rawMediaRetention="none"). Honest availability
(available/partial/unavailable); **never claims full scene understanding from generic labels.** Tested on owned fixtures
(`P008AVisualBaselineTests`). No face identity / biometric / sensitive-trait inference. External VLM remains UNAVAILABLE
(rights matrix) → baseline is the FAST visual semantic path; a compact embedding is the future T2/DEEP upgrade.
