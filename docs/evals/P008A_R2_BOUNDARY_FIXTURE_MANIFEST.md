# P008A-R2 — Owned Boundary Fixture Manifest

Status: `TESTED` · Rights: all material project-generated (deterministic synthesis), no third-party clips.
Source: `packages/GuardianKit/Sources/GuardianCore/BoundaryFixtureHarnessV3.swift`.

## Rights & provenance
Every fixture frame is a synthetic `MultiRegionSignature` produced by `BoundarySignatureFactory`
(thermometer luma codes + 4-bin histogram). No recorded video, no screenshots, no social-platform
media is used. Therefore the corpus is **rights-clear by construction** and reproducible from seed.

## TUNE / HELD-OUT split (no leakage)
`BoundaryFixtureGenerator.corpus(seed:)` builds the SAME 18-slice structure but shifts every content
value by `seed * 0.07`:
- `TUNE`   = `corpus(seed: 0)` — the only set inspected while choosing policy parameters.
- `HELD-OUT` = `corpus(seed: 1)` — unseen derivatives; evaluated exactly once with the frozen policy.
Split is by deterministic derivative offset, so no individual labeled frame appears in both sets.

## The 18 labeled slices
Each slice declares exact true-boundary frames (`k == 0` of each item; `repeated-same` relabels the
identical second start to `false` because an identical repeat is not a *visual* boundary).

| # | Slice | Purpose / hard case |
|---|-------|---------------------|
| 1 | static-cards | distinct center per item, ~0 motion |
| 2 | talking-head | small sustained motion |
| 3 | high-motion-sport | LARGE within-item motion, NO cut — must not false-boundary |
| 4 | panning-landscape | steady coherent drift |
| 5 | subtitles | bottom overlay appears/disappears within item |
| 6 | comments-overlay | bottom region change, same content |
| 7 | menu-overlay | large single-region (bottom) change |
| 8 | autoplay-transition | clean new item |
| 9 | ad-transition | big brightness/histogram shift |
| 10 | rapid-3-swipe | short dwell, 3 distinct items |
| 11 | slow-swipe | long dwell |
| 12 | repeated-same | identical repeat → not a detectable visual boundary |
| 13 | same-theme | moderate center change, shared theme (subtle) |
| 14 | dark-to-dark | both low luma, center pattern differs |
| 15 | bright-to-bright | both high luma (subtle) |
| 16 | persistent-chrome | top/bottom identical across items, only center changes |
| 17 | center-only | edges static, content lives in center |
| 18 | partial-screen | content in center, moderate |

## Ground-truth matching
`BoundaryEvalV3.evaluate` greedily matches each committed NEW to a labeled boundary within ±3 frames;
extra commits near an already-matched boundary count as duplicates, unmatched commits as false
positives, unmatched truths as false negatives. Metrics: precision / recall / F1 / duplicate-per-item.

## Reproduce
```
cd packages/GuardianKit && swift test --filter P008AR2BoundaryV3Tests
```
