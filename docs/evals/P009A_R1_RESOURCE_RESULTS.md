# P009A-R1 — Resource Results
Status: lab `TESTED` · device `PENDING` (fresh run user-gated).
## New-evidence cost (§15, measured by construction + suite)
Projection continuity: one zero-offset correlation over 8-bin vectors (≈16 mults) per shot commit. Histogram
continuity: 4-bin L1. Cadence: two comparisons. Regional: reuses computed region distances. ALL run only on shot
commits (~1/1.6 s on device), not per frame — per-frame cost unchanged from V5 (device ref 1.294/2.856 ms).
Grouping decision: O(≤6) reference comparisons; coalescer O(≤6×6) on provisional items only. Graph/evidence/cache
bounded (323-test suite incl. 2000-shot boundedness). No Vision/VLM per shot; no low-value expensive signal added.
## Economy (lab): held-out analyses avoided 0.48; device-like 20 analyses / 35 shots (43% avoided, ≥40% gate ✓).
## §20 thermal: contract `ThermalAwareDegradationV1` (FAIR → optional deep work defers; serious/critical → none);
device time-to-FAIR/duration/recovery to be captured on the fresh run. V5-run thermal (fair 45/73) is the reference.
NOT INSTRUMENTED (honest): queue depth, dropped samples; CPU/energy xctrace only if actually captured.
