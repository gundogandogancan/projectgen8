# P004 — Whole-Video Benchmark

**Doc status:** `CANONICAL` (LAB_MEASURED) · **Phase:** 4 · **Date:** 2026-10-18 · PROMPT 004 §18. Legal/synthetic only. Artifact: `ml/evaluation/results/whole-video-benchmark.json` (18 rows). Timing is LAB/sim — **NOT a device SLO**; device certification requires a physical device (`P002_REAL_DEVICE_GATE.md`).

## Durations × modes
15s, 30s, 60s, 5min, 15min, 60min × {ECO, BALANCED, MAX_PROTECTION}.

## Measured (LAB, deterministic)
- **sample count** (bounded): 1-hour video → ECO 16 · BALANCED 32 · MAX 64 (never per-frame; ≤100 cap).
- **window count**, **deepened windows planned** (ECO deepens ≤ BALANCED ≤ MAX), **coverage %**.
- Coverage definition is **included** with every number (no "whole video analyzed in X seconds" without coverage).

## Not claimed (honest)
- Wall-clock total coarse-map time, memory, thermal, energy, UI smoothness → require **device + Instruments** (pending; §19). Not fabricated.
- First-trustworthy-decision time on real media → requires real decode + device.

## Invariants verified
No full-FPS loop; sample budget bounded at all durations; ECO ≤ BALANCED ≤ MAX deepening; coverage carried through.
