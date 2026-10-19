# P008A-R1 — BEFORE Baseline (immutable)
Real session: iPhone 14 Pro Max (iPhone15,3), iOS 26.6, team 47XQMQZLF6, app com.gen8.guardian.dev.
Extension build during that session used the OLD boundary logic: `ContentChangeDetector` (P007D cheap aHash + settle),
NOT `ContentBoundaryDetectorV2`. No layout signature, no dwell/debounce commit gate.
## Immutable evidence
- File: `docs/evals/artifacts/P008A_BEFORE_crossapp_session.log` (30 KB, 336 lines, derived-only).
- SHA-256: `96a92d02f1917e9885d57f3518f6ac2cce9c940bafc897dfe864ee5f798224d6`
## BEFORE numbers (the baseline to beat)
- Session 1: frames=525, changes=111, analyzed=44. Session 2: frames=3033, changes=295, analyzed=124, heavy=120, reuse=4.
- Total frames=3558, **total boundary triggers=406, total analyzed=168** vs ~20 real content items → gross over-detection.
- firstTrustworthyMs cheap path p50=0.079, p95=0.185, max=1.276. 164/164 UNKNOWN. raw persisted media=0. 1 interruption → 1 restart.
This 406-trigger behavior is the BEFORE baseline; the fixed build must show a MATERIAL reduction on a new session.
