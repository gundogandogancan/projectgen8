# RWC-PRE-12 — SPLIT / SEALING PROTOCOL

SPLITS: TRAIN / CALIBRATION / HELD_OUT_FINAL / STRESS / OOD / SAFETY_SENTINEL (registry law unchanged).
DISJOINTNESS: (1) item-level - an asset appears in exactly one split; (2) semantic near-duplicate -
near-duplicates (same scene re-uploads, trivial edits, re-encodes; detected via content-hash + perceptual
near-dup screen + human spot check) must land in the SAME split or be dropped; (3) source leakage -
same creator/series/template clusters assigned to one split where the cluster is label-correlated.
HELD_OUT_FINAL LAW: selected BEFORE any fitting on real data; manifest (asset IDs + content hashes +
profile pairs) written and SHA-256 SEALED in-repo; RUN-ONCE - every opening event is logged
(who/when/commit); results computed with strict typed metrics only.
INVALIDATION: if after opening ANY of weights/thresholds/feature engineering/rubric/split policy changes
materially, the set LOSES FINAL status permanently; a NEW sealed final set (fresh assets or provably
unexposed remainder) is required. EMERGENCY INVALIDATION: rights revocation or leakage discovery inside
HELD_OUT_FINAL -> immediate FINAL-status loss + incident record in the resolution ledger.
ZERO data exists this round: heldout_open_count = 0 is load-bearing in the master manifest.
