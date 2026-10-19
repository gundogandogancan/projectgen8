# P009C — Rights-Clear Semantic Corpus (`P009CCorpusV1`)

**Seedless split-authored banks** (R1 F2 law carried): TUNE: 21 · HELD_OUT: 10 · STRESS: 4 · OOD: 4.
`P009CLeakageAuditorV1` (same declared rule: token Jaccard > 0.8 + same modality combo) runs in the
suite → **0 violations**. The P009B CALIBRATION_RESERVED bank stays untouched (fingerprint re-checked by
the standing AUDIT4 probe) — P009C defines no calibration split of its own and uses none.

## §23 required families — coverage

straightforward-educational (tc/hc) · educational+sensitive (tc/hc) · humor (tc) · sarcasm (tc) ·
quoted harmful (tc/hc) · literal harmful (tc) · persuasive ad (tc) · manipulative urgency (tc/hc) ·
calm nature (tc/hc) · music-only (tc) · sensitive news/event (tc) · montage (tc, stress) · B-roll (tc) ·
repeated scene (tc b-roll return) · topic shift (tc/stress) · multi-topic (tc montage) · benign→risky
(tc/hc) · risky→benign (tc/hc/stress long-tail) · multimodal contradiction (tc/hc) · entity conflict (tc) ·
intent ambiguity (tc/hc) · unsupported language (tc ja / hc ar / ood de) · OOD-noisy (tc/ood poisoned/empty/audio-unknown).

Scenarios are multi-SEGMENT (temporal scripts feed the real TemporalExpertV1); the harness routes each
segment through the live mesh (`cacheEligible=false` — shot-moment law) and feeds `WorldModelBuilderV1`.

## Rights + honesty limits

100% project-authored derived-input bundles; provenance = the source file; registered in the asset
ledger. Validates SEMANTIC structure/honesty — NOT real-world accuracy; no exact P/R claimed. TUNE-phase
fixes (all correctness/honesty, no tuning-to-fit): segment cache-bleed fix (`cacheEligible`), per-shot
deep-lease scope, current-vs-historical risk split, readiness-requires-semantics, one annotation
authoring correction (benign→risky is escalation, not a same-moment contradiction — documented inline).
