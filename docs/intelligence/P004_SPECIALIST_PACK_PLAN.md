# P004 — Specialist Pack Plan

**Doc status:** `CANONICAL` · **Phase:** 4 · **Date:** 2026-10-18 · PROMPT 004 §7.

## FAST-PATH heads (cheap enough for pre-exposure)
| Head | Engine | Resource | Langs | Cacheable | FAST |
|---|---|---|---|---|---|
| Language | NLLanguageRecognizer | TINY | many | yes | ✅ |
| OCR/text | Vision (fast mode) | MEDIUM | many | yes | ✅ (deadline-gated) |
| Topic/semantic | NLTagger + lexicon | LIGHT | TR+EN | yes | ✅ |
| MDD topic | lexicon-v1 / mdd-linear-v1 | TINY | TR+EN | yes | ✅ |
| Attention signals | lexicon-v1 | TINY | TR+EN | yes | ✅ |
| Lightweight entity (shield exact) | exact/alias | TINY | TR+EN | yes | ✅ |

## DEEP-PATH heads (run selectively via DeepeningPlanner)
| Head | Engine | Resource | FAST/DEEP |
|---|---|---|---|
| Semantic shield similarity | NLEmbedding | LIGHT | DEEP (governor-gated) |
| Visual feature/similarity | Vision feature-print | MEDIUM | DEEP |
| Stronger visual safety (H1) | — UNAVAILABLE — | — | — |
| Long-context transcript / claim-evidence | — future — | HEAVY | DEEP |

Each head declares latency/memory/compute/size/langs/modality/calibration/cacheability/resource-class/FAST-DEEP in `MODEL_REGISTRY.yaml` + `ON_DEVICE_MODEL_PACK.yaml`. ResourceGovernor selects the smallest sufficient FAST subset; deep heads run only when the DeepeningPlanner prioritizes a window. Scheduler does **not** launch every head for every item (§25 P003 / §7 P004).
