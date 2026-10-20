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

V2 ADDENDUM (A14-F11/F12):
WHAT COUNTS AS OPENING - NOT opening: sealed-manifest hash verification, manifest integrity check,
encrypted-storage existence check. OPENING: viewing labels, running model inference on the set,
reading outcome-bearing metadata, partial metric computation, debug scoring, manual content inspection
beyond permitted pre-seal QA. AUTHORIZED OPENER: the evaluation runner role ONLY, under a logged
PRE-authorized evaluation event; every opening is append-only logged (who/when/commit/purpose);
access control = sealed set stored separately from working corpus with opener-role gating.
MATERIAL-CHANGE MATRIX - MATERIAL (FINAL status lost): weights, thresholds, features, rubric, metric
implementation, calibration estimator, split policy, label semantics, model revision affecting
predictions. NON-MATERIAL: pure typo/docs changes with zero semantic/code-behavior effect, ONLY via an
explicit audited correction record - no discretionary 'small enough' judgment exists.
REVOCATION x HELD-OUT: revocation BEFORE opening => affected assets removed, set re-sealed or
invalidated per predeclared law; revocation AFTER opening => the held-out set loses FINAL status AND
every aggregate computed from the invalidated asset set is NO LONGER VALID FINAL EVIDENCE - preserved
as historical invalidated results (never deleted, FM-014).
