# P009A-R1 — Privacy Recheck
Status: source-level `VERIFIED`; device-container recheck repeats after the fresh run.
Added Tier-0 features are DERIVED-ONLY: projection correlation (8-bin luma vectors), 4-bin histogram L1, cadence
timing, regional distances — computed from already-derived SegmentFrameV4 data; nothing new persisted; no raw
frame/audio/OCR-transcript/title; no upload. Threat-model updates (§16):
- projection fingerprint leakage: 8-bin coarse vectors, non-reconstructive; stay in-process; only scalar scores logged.
- histogram linkage: 4 bins — too coarse to link across sessions; derived class bounded retention.
- deferred coalescing history: bounded (≤6 shots/side), session-scoped, derived IDs only.
- cache correlation: quantized keys + full-signature verify + re-analysis on collision (unchanged).
Prior device-container rechecks: 4 consecutive clean runs (`ZERO_VERIFIED_ON_DEVICE`); repeat on the R1 run.
