# P009A — Hierarchical Fixture Manifest

Status: `TESTED`. Source: `HierarchicalCorpusV1.swift`. Rights: 100% project-generated deterministic descriptor
streams — no third-party media, nothing reconstructable. Labels are EXACT ShotID + ItemID + transition type +
expected grouping (§18).

## Level of synthesis
Fixtures are SHOT-DESCRIPTOR streams (the grouping engine's input contract): representative derived signatures
(via the V4/V5 frame factory), transition metadata, timing, optional caption fingerprints / audio-continuity flags.
Shot-level sensor behavior is separately covered by the V5 fixture suite (unchanged); grouping is evaluated on its
own contract boundary. Device reality encoded: many true swipes present as plain CUTs (translation unseen between
samples) — the `cutSwipe` variants force the boundary to be caught by caption/audio/theme/dwell evidence.

## The 24 §18 scenarios
1 one-shot-one-item · 2 multi-cut-one-item · 3 montage · 4 talking-head-broll · 5 slideshow · 6 music-video ·
7 high-motion-then-new · 8 pan-within-item · 9 same-speaker-cuts · 10 topic-continuous-scenes ·
11 visually-similar-adjacent · 12 same-template-adjacent · 13 repeated-item · 14 ad-after-content · 15 rapid-swipes ·
16 slow-swipe · 17 crossfade-autoplay · 18 persistent-chrome-items · 19 overlay-within-item ·
20 app-surface-transition · 21 no-audio-item · 22 caption-continuity · 23 caption-topic-change ·
24 ambiguous-identity (AMBIGUOUS is the labeled-acceptable outcome).
STRESS adds: stress-long-montage (24 internal cuts — must not explode) and stress-many-rapid-items (8 items,
800 ms dwell — must not collapse).

## Splits (§18, no leakage)
TUNE = `corpus(seed:0)` (only set used for policy selection) · HELD-OUT = `corpus(seed:1)` (frozen eval, once) ·
STRESS = `corpus(seed:2, stress:true)`. Seed shifts themes + caption identities (different derivatives, same structure).

## Metrics (§19)
`GroupingEvalV1`: new-item P/R/F1 (confirmed decisions), merge precision/recall, FALSE CROSS-ITEM MERGE per item
(safety-critical), ambiguous count (with acceptable-ambiguous tracking), shots/item. Split/merge asymmetry is
reported, never hidden.
