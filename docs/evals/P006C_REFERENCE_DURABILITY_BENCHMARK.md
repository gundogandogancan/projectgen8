# P006C — Reference Durability Benchmark

LAB host (macOS dev host, 2026-10-18). NOT device-certified. Tests: `ShieldDurabilityBenchmarkTests` (startup/scale) +
`P006CVisualDurabilityTests` (signature distances).

## 1. Startup / scale (durable path: persist → fresh store → rebuild → first decision)

| Rules (N) | cold load + rebuild | first usable decision | lookup p50 | p95 | p99 | delete | update |
|-----------|---------------------|-----------------------|------------|-----|-----|--------|--------|
| 10      | 248 µs    | 63.8 µs | 13.71 µs | 14.79 | 18.71 | 8.67 | 4.00 |
| 100     | 853 µs    | 23.8 µs | 13.38 µs | 13.92 | 20.83 | 2.92 | 3.33 |
| 1,000   | 7.30 ms   | 27.8 µs | 13.29 µs | 14.08 | 19.67 | 3.17 | 4.00 |
| 10,000  | 69.3 ms   | 34.9 µs | 13.12 µs | 14.21 | 23.42 | 4.12 | 4.12 |

Warm lookup flat ~13 µs across scale; cold load O(N), off-main (no MainActor block, tested). delete/update O(tokens).

## 2. Visual signature distances (structured 8×8 pattern fixtures — models a real logo/photo)

| Comparison | aHash Hamming | dHash Hamming | vector L2 | → state |
|------------|---------------|---------------|-----------|---------|
| same image | 0 | 0 | 0.000 | MATCH_HIGH |
| resized (640→320) | 0 | 0 | 0.000 | MATCH_HIGH |
| lossless PNG re-encode | 0 | 0 | 0.000 | MATCH_HIGH |
| different pattern | 25 | 20 | 0.371 | NO_MATCH |
| solid gray | 30 | 34 | 0.304 | NO_MATCH |

## 3. Demonstrated vs undemonstrated robustness (honest)
- **Demonstrated:** exact match, lossless re-encode, downscale resize (structure-preserving), unrelated-image negative
  control, true post-relaunch functional match.
- **NOT demonstrated this phase:** brightness/contrast shift, crop tolerance, rotation. The aHash (mean-threshold) and
  normalized-vector (mean-centered) designs are expected to tolerate mild brightness, but we do not *claim* it until a
  test demonstrates it. Crop/rotation are known perceptual-hash weaknesses — unsupported, documented.
- **Fixture caveat (important):** perceptual hashing needs spatial structure. Sparse text-on-white images are an
  adversarial fixture (a resized SAME image can differ more than a DIFFERENT one) — so discrimination/variant tests use
  structured pattern fixtures that reflect the real logo/photo use case. This limitation is stated, not hidden.
