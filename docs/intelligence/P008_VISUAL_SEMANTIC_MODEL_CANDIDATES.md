# P008 — Visual Semantic Model Candidates (§6)
## Outcome: NO rights-clear, commercially-usable on-device visual-semantic model INTEGRATED.
Built-in Apple Vision (classification, feature print, saliency, object/scene, barcode/QR, OCR, image quality) is used as
a FAST evidence provider, but is NOT treated as full semantic/VLM understanding (§5). For a compact on-device
visual-semantic embedding / VLM (memes, symbolic meaning, scene context), every candidate must document name/version,
source, license, commercial rights, training-data disclosure, size, quantization, RAM, latency, Core ML feasibility,
tasks, limitations, safety weaknesses (§6). **Without the ability to verify license + provenance at implementation time,
no candidate was downloaded or integrated** (repo rule: do not integrate unclear-rights models). Status:
`VISUAL_SEMANTIC_EMBEDDING = UNAVAILABLE_PENDING_RIGHTS_CLEAR_CANDIDATE`. FAST path remains built-in Vision + perceptual
signature; a compact embedding is reserved for the T2/DEEP path once a rights-clear candidate is verified. Not faked.
