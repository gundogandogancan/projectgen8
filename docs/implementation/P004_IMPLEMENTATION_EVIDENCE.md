# P004 IMPLEMENTATION EVIDENCE

**Doc status:** `CANONICAL` · **Phase:** 4 · **Date:** 2026-10-18 · PROMPT 004 §34. No fabricated values.

## Build & test
- `swift test` → **125 tests, 0 failures** (macOS, Swift 6.3, headless). Prior 108 all green.
- iOS app `xcodebuild` (iPhone 17 Pro sim) → **BUILD SUCCEEDED** (GuardianLab debug shows whole-video sample stats).
- Prior-evidence revalidation: PASS.

## Whole-video engine (all deterministic, bounded, tested)
| Component | Type | Evidence |
|---|---|---|
| `WholeVideoSampler` | coarse-to-fine, mode-budgeted | 1h→16/32/64 samples (ECO/BAL/MAX), ≤100 cap; short-dense vs long-coarse |
| `SceneBoundaryDetectorV1` | feature-diff + min-gap | static→none, hard cut→boundary, flicker suppressed |
| `WholeVideoCoverage` / `WholeVideoConfidence` | non-binary coverage + separate confidence dims | score-eligibility gates tested (low coverage / conflict → no score) |
| `CoarseTemporalMapV1` | windows + coverage | flagged/unknown window queries |
| `DeepeningPlannerV1` | explicit versioned priority | high-risk deepened, calm early-exit, ECO≤MAX |
| `AnalysisAheadV2` | analyzed/coarse/deep/unknown leads | behind→strictHold/cautionUnknown (never stale-safe) |
| `TemporalFusionV2` | cross-window fusion | visual dominance, text disambiguation, conflict↓confidence, missing→UNKNOWN, repeated-risk |
| `PersonalProjectionLayer` | cheap personal decision over shared map | positive-exposure projection without re-analysis |

## H1 sensitive visual
Still **UNAVAILABLE** — evidence-backed blocker: no rights-clear validated on-device graphic-content model; dataset candidates flagged (child/graphic concerns) in `P003_DATASET_CANDIDATE_REGISTER.md`. Custom-training path documented; not run (no lawful graphic dataset). Honest, per §8.B.

## Training run (§10, §11)
**Real train→eval→export loop executed:** `mdd-linear-v1` (logistic regression over 6-d lexicon features), synthetic OWNED TR+EN data, deterministic split, per-language eval. Artifacts: `ml/training/runs/mdd-linear-v1.{model,manifest}.json`. Metrics LAB on a **tiny 4-sample test** (F1 1.0 vs baseline 0.667) → pipeline demonstration, **NOT production accuracy**. Status ACTIVE_LAB. Calibration UNAVAILABLE. Reproducible (same checksum).

## Model compression / export
Linear head is trivially small (6 weights+bias); Core ML export documented as trivial (linear model) but not run (negligible benefit at this size). No blind quantization.

## Model pack manifest
`ON_DEVICE_MODEL_PACK.yaml` (`gen8-lab v1`, ACTIVE_LAB) + `ModelPackManifest` type: checksum/rollback activation gate + checksum verify (corrupt→reject) tested.

## ContentDNA V3 / TemporalGraph V3
ContentDNA V3 adds coverage + scene boundaries + deepened windows + modelPackVersion + rightsState (Codable round-trip tested; no personal score stored). TemporalGraph V3: `TimedSignal` carries sceneID/sampled/deepened/modelVersions + headTask attribution; alternate-cut safety retained.

## Personal projection / reuse
`PersonalProjectionLayer` reuses shared non-personal map → cheap personal admission (deterministic, no head re-invocation). Reuse economics: avoided head invocations when ContentDNA hit (shared intelligence).

## Whole-video benchmark
`ml/evaluation/results/whole-video-benchmark.json` (18 rows, durations×modes). Sample counts bounded; coverage included; ECO≤BAL≤MAX deepening. Timing LAB-only; device metrics pending (`P002_REAL_DEVICE_GATE.md`).

## Calibration / eval
Per-task metrics only (no aggregate). Calibration UNAVAILABLE_INSUFFICIENT_DATA. Eval report: `P004_MODEL_EVAL_REPORT.md`.

## Failure modes
Tested/assured: missing modality→UNKNOWN, modality conflict→↓confidence, model checksum failure→reject, no rollback→no activation, insufficient coverage→no score, analysis-behind→hold/caution, long video→bounded, alternate-cut→refuse skip, stale ContentDNA→version invalidation.

## Privacy / rights / security
No dataset downloaded except OWNED synthetic; no private/child data; no raw-media persistence (ContentDNA stores summaries/hashes/boundaries only); no cloud; model never directly hides/blocks (deterministic fusion does); checksum/rollback supply-chain gate; no production activation.

## Known limitations
H1 + explicit-sexual UNAVAILABLE. Trained head is lexicon-feature (not embedding) + tiny synthetic data → not production accuracy. Calibration UNAVAILABLE. Device CPU/energy/thermal/UI = pending (no Team). No real video decode pipeline yet (frame descriptors are provided/synthetic). No production claim.

## Files changed
GuardianCore +7 (WholeVideo, TemporalFusionV2, PersonalProjection, ModelPack, LinearClassifier, TrainingRunner; ContentDNA V3 + TemporalGraph V3 ext). Tests +4 (WholeVideo, WholeVideoBenchmark, TrainingRun; fusion reuse). App GuardianLab V3 debug. Docs: 7 P004 docs + ON_DEVICE_MODEL_PACK.yaml + MODEL_REGISTRY update + ml/training artifacts + whole-video benchmark artifact.
