# P002 IMPLEMENTATION EVIDENCE

**Doc status:** `CANONICAL` · **Phase:** 2 · **Date:** 2026-10-18 · PROMPT 002 §30 / 002A. No fabricated values.

## Build & test (real)
- `swift test` → **83 tests, 0 failures** (macOS arm64, Swift 6.3, headless). Includes real CryptoKit / Vision / NaturalLanguage.
- iOS app `xcodebuild` (iPhone 17 Pro sim, Debug, CODE_SIGNING_ALLOWED=NO) → **BUILD SUCCEEDED** with `GuardianCore` + `GuardianIntelligence` linked.
- P001 revalidation: PASS (`P002_P001_EVIDENCE_REVALIDATION.md`).

## REAL_PROVIDER_MATRIX
| Head | Provider | Status | Provenance | Evidence |
|---|---|---|---|---|
| Identity (exact) | CryptoKit SHA-256 | **REAL** | CRYPTO_HASH | IdentityV1Tests |
| Identity (perceptual) | deterministic avg-hash | **REAL** | PERCEPTUAL_HASH | IdentityV1Tests |
| Identity (visual) | Vision feature print | **REAL** | APPLE_VISION | VisionProvidersTests, IdentityRobustnessTests |
| OCR / text | Vision VNRecognizeTextRequest | **REAL** | APPLE_VISION | VisionProvidersTests (read "GUARDIAN"), FastPreflightTests |
| Language | NaturalLanguage NLLanguageRecognizer | **REAL** (`REAL_LANGUAGE_SIGNAL` only) | APPLE_NATURAL_LANGUAGE | NLProviderTests (en+tr) |
| Semantic similarity | NaturalLanguage NLEmbedding (actor-isolated) | **REAL** (en avail) | APPLE_NATURAL_LANGUAGE | SemanticEmbeddingTests (+concurrency) |
| Topics | NaturalLanguage NLTagger (light) | REAL (advisory) | APPLE_NATURAL_LANGUAGE | NLProviderTests |
| sensitiveContent/violence/disease/manipulation/personalBenefit/childSafety | — none validated — | **UNAVAILABLE** (never fabricated) | unavailable | FastPreflightTests |

## Model candidates / licenses (§5/§17)
No external model downloaded. Apple framework engines registered in `MODEL_REGISTRY.yaml` (`apple_native_engines`); `external_model_candidates: []`.

## Content Identity V1 (§6) + robustness
Tier A SHA-256, Tier B perceptual avg-hash, Tier C transcript fingerprint; confidence-tiered. Empirical `IDENTITY_ROBUSTNESS_MATRIX` in `P002_IDENTITY_ROBUSTNESS_MATRIX.md` (byte-identical, PNG re-encode, perturbation → SAME; different → no false match; alt-cut → refused). Resolution/crop/scale/brightness NOT yet claimed.

## ContentDNA V1 (§7)
`ContentDNAV1` (Codable, versioned, invalidation on version mismatch, bounded `ContentDNAStore`); personal/global separation (no personal fields); `testNoRawMediaFieldsExist` proves no raw bytes stored.

## ModelRouter V1 (§8) / ResourceGovernor V1 (§9)
Deterministic router (cache-wins, identity-deterministic, thermal/low-power→cheap/abstain, no-local→abstain, privacy-restricted on-device). Governor degrades to ECO on thermal/low-power/memory; idle→no work. 11 RouterGovernorTests pass.

## FastPreflight V1 (§10)
`FastPreflightEngineV1` orchestrates identity→OCR→language→semantic→visual-feature, governor-gated deep heads, per-head provenance envelope, honest UNAVAILABLE. FastPreflightTests confirm real OCR+language and UNAVAILABLE classifiers.

## Training/dataset foundation (§11–14)
`ml/` workspace: `schemas/{sample,label,rights-provenance,dataset-manifest}.schema.json` (5-plane label firewall), `datasets/golden-v0/manifest.json` (synthetic/metadata, no copyrighted/private/child data), `P002_HUMAN_LABELING_PROTOCOL.md`.

## Eval harness V1 (§15)
`EvalHarness` runs golden-v0 → per-task metrics (identity/language/ocr), abstentions separate, no aggregate "AI accuracy"; artifact `ml/evaluation/results/latest.json` (identity 2/2, language 2/2, ocr 2/2 on golden-v0). EvalHarnessTests pass.

## Calibration V0 (§16)
`CALIBRATION_STATUS = UNAVAILABLE_INSUFFICIENT_DATA` (`P002_CALIBRATION_V0.md`) — no fake curve; raw-vs-calibrated separation + abstention threshold contract + schema defined.

## Temporal V1 (§19) / Analysis-Ahead V1 (§20)
`TemporalExtractorV1` coarse sample planning + refine hooks + provider-attributed segments. Scheduler V1 deadline-aware + governor depth override; SchedulerV1StressTests (rapid-swipe bounded≤3, deadline priority, no duplicate analysis, ECO shrink).

## LAB_PRE_EXPOSURE_METRICS (§21)
`PreExposureMetrics` / `ExposureRecord` with discovered/analysis/decision/reveal timestamps, lead time, decisionBeforeReveal, route, mode, unknownReason, engine versions; `PRE_EXPOSURE_COVERAGE_RATE` computed (test: 2/3), label `LAB_MEASURED`. Not a production SLO.

## Device health / Instruments (§22)
`GuardianSignposter` (OSSignposter) stage names (identity/cache/ocr/language/semantic/visualFeature/preflightFusion/admission/scheduler/temporal/uiUpdate). Measurement protocol: `P001_DEVICE_MEASUREMENT_PROTOCOL.md`. No invented energy numbers.

## REAL_DEVICE_GATE (§23)
`PENDING_EXTERNAL_DEPENDENCY` (no Team) — `P002_REAL_DEVICE_GATE.md`. No battery/thermal/latency/Dynamic-Island certification. Lab/sim values labelled.

## SKILL_ALLOWLIST_STATUS (§5)
Supply chain **frozen**; `CLAUDE_SKILL_ALLOWLIST.md`. 82 skills installed user-global (hooks stripped); default DISABLED; minimal advisory set allowlisted; no skill executed code/mutated repo/accessed secrets/network during P002.

## Privacy / security (§26/§27)
Raw media ephemeral; ContentDNA stores no raw bytes (test); local-only; zero network on fixture path; no secrets; Apple engines on-device. No unsigned/unregistered model active.

## GuardianLab debug UI (§18)
Internal diagnostics disclosure gains a "Real preflight (debug)" section showing route/mode/identity/language/OCR + per-head REAL/UNAVAILABLE/UNKNOWN. Normal Pure Bar unchanged/minimal.

## Known limitations
No validated content-safety/benefit classifier (heads UNAVAILABLE); embeddings English-verified (Turkish sentence embedding availability runtime-dependent); identity robustness limited to tested transforms; latency/energy sim-only (device gate pending); Swift 5 mode / iOS target unchanged (ADRs pending); Dynamic Island RCOV.

## Files changed
GuardianCore +7 (Ports, ModelRouter, ResourceGovernor, ContentDNA, PreExposureMetrics, TemporalExtractionV1, Signposts; ContentTypes provenance). GuardianIntelligence target +7 (ContentIdentityResolverV1, NLTextSignalProvider, VisionProviders, SemanticEmbeddingProvider, SyntheticImage, FastPreflightEngineV1, EvalHarness). Tests +8. App: GuardianLabModel/View debug + pbxproj wires GuardianIntelligence. Docs: ADR-0012, Apple-native capability report, skill allowlist, device gate, identity robustness matrix, calibration, human-labeling protocol, P001 revalidation, this doc. `ml/` workspace + schemas + golden-v0 + eval artifact.
