# P009A-R1 — CrossShotProjectionContinuityV1
Status: `TESTED`. §6A: zero-offset normalized correlation of the existing 8×8 row/col luma projections across a shot
boundary — coarse spatial/layout structure continuity (production layout persists across internal cuts). Reuses the
V5 projection machinery; no raw retention, no app geometry. Fires SAME at corr ≥ 0.80 (w 0.20); fires NEW
(projection-break) at corr ≤ 0.30 (w 0.20). Style channel only — can never anchor a merge alone (see TIER0_EVIDENCE_MODEL).
