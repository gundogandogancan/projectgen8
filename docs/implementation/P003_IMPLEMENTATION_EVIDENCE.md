# P003 IMPLEMENTATION EVIDENCE

**Doc status:** `CANONICAL` · **Phase:** 3 · **Date:** 2026-10-18 · PROMPT 003 §34. No fabricated values.

## Build & test
- `swift test` → **108 tests, 0 failures** (macOS, Swift 6.3, headless). Prior 83 all still green.
- iOS app `xcodebuild` (iPhone 17 Pro sim) → **BUILD SUCCEEDED** (GuardianLab debug now shows specialist signals).
- P001/P002 revalidation: PASS (`P002_P001_EVIDENCE_REVALIDATION.md` + re-run).

## Real specialist heads (beyond language/OCR/feature-print)
| Head | Engine | Provenance | Langs | Calibration | Status |
|---|---|---|---|---|---|
| Mortality/Disease/Disaster (H2) | lexicon-v1 | LEXICON_V1 | TR+EN | UNAVAILABLE | ACTIVE_LAB |
| Semantic Shield (H3) | NLEmbedding + exact/alias | EMBEDDING_CLASSIFIER_V1 | TR+EN | UNAVAILABLE | ACTIVE_LAB |
| Topic/Message (H4) | NLTagger + intent | APPLE_NATURAL_LANGUAGE | TR+EN | heuristic | ACTIVE_LAB |
| Attention/Manipulation (H5) | lexicon-v1 | LEXICON_V1 | TR+EN | count-based | ACTIVE_LAB |
| Personal Benefit vector (H7) | rules-v1 | RULES_V1 | TR+EN | n/a | ACTIVE_LAB |
| Sensitive Visual (H1) | — none rights-clear — | unavailable | — | — | **UNAVAILABLE** (no improvising) |

≥2 real heads beyond language/OCR/feature-print → satisfied (H2, H3, H4, H5). H1 + explicit-sexual = honest UNAVAILABLE.

## Fusion / explanation
`ScoreAdmissionFusionV1` (deterministic, `fusion-v1`): coverage gate → child floor → hard shield → positive exposure → manipulation → benefit threshold. No averaging. No numeric score below coverage threshold. `ExplanationEngineV1` emits reason codes (`TOPIC_EXCLUDED`, `POSITIVE_EXPOSURE_DISEASE`, `CHILD_POLICY_BLOCK`, …). Truth/Evidence separate from exposure policy (test-proven).

## ContentDNA V2 / TemporalGraph V2
ContentDNA V2 adds reusable non-personal `DNAHeadSignal[]` (headId/version/label/calibratedConfidence/provenance/freshness/rights) — personal fields excluded (test); Codable round-trip. TemporalGraph V2: `TimedSignal.headTask` attributes WHICH head produced each timestamped signal; version/alignment safety retained (wrong-version still refused).

## Calibration
All probabilistic heads: `calibratedConfidence = nil` ⇒ `UNAVAILABLE_INSUFFICIENT_DATA` (`P002_CALIBRATION_V0.md`). No fabricated curve. No pooled calibration across tasks.

## Eval / adversarial
`EvalHarness` per-task metrics artifact (`ml/evaluation/results/latest.json`); `AdversarialEvalTests` (neutral-medical, clickbait, TR disaster, alias, empty-abstain). False-hide/allow tracked; abstentions not counted as positives. Pending media-dependent adversarial cases explicitly not claimed.

## TR + EN
H2/H3/H4/H5 declare TR+EN; TR tests pass (deprem/kanser/Rakip Takım); EN thresholds not applied to TR (per-language lexicons/embedding language).

## Resource / deadline
Heads declare resource class (TINY/LIGHT) in `MODEL_REGISTRY.yaml`; ResourceGovernor + ModelRouter + deadline-aware scheduler from P002 govern selection (ECO shrinks look-ahead; thermal degrades). Idle = no work (tests).

## GuardianLab V2
Debug diagnostics now run FastPreflight + MDD + manipulation heads and display route/mode/identity/language/OCR + per-head REAL/UNAVAILABLE + specialist labels. Normal Pure Bar unchanged/minimal.

## Privacy / rights / security
No dataset downloaded; real heads use only ours (synthetic + lexicons). No private/child data. No raw media persisted (ContentDNA V2 stores labels/hashes only). No cloud dependency. Model output never directly hides/blocks/skips — deterministic fusion does. No unsigned model active. trailofbits skills remain personal-only (CC-BY-SA).

## Known limitations
H1 sensitive-visual + explicit-sexual = UNAVAILABLE (no rights-clear model). Lexicon/rules heads are precision-limited (not trained models) — labelled, not called "AI". Calibration UNAVAILABLE (tiny data). Turkish embedding availability runtime-dependent. Latency/energy sim-only (device gate PENDING). No production claim.

## Files changed
GuardianCore +5 (SpecialistSignals, Lexicons, FusionV1, PersonalBenefitEstimatorV1; ContentDNA V2 + TemporalGraph V2 + SensitiveCategory/SignalProvenance ext). GuardianIntelligence +2 (SpecialistHeads, SemanticShieldV1). Tests +3 (FusionV1, SpecialistHeads, AdversarialEval). App: GuardianLab debug specialist signals. Docs: P003 taxonomy/dataset/model/fusion/distillation/golden-v1/adversarial + this + MODEL_REGISTRY update.
