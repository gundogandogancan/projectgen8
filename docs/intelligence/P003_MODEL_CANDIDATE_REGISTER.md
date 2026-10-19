# P003 — Model Candidate Register

**Doc status:** `CANONICAL` · **Phase:** 3 · **Date:** 2026-10-18 · PROMPT 003 §4. Preference: Apple-native → small validated open model (clear license) → custom distilled → cloud (future). **No model downloaded this phase.**

| Task | Model/engine | Source | Version | License | Commercial | Size | Modality | Langs | Mem | Latency | CoreML export | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Language ID | NLLanguageRecognizer | Apple | OS | Apple SDK | yes | — | text | many | tiny | fast | n/a (native) | **ACTIVE_LAB** |
| Semantic similarity | NLEmbedding | Apple | OS | Apple SDK | yes | — | text | per-lang | small | fast | n/a | **ACTIVE_LAB** (EN avail) |
| OCR | Vision VNRecognizeTextRequest | Apple | OS | Apple SDK | yes | — | image | many | — | medium | n/a | **ACTIVE_LAB** |
| Visual feature | Vision VNGenerateImageFeaturePrintRequest | Apple | OS | Apple SDK | yes | — | image | — | — | medium | n/a | **ACTIVE_LAB** |
| Mortality/Disease/Disaster | lexicon-v1 (ours) | ours | v1 | OWNED | yes | — | text | TR+EN | tiny | tiny | n/a | **ACTIVE_LAB** (LEXICON_V1, not a model) |
| Attention/Manipulation | lexicon-v1 (ours) | ours | v1 | OWNED | yes | — | text | TR+EN | tiny | tiny | n/a | **ACTIVE_LAB** |
| Sensitive Visual (graphic) | — none rights-clear — | — | — | — | — | — | image | — | — | — | — | **UNAVAILABLE** (do not improvise) |
| Explicit-sexual classifier | — none rights-clear — | — | — | — | — | — | — | — | — | — | — | **UNAVAILABLE** |

**Acceptance gate (§33):** a head is `ACTIVE_LAB` only with license OK + test set + baseline + FP/FN documented + latency measured + resource class + calibration status + rollback. **`ACTIVE_PRODUCTION` is NOT allowed in Prompt 003.** No heavyweight/cloud model added. Also recorded in `MODEL_REGISTRY.yaml`.
