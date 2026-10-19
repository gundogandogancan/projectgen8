# P009B — STRESS / OOD Results (R1: corpus V2, run once after freeze)

**Harness:** `P009BR1ClosureTests.testStressOODV2RunOnce` — `P009BR1_STRESS scenarios=10 failures=0`,
`P009BR1_OOD scenarios=8 failures=0`.

## R1 retraction of the original doc's false claims (F3)

1. ~~"different surface variants"~~ — FALSE for the V1 corpus: STRESS/OOD seeds were byte-identical to
   TUNE/HELD-OUT (audit-proven). The V2 banks are genuinely distinct instances (leakage auditor: 0 violations).
2. ~~"all-unavailable scenario → route reports `all-modalities-unavailable`"~~ — FALSE on the
   full-domain path: `SafetyEvidenceExpertV1` and `TemporalExpertV1` always emit available records
   (coverage 0 / status labels), so that reason can never fire when they are requested (probe-proven:
   `testEmptyInputAbstentionTruth`). The reason DOES fire when only provider-fed domains are requested.
   The V2 `t-ood-empty-bundle` expectation asserts explicit `UNAVAILABLE:` evidence instead — which is
   what actually happens.

## What STRESS (V2) exercises

Label flood (64 visual labels), 40×-repeated long text with a risk tail (contradiction required),
240 cuts/min + urgency lexicon stack, all-modalities-rich benign agreement, mixed risk+calm single text
(contradiction), repeat-hammer (cache-hit law), 8-step extreme montage, symbol flood ×10, whitespace-only
text, exact OOD-boundary confidence (0.15).

## What OOD (V2) exercises

Unsupported language (ja) — distinct from TUNE's (de) and HELD-OUT's (ar); malformed locale (`zz-!!` →
sanitizer → UNSUPPORTED abstention); NaN edit density (sanitizer drops; rapid-edit label forbidden);
negative elapsed; empty arrays (explicit no-visual UNAVAILABLE + `audio:no-validated-events`);
out-of-range confidence 7.5 (clamped); 100 labels (truncated to 64 — `bulk99` forbidden);
speech-declared-without-transcript (honest `speech:none-detected`).

## Unit-level stress beyond the corpus

Bounded containers (3000 inserts), generation churn + cancellation, 15-variant handoff quarantine
(AUDIT3), F1 lease retry-exhaustion storm test, deadline race with injectable clock, sanitizer property
sweep over a poisoned-value grid.

Run-once discipline: expectations frozen at TUNE; no policy/lexicon/threshold/expectation changed after.
