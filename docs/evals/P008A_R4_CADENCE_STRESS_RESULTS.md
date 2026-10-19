# P008A-R4 — Cadence-Stress Results (run once, frozen policy-v5)

Status: `TESTED`. Source: `testCadenceInvariantSegmentation` (§9/§10). Same semantic stream (`corpus(seed:1)`)
rendered at different capture cadences; compare total committed segment COUNTS.

## Results
| variant | frame interval | committed |
|---------|---------------|----------:|
| 60 fps | 16.7 ms | 14 |
| 30 fps | 33.3 ms (baseline) | 15 |
| 20 fps | 50.0 ms | 15 |
| irregular (±40% jitter) | ~33 ms | 15 |
| dropped samples (1 in 7) | 33 ms | 15 |

## §14 cadence gate
- commit-count deviation across cadence variants vs the 30 fps baseline: 60 fps = **6.7%**, 20 fps = 0%,
  jitter = 0%, drop = 0% — all **≤ 10% (and ≤ the 20% test bound)** → **PASS**.
- no systemic transition loss under modest dropped-frame gaps (drop variant = 15, same as baseline) → **PASS**.

## Reading
Because dwell / POST persistence / transition-timeout are TIME-based (ms), the SAME semantic content yields
essentially the SAME segment count whether captured at 20, 30, or 60 fps, with jitter, or with dropped samples. This
directly fixes V4 root cause #5 (frame-count logic fragile under variable ReplayKit cadence). The tiny 60 fps
deviation (one fewer commit) is within the error budget — a higher frame rate shifts a borderline high-motion cut.
