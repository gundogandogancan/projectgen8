# P009C — TUNE Results

`P009C_TUNE scenarios=21 failures=0` (after the TUNE-phase defect fixes below) — then FROZEN.

## Defects found by TUNE (the split's purpose; all correctness/honesty, no threshold tuning)

1. **Segment cache-bleed:** the per-item mesh cache served segment 1's evidence to segments 2..N of the
   same confirmed item — a shot moment was masked by item-level reuse. Fix: `cacheEligible=false` for
   segment-scoped routes (context flag; default true keeps all P009B behavior byte-identical).
2. **Per-item deep lease vs multi-shot items:** F1's (item,domain) lease suppressed per-shot vision in
   montages. Fix: segment-scoped routes lease per (item, SHOT, domain); item-level dedupe unchanged.
3. **Recovery vs monotone risk:** the temporal expert's monotone memory kept segment risk high forever,
   so recovery could never be observed. Fix: CURRENT-moment risk (non-temporal families) drives recovery;
   historical risk (`registerRisk`) drives escalation and is never lowered.
4. **Readiness inflation:** temporal bookkeeping alone (always-available counters) made empty/unsupported
   content DNA-ready. Fix: readiness requires SEMANTIC (non-temporal) strength + state ∉ {UNKNOWN, UNAVAILABLE}.
5. **`n/a` placeholder versions** from unavailable-evidence records leaked into durable meshModelVersions
   → excluded (available evidence only).
6. **Annotation authoring correction:** benign→risky expected a contradiction; it is an ESCALATION event
   (risk arrives after the benefit; no same-moment pair) — expectation corrected and documented inline.

After these: policies, taxonomy, weigher constants, resolver order, and all expectations FROZEN.
