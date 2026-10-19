# P008A-R4 — Fixture Generator V5

Status: `TESTED`. Source: `FixtureGeneratorV5.swift`. Rights: 100% project-generated; reproduces only motion
statistics from `DeviceMotionProfileV2` — no real user content (§12).

## New vs V4
- **Per-frame timestamps** (cadence): `frameIntervalMs`, `jitter` (irregular spacing), `dropEvery` (dropped-sample gaps).
- **Continuous-PAN slices**: `drift` makes a segment evolve SMOOTHLY (steady base drift + low per-frame noise +
  coherent sliding projection) with NO abrupt step → must stay SAME_SEGMENT. (`panning-continuous`, `pan-then-cut`,
  `stress-long-pan-no-cut`.)

## Slices (§12)
low motion, sustained high motion, continuous pan, pan-then-cut, subtitles/comments/menu overlays, autoplay
crossfade, ad transition, rapid 3-swipe, slow swipe, repeated-same (not a boundary), same-theme adjacent, dark-to-dark,
bright-to-bright, persistent chrome, center-only/partial-screen. STRESS adds extreme-motion-no-cut (40f),
long-pan-no-cut (50f), long-high-motion (60f), dense-overlays.

## Splits (§13, no seed/source leakage)
- `TUNE` = `corpus(seed:0)` — only set used to pick policy params.
- `HELD-OUT` = `corpus(seed:1)` — frozen eval, once.
- `STRESS` = `corpus(seed:2, stress:true)` — motion ×1.6 + pathological slices.
- `CADENCE-STRESS` = `corpus(seed:1)` rendered at 60/30/20 fps + jitter + dropped samples; compare commit COUNTS.

`SegmentEvalV5` runs the timestamped accumulator and matches committed NEW_SEGMENT ↔ labeled boundary within ±7
frames (the time-based confirm adds a few frames of legitimate latency) → precision/recall/F1/duplicate/false-new +
maxConsecutiveCommitRun + totalCommitted (for cadence comparison).
