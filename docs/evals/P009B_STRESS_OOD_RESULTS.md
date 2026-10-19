# P009B — STRESS / OOD Results (seeds 2 and 3, run once after freeze)

**Harness:** `P009BExpertMeshTests.testStressOODCorpus` — failures=0 on both seeds.

## What the splits exercise

- **STRESS (seed 2, EN surface):** the full 17-scenario sweep again under different surface variants —
  confirms expectations are structural, not memorized strings.
- **OOD (seed 3, TR surface):** same, with the OOD family doing the heavy lifting:
  - `unsupported-language` (ja) → `UNSUPPORTED_LANGUAGE`, zero topic labels (abstention, no guessing)
  - `noisy-ocr` → low confidence + OOD flag, zero topic labels
  - `absent-audio` → explicit `UNAVAILABLE:no-audio-provider-input`
  - `all-unavailable` (empty input bundle) → every expert abstains; route reports
    `all-modalities-unavailable` → UNKNOWN (never a fabricated understanding)
  - `unsupported-audio-classes` → `audio:unsupported-classes:2` + `audio:no-validated-events`

## Additional stress beyond the corpus (unit level)

- `testBoundedRuntimeContainers`: 3000 publishes/records → bus ≤ 2048, ledger ≤ 4096 (bounded memory).
- `testStaleResultCannotCrossIdentity` + `testCancellationStopsWork`: generation churn and cancelled
  tokens under routing — no stale attachment, no post-cancel work.
- `testHandoffSanitization`: 7 malformed handoff variants (NaN/∞/negative/out-of-range/malformed-id/
  missing-version/stale-session) → all QUARANTINED, 1 valid accepted, never positive state.

failures=0, run-once discipline preserved.
