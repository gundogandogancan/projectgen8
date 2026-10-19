# P009A-R1 — Tier-0 HELD-OUT Results (run once, frozen)
Status: `TESTED`. Set: `Tier0CorpusV1.corpus(seed:1)`, profile EXTENSION_FAST_TIER0, 44 items.

| §13 gate | target | achieved | verdict |
|----------|-------:|---------:|:-------:|
| new-item precision | ≥ 0.98 | **1.000** | PASS |
| new-item recall (expected-NEW) | ≥ 0.90 | **1.000** (raw incl. AMBIGUOUS_OK boundaries: 0.850) | PASS |
| F1 (expected) | ≥ 0.94 | **1.000** (raw 0.919) | PASS |
| same-item merge precision | ≥ 0.99 | **1.000** | PASS |
| same-item merge recall | ≥ 0.80 | **0.873** | PASS |
| false cross-item merge / item | ≤ 0.005 | **0.0000** | PASS |
| internal multi-cut coalescing | meaningful | shots/item 2.25; montage/music-video/slideshow/B-roll coalesce | PASS |
| rapid different items separate | — | rapid-swipes all distinct | PASS |
| AMBIGUOUS rate | ≤ 0.20 | **0.133** (3 of them labeled AMBIGUOUS_OK) | PASS |
| analyses avoided | > 0 | **0.48** | PASS |

**ALL §13 Tier-0 held-out gates PASS.** Missed merges (0.127) are first wild internal cuts before references
accumulate — held provisional (safe) and partially repaired by the deferred coalescer. Not hidden: same-template,
visually-similar, montage, rapid, cut-presenting slices all printed per-slice in the test log.
