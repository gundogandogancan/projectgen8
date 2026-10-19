# P008A-R3 — Realistic Fixture Generator

Status: `TESTED`. Source: `packages/GuardianKit/Sources/GuardianCore/RealisticFixtureGeneratorV4.swift`.
Rights: 100% project-generated deterministic synthesis; reproduces only STATISTICAL motion characteristics from
`DeviceMotionProfileV1` — never any real user content.

## Why rebuilt
R2's fixtures used per-frame drift 0.005–0.10 (unrepresentative) → lab passed, device failed. R3 parameterizes the
generator from the real device motion profile so realized fixture energies match reality.

## Full-frame motion model
Each frame: content regions (center/global + edges/top/bottom unless pinned as chrome) all move with
`base + motionOffset`, matching real feed video where the whole content area moves. `chrome*` pins a UI region
(persistent chrome / overlay). Smooth 4-bin luma histogram (Gaussian kernel) so small luma changes → small
histogram changes. Row/col projections identify a segment and translate on swipes (coherent-translation cue).

## Realism check (printed by the tune test)
Realized fixture `sameItemMotionMedian ≈ 0.080`, `transitionDistMedian ≈ 0.324` vs profile `0.123 / 0.370` — same
order of magnitude and the key cut≫motion separation reproduced (R2's were ~8× too small).

## Slices (§15) — realistic amplitudes from the profile
low-motion-static, talking-head, high-motion-sport (sustained large motion, no mid-cut), panning-landscape,
subtitles, comments-overlay, menu-overlay, autoplay-crossfade (gradual), ad-transition, rapid-3-swipe, slow-swipe,
repeated-same (identical → not a boundary), same-theme (small identity gap), dark-to-dark, bright-to-bright,
persistent-chrome, center-only, partial-screen. Each labels first-frame-of-new-segment as the true boundary.

## Three-way split (§16, no source-seed leakage)
- `TUNE`     = `corpus(seed: 0)` — the only set used to choose policy params.
- `HELD-OUT` = `corpus(seed: 1)` — frozen-policy eval, once.
- `STRESS`   = `corpus(seed: 2, stress: true)` — motion ×1.6 (exceeds observed) + pathological slices:
  stress-extreme-motion-no-cut (40 frames), stress-long-high-motion (60), stress-rapid-5-swipe (2-frame dwell),
  stress-dense-overlays. Not touched until held-out ran.

`SegmentEvalV4` greedily matches committed NEW_SEGMENT ↔ labeled boundary within ±4 frames →
precision / recall / F1 / duplicate-per-item / false-new-per-item / maxConsecutiveCommitRun + realized-motion telemetry.
