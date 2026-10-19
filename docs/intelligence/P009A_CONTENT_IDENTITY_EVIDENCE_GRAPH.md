# P009A — Content Identity Evidence Graph

Status: `TESTED`. Source: `ContentIdentityEvidenceGraphV1` (ContentItemGroupingV1.swift).

## Contract (§5)
Every identity evidence edge carries: **source · timestamp · confidence · freshness · privacy class · capability
provenance · model/policy version**. Bounded container (default 1024 edges, FIFO eviction) — tested.

## Modalities + sources currently wired (honest availability)
| modality | sources (Tier) | status |
|----------|----------------|--------|
| VISUAL | theme-continuity / theme-discontinuity from existing multi-region signatures (T0) | IMPLEMENTED |
| UI/SURFACE | chrome-same / chrome-change (persistent layout, T0); official app identity only via official APIs | chrome IMPLEMENTED; app identity NOT (iOS does not expose cross-app bundle ids to a broadcast extension — never faked) |
| TEMPORAL | swipe-gate, crossfade, cut-prior, edit-burst cadence, long-dwell (T0) | IMPLEMENTED |
| TEXT | caption fingerprint match/change (T1, app profile; derived non-reconstructive) | CONTRACTED; extension profile = unavailable (honest nil) |
| AUDIO | audio-continuity / audio-break flags (T1; continuity flags only — no audio retained; speaker/timbre NOT used) | CONTRACTED; extension profile = unavailable |
| CACHE/PRIOR | dna-cache-hit prior (T0 via ContentIdentityCacheV1) | IMPLEMENTED |
Apple Vision feature print / embeddings / VLM identity: Tier-1 escalation candidates, NOT wired in this phase
(capability + resource gating pending) — routed through the meta-brain when they arrive as packs.

## Evidence weighting (frozen `item-grouping-policy-v1`)
Merge: caption-match 0.35 · audio-continuity 0.30 · theme-continuity 0.22 · edit-burst 0.12 · cut-prior 0.10 ·
chrome-same 0.05. New: swipe-confirmed 0.48 · chrome-change/app-surface 0.38 · caption-change 0.30 · theme-discontinuity
0.22 · audio-break 0.20 · crossfade 0.15 · long-dwell 0.12 · cache-prior 0.30·conf. Not a blind average — strong
new-item evidence (confirmed swipe / chrome change) VETOES a merge regardless of merge score (§7).
