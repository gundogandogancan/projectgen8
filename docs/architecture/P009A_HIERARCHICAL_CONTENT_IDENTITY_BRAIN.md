# P009A — Hierarchical Content Identity Brain

Status: lab `TESTED` (held-out §20 gates ALL PASS) · device item-group validation `PENDING` (user-gated).
Source: `ContentIdentityHierarchyV1.swift` + `ContentItemGroupingV1.swift` (GuardianCore).

## Canonical hierarchy (§1 — PERMANENT CANON)
```
OBSERVATION → FRAME → SHOT/PERSISTENT-VISUAL-SEGMENT → SCENE → CONTENT ITEM → TOPIC/NARRATIVE
→ CONTENT DNA → PERSONAL POLICY → GUARDIAN ADMISSION
```
A cut may create a new SHOT without a new ITEM. A swipe may create a new ITEM even if visually similar.
**These levels are never collapsed again.** (This closes the R1–R4 root confusion: V5's device "57 vs ~20" was
shot-level truth judged by an item-level ruler.)

## Entry truth preserved (§0)
V5 evidence intact (all 5 artifact SHAs re-verified this phase). V5 thresholds NOT retuned; its contract is
reclassified via `ShotSegmenterV5` (adapter) as shot detection. Device ground truth was approximate — the 57 segments
are NOT claimed to be individually verified cinematic shots; that uncertainty is preserved.

## Layers implemented
- **ShotSegmenterV5** (§3): frozen V5 wrapped; emits `ShotBoundaryEvent` + `ShotDescriptorV1` (derived signatures,
  transition metadata, timestamps, provenance). Never claims item detection.
- **HierarchicalTemporalGraphV1** (§4): shot/scene/item nodes, typed edges (adjacency, likely/confirmed same/new,
  ambiguous, continuity, interaction, provenance). Bounded (`maxActiveShots`); evicted history compacts into
  `CompactedItemSummaryV1` (counts only) — proven by `testBoundedGraphMemory` (200 shots → ≤16 active, 0 lost).
- **ContentItemGroupingEngineV1** (§6): SHOT_ONLY → CANDIDATE/CONFIRMED SAME/NEW → AMBIGUOUS state machine over the
  evidence graph. Internal cuts stay in one item; a new item needs item-level evidence; insufficient evidence →
  AMBIGUOUS provisional split; revisions versioned (`ContentIdentityRevision`: provisional/refined/split/merged/invalidated).
- **ContentItemEvidenceAccumulatorV1** (§8): per-item consolidation; risk is monotone-max (a later dangerous shot
  escalates the item; earlier harmless shots never suppress it — `testItemRiskEscalation`).
- **ContentDNAItemV1** (§10): item-level DNA (identity/revision, modality summaries, temporal span, risk, uncertainty,
  provenance, privacy class, model versions, expiry). Numeric suitability stays OFF.
- **ContentIdentityCacheV1** (§11): non-reconstructive quantized-signature keys; hit/collision/miss; collision
  degrades to re-analysis; bounded; invalidation by DNA id.

## Safety-first merge (§7 — canonical rule)
`uncertain SAME_ITEM → never silently inherit a safe Guardian admission.` Implemented structurally:
`ItemGroupingDecisionV1.safeAdmissionInheritance` is true ONLY on non-provisional SAME_ITEM_CONFIRMED. AMBIGUOUS =
provisional split; late strong evidence may merge it back (versioned MERGED revision). False split = compute waste;
false merge = safety error → merge precision optimized first (frozen policy: held-out mergeP = 1.000, xMerge = 0).

## Held-out result (once, frozen `item-grouping-policy-v1`)
newP **1.000** · newR **0.944** · F1 **0.971** · mergeP **1.000** · mergeR 0.970 · false cross-item merge **0.0000**/item ·
shots/item 2.60 · all §20 predeclared gates PASS. See P009A_HELDOUT_RESULTS.
