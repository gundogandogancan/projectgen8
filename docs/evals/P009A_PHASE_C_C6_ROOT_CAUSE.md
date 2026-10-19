# P009A Phase C — C6 Root Cause (data-first)
Reproduced the auditor probe case and inspected FIRED EVIDENCE (not aggregate S): stress bright-to-bright boundary
fired `cut-prior + long-dwell + theme-continuity + histogram-continuity + chrome-continuity + regional-continuity`,
theme distance **0.073** (strong anchor, dwell-immune), projection **0.410** (STRUCTURE silent), real dwell 5000 ms
(conflicting evidence, ignored), S=0.632 → SAME. Exact failure chain: (1) strong-theme anchor granted dwell
immunity; (2) four measured-correlated gross-luma channels counted as four proofs; (3) no independent-family
requirement; (4) temporal conflict (long dwell) had no veto power over a "strong" visual match. Coalescer/cache not
involved. Fix: EvidenceIndependenceGuardV1 (see its doc) — families + temporal-support requirement. NOT done:
device-count tuning, fixture constants, app geometry, strongNew weakening. Result: original C6 probe PASSES
untouched; case now returns AMBIGUOUS (its labeled-safe outcome).
