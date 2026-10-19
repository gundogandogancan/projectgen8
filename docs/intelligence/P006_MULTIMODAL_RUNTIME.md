# P006 — Universal Multimodal Runtime

**Doc status:** `CANONICAL` · **Phase:** 6 · **Date:** 2026-10-18 · PROMPT 006 §5,§6,§7,§16,§17,§18,§19,§20,§23,§24.

## Envelope & ports
`ContentObservationEnvelope` (platform-neutral) carries any subset of modalities; **missing modality = UNKNOWN, never negative evidence.** Perception ports (`StructuredTextObservationPort`, OCR/Caption/Speech/GeneralAudio/Music/Image/VideoTemporal/Metadata) declare support/permission/privacy/latency/cancellation/provenance/rights/cacheability. No Accessibility-API surveillance bypass; no claim of arbitrary iOS cross-app text extraction.

## Text first-class (§7)
Priority: structured/DOM/captions → subtitles → metadata → transcript → OCR. `TextSourceMerge` dedupes identical text (avoids re-analysis), preserves source+timestamp provenance, flags conflicts. Tested.

## Complexity + orchestration (§16,§17)
`ContentComplexityProfile` (micro/short/medium/long/veryLong/live + modality richness/uncertainty/policy sensitivity). `IntelligenceOrchestrator` schedules FAST vs DEEP vs skip — **NOT one giant LLM, no "run all heads"** (cached ⇒ run nothing; no-audio ⇒ no speech head). `ComputeBudgetPlanner` sets per-content budgets (cloud OFF default; thermal/low-power → ECO).

## Sub-second admission (§19)
`SubSecondAdmission`: cache short-circuit; else deterministic fusion fast path; **deep path non-blocking** (continues after first trustworthy admission). Real monotonic timing (no fake sleep). Fast-path p50 ~1.7µs LAB (fusion compute only; full media path measured in benchmarks).

## Next-content queue (§20,§21)
`NextContentCandidate` readiness states (discovered→identity→cache→fast→admission); `NextContentQueue` prioritizes (revealProb×risk ÷ time×cost), bounded ≤3, drops low-prob under pressure, dedupes. **No invented future content.**

## Disagreement (§23) & live (§24)
`MultimodalDisagreementCouncil`: visual-graphic dominance, text disambiguation, conflict↓confidence, missing→UNKNOWN. No averaging. `LiveContentMode` rolling states (rollingFast/rollingDeep/coverageLag/unknownAhead) — no future-frame claims.
