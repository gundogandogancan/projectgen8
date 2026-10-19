# P009B — TUNE Results (seed 0)

**Harness:** `P009BExpertMeshTests.testTuneCorpus` → `P009BCorpusV1.runScenario` (full mesh, APP_FULL_TIER1)

## Final (after fix, before freeze)

```
P009B_TUNE scenarios=17 failures=0 abstentions=18 contradictions=2
```

- failures=0 — all structural expectations met.
- abstentions=18 — honest UNAVAILABLE/UNKNOWN emissions across the 17 scenarios (absent modalities
  abstain rather than guess).
- contradictions=2 — `educational-plus-sensitive` and `benign-then-risky` both produce the required
  risk-vs-positive contradiction edges.

## Defect found and fixed during TUNE (the split's purpose)

`unsupported-audio-classes` initially FAILED: when every sound class was unsupported,
`AudioEventExpertV1` emitted `audio:unsupported-classes:N` but suppressed the explicit
`audio:no-validated-events` honest-state marker (labels-nonempty ternary bug). Fix (ExpertArmsV1.swift):
the marker is emitted whenever zero classes validate. This is an honesty-strengthening fix, not a
threshold tune; no routing policies, thresholds, or expectations were adjusted to make anything pass.

## Freeze

After this single fix, expert policies, routing order (resource costs), thermal gates, lexicon sets,
and all corpus expectations were FROZEN. HELD-OUT/STRESS/OOD were then run once (see their docs).
