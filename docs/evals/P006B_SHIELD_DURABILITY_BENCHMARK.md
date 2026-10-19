# P006B — Shield Durability Benchmark

Re-run of the Shield benchmarks on the **durable** path (persist → fresh store → rebuild → lookup), with p50/p95/p99.
Test: `GuardianCoreTests/ShieldDurabilityBenchmarkTests.swift`. LAB host (macOS dev host, 2026-10-18) — NOT device-certified.

## Measured (after the O(N²) rebuild fix)

| Rules (N) | cold load + rebuild | warm lookup p50 | p95 | p99 | delete | update |
|-----------|---------------------|-----------------|-----|-----|--------|--------|
| 10      | 275 µs    | 13.67 µs | 14.50 µs | 18.79 µs | 5.75 µs | 4.04 µs |
| 100     | 874 µs    | 13.71 µs | 14.58 µs | 20.12 µs | 2.92 µs | 3.42 µs |
| 1,000   | 6.74 ms   | 13.33 µs | 14.71 µs | 20.12 µs | 3.67 µs | 5.00 µs |
| 10,000  | 66.8 ms   | 12.96 µs | 14.42 µs | 33.21 µs | 3.83 µs | 3.71 µs |

## Interpretation
- **Warm lookup (exact match + shortlist) is flat ~13 µs p50 across 10 → 10,000 rules.** Persistence did not slow the
  hot pre-exposure path. `matchersRun` stays bounded (asserted < 60).
- **Cold load is O(N)** (JSON decode + single-pass index build): 275 µs → 66.8 ms for 10k rules.
- **delete / update are O(tokens-of-rule)** (~3–6 µs) thanks to the reverse-map index — not O(all rules).

## Regression fixed during 006B
The first durable implementation rebuilt the index via `upsert`→`remove`, where `remove` scanned **all** token keys →
O(N²). Measured **13.9 s** cold load at 10,000 rules (a §16 device-health violation). Adding per-rule reverse maps
(`ruleTokens`, `ruleSource`) and a direct-insert rebuild path brought it to **66.8 ms** — a ~208× improvement. This is
why we quote the *new* measurements and not the P006A "~10 µs flat" headline alone.

## Honesty / limits
- LAB host microbenchmarks; not device CPU/battery/thermal evidence (still `PENDING_EXTERNAL_DEPENDENCY`, no team).
- 10,000 rules is a synthetic stress ceiling; real personal rule sets are far smaller. Cold load is designed to run
  **off the main actor** (see device-health discipline) so even the 10k case cannot block UI at launch.
- Image-reference lookup cost is one Vision feature print per compared frame (measured in P006A), independent of N.
