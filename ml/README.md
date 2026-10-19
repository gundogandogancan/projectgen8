# Gen8 ML Workspace (offline, auditable)

**Doc status:** `CANONICAL` · **Phase:** 2 · PROMPT 002 §11 / 002A §7. **No giant data files in git.** Small, legally-safe, synthetic/metadata fixtures only. No scraped social video, no private screen data, no child private data.

```
ml/
  README.md                  this file
  schemas/                   machine-readable schemas (sample, label, rights-provenance, dataset-manifest)
  datasets/golden-v0/        Golden Dataset v0 (synthetic/metadata fixtures)
  evaluation/results/        machine-readable eval artifacts (latest.json emitted by EvalHarness)
  labeling/                  human-labeling protocol lives in docs/evals/P002_HUMAN_LABELING_PROTOCOL.md
  training/                  (future) training configs — no data dumps
  export/                    (future) Core ML export manifests
  manifests/                 (future) model pack manifests → see docs/architecture/MODEL_REGISTRY.yaml
```

## Hard rules
- Every sample carries rights/provenance (`schemas/rights-provenance.schema.json`). No reuse without it.
- Labels preserve the **5-plane ontology firewall** (`schemas/label.schema.json`) — never collapsed to one good/bad label.
- Eval is **per-task** (never one "AI accuracy"); artifacts in `evaluation/results/`.
- Calibration is honest; see `docs/evals/P002_CALIBRATION_V0.md` (currently `UNAVAILABLE_INSUFFICIENT_DATA`).
