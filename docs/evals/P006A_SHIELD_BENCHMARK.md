# P006A — Shield Benchmark (index scaling + correctness)

**Requirement (§16):** the shield index must stay bounded and fast as the personal rule set grows.
Test: `GuardianCoreTests/ShieldBenchmarkTests.swift` — build an index of N exact-text rules + one known "hit" rule,
evaluate a fixed sample envelope 500× per scale, measure per-eval latency and matchers run.

## Measured (macOS dev host, 2026-10-18 — LAB, not device-certified)

| Rules (N) | per-evaluation | matchers run | correctness |
|-----------|----------------|--------------|-------------|
| 10 | **10.31 µs** | 5 | hit found, action = HIDE |
| 100 | **9.92 µs** | 5 | hit found, action = HIDE |
| 1000 | **9.81 µs** | 5 | hit found, action = HIDE |

## Interpretation
- **Latency is flat across 10 → 1000 rules** and `matchersRun` stays constant (5) — the evaluator runs matchers only on
  the **shortlist** produced by the layered index (token / source / bounded-semantic retrieval), never on all N rules.
  This is the bounded-work invariant, proven, not asserted.
- Correctness is checked at every scale (the planted "earthquake" rule is always the chosen outcome with the configured
  HIDE action). No scale weakened detection.

## Honesty / limits
- These are **LAB host** microbenchmarks (deterministic, in-memory). They are **not** device CPU/battery/thermal
  evidence — that remains `PENDING_EXTERNAL_DEPENDENCY` (no signing team; see P005_DEVICE_EVIDENCE).
- Semantic matching latency depends on NLEmbedding and is measured separately; when no embedding exists the semantic
  matcher short-circuits to UNAVAILABLE (no hidden cost, no fake pass).
- Image/logo matching cost is dominated by one Vision feature-print per frame (sparse sampling from P005), not by the
  rule count — the index shortlist is text/source-driven.
