# P008A-R1 — Boundary + Resource Device Results (REAL re-run, 2026-10-19)
Fixed build (ContentBoundaryEngineV2, policy boundary-policy-v2, EXTENSION_FAST). User ran ONE broadcast: ~20 distinct
Instagram items incl. high-motion, switched app and back, stopped. Evidence pulled derived-only; container held ONLY the
.log (0 media). Immutable: docs/evals/artifacts/P008A_R1_AFTER_crossapp_rerun.log (SHA-256 8510ee92...).

## BEFORE → AFTER
| Metric | BEFORE (aHash) | AFTER (BoundaryEngineV2) |
|--------|----------------|--------------------------|
| frames | 3558 | 3593 (one session; app-switch did NOT interrupt) |
| boundary triggers (candidates) | 406 | 74 |
| committed NEW_CONTENT / analyzed | 168 analyzed | **5 committed, 5 analyzed (4 heavy + 1 cache reuse)** |
| cheap path p50 / p95 | 0.079 / 0.185 ms | 0.125 / 0.311 ms |
| peak memory | not measured | **29.2 MB** (< 40 MB target, < ~50 MB limit) |
| thermal | not measured | **nominal** |
| score | UNKNOWN | UNKNOWN (5/5) |
| raw media persisted | 0 | 0 |

## Manual approximate ground truth (MANUAL_APPROXIMATE_GROUND_TRUTH; no per-frame timestamps)
- expectedDistinctContentItems ≈ 20; expectedAppTransitions ≥1; expectedInterruptions = 0 (broadcast stayed active across the app switch).
- committed NEW_CONTENT = 5. The 5 commits had sigDist 18–43, layoutDelta 8–12 (clear swipes) → likely all true positives.
- **true-positive ≈ 5 · false-new ≈ 0 · missed-new ≈ 15**
- **precision ≈ 1.00 · recall ≈ 0.25**
- over-detection ratio (committed/true): BEFORE ≈ 8.4 (168/20) → AFTER ≈ 0.25 → now UNDER-detection.

## Verdict
- Over-detection / false-new spam: **FIXED** (406→74 candidates, 168→5 committed; within-item motion no longer spams).
- Resource: **PASS** — peak 29.2 MB, nominal thermal, sub-ms cheap path (CPU/energy xctrace not captured this run → DEVICE_EVIDENCE_INSUFFICIENT for those).
- Privacy: **PASS** — only the derived .log; 0 media.
- UNKNOWN gating: **PASS** — all 5 UNKNOWN.
- Automatic session: **PASS** — 1 session, app-switch handled live (no restart), 1 manual Start action over ~20 items.
- **Boundary ACCURACY: FAIL (overcorrected)** — recall ≈ 0.25; ~15 real content changes MISSED. §13 requires actual swipes
  still captured + count close to ground truth. 5 vs ~20 is NOT close.

## Root cause of under-detection + next fix (NOT applied this turn — would be tune-to-fit without re-validation)
Debounce/dwell + thresholds swung too far: `debounceFramesBetweenNew=6` likely merged fast consecutive swipes, and/or
`perceptualNew=18`/`layoutNew=8` rejected real Instagram swipes whose chrome (shared Reels layout) yields small layoutDelta
and moderate perceptual change. Retune `ContentBoundaryPolicyV2` (lower debounce, lower perceptualNew, OR commit on a
strong isolated perceptual jump even within debounce), add real labeled device fixtures, then RE-RUN before claiming PASS.
