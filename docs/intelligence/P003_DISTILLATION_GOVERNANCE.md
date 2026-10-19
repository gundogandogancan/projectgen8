# P003 — Teacher→Student Distillation Governance

**Doc status:** `CANONICAL` · **Phase:** 3 · **Date:** 2026-10-18 · PROMPT 003 §18, §19. **No distillation run this phase** (no custom model trained — real heads are Apple-native + deterministic lexicon/rules). This governs any future run.

## Rules
- Teacher model is **not production authority** — only generates *weak labels* offline.
- Only **approved/licensed** data may be sent to a teacher (`rights-provenance.schema.json`, `trainingAllowed=true`). Never private user screens; never child private data.
- Weak labels are **never silently promoted** to ground truth — human/evidence verification required (`P002_HUMAN_LABELING_PROTOCOL.md`, 5-plane firewall).
- Student must **beat baseline on held-out eval**, be **calibrated**, and pass **regression** before `ACTIVE_LAB`.
- `ACTIVE_PRODUCTION` is out of scope for Prompt 003.

## Required run manifest (future, §18)
dataset version · train/val/test split + seed · architecture · optimizer/hyperparameters · class weighting · augmentation · metrics · calibration · export · quantization · Core ML conversion · checksum · model manifest. No notebook-only magic; every run emits a manifest to `ml/manifests/`.

## Status
`DISTILLATION_STATUS = NOT_RUN` — infrastructure/governance defined; triggered only when a custom model is justified and rights-clear data exists.
