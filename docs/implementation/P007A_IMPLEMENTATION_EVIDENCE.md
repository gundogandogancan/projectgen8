# P007A — Implementation Evidence

**Scope:** R1/Lab evidence-integrity closeout. Two gates closed: (1) a REAL measured pipeline benchmark (no modeled
media), (2) a REAL WidgetKit Control + Live Activity extension target that compiles. **No signing/bundle/Team/App-Group
change, no device install.** Verify: `swift test` → **215/215**; app + extension builds → **BUILD SUCCEEDED**.

## 1. Benchmark evidence-class correction (§1,§2)
- The P007 full-pipeline benchmark is relabelled **MODELED_PROJECTION** (`P007FullPipelineBenchmarkTests`, tags
  `P007_MODELED_*`); it proves the *first-trustworthy-excludes-deep* invariant only, not real latency.
- New **LAB_MEASURED_REAL_PIPELINE**: `GuardianMediaTests/P007ARealPipelineBenchmarkTests` executes every included stage
  for real (Vision OCR, AVAssetWriter MP4 + AVAssetImageGenerator frames, SoundAnalysis, on-device Speech adapter, Shield
  index/eval, `ScoreAdmissionFusionV1`). Structured §3 fields per sample; evidence_class per route. Doc:
  `docs/evals/P007A_REAL_PIPELINE_ADMISSION_BENCHMARK.md`.
- Truth surfaced: **real Vision OCR ≈ 218 ms** (vs P007's modeled 120 µs). Deterministic routes genuinely < 1 ms.
  Speech really returns `BLOCKED_NOT_AUTHORIZED` (partial pipeline, no modeled duration). Cache route ran no media work;
  video/image routes really invoked provider work; cancellation left no stale current result (all asserted).

## 2. Real Control / Live Activity extension (§7–§12)
- Added Xcode target **`GuardianControlExtension`** (`com.apple.product-type.app-extension`), product
  `GuardianControlExtension.appex`, embedded in the app via an Embed-Extensions phase + dependency.
- Real source: `@main WidgetBundle`, `ControlWidget` + `ControlWidgetToggle` + `SetValueIntent` (AppIntents),
  `ActivityConfiguration` + Dynamic Island regions (compact/minimal/expanded/lock-screen), shared activation bridge,
  availability guards, minimal privacy-safe labels, UNKNOWN fallback.
- Compile-proven (simulator, CODE_SIGNING_ALLOWED=NO): extension target **BUILD SUCCEEDED**; whole scheme **BUILD
  SUCCEEDED**. Status `COMPILED_NOT_DEVICE_VERIFIED`. Doc: `docs/platform/ios/P007A_CONTROL_EXTENSION_COMPILE_EVIDENCE.md`.

## 3. Dynamic Island state safety (§13)
Content-identity + monotonic-sequence ordering, stale→UNKNOWN, Guardian-OFF→neutral are enforced by the headless-tested
`GlyphSurfaceController` / `LiveActivityUpdatePolicy` (GuardianCore, P006C/P007). The extension's views consume the
minimal surface state; no old positive/safe glyph can survive a content change in app-owned state.

## 4. Signing non-mutation (§14)
No `DEVELOPMENT_TEAM` set; app bundle id `com.aymedo.Gen8` unchanged; no App Group registered; no portal action; no
device install. The extension's placeholder bundle id `com.aymedo.Gen8.GuardianControl` exists only to let the target
compile and is documented PROPOSED. R2 values collected in `docs/platform/ios/P007A_R2_SIGNING_HANDOFF.md`.

## 5. Release readiness (§17)
Remains **R1** (real app+extension build, all tests, real local-media E2E benchmark, measured vs modeled cleanly
separated, no device claim). R2 = physical signed-device proof, user-approved.

## 6. Files changed
New: `GuardianControlExtension/{GuardianControlBundle,GuardianControlWidget,GuardianLiveActivityWidget,GuardianControlState}.swift`,
`GuardianControlExtension/Info.plist`; `Tests/GuardianMediaTests/P007ARealPipelineBenchmarkTests.swift`; 5 docs.
Changed: `Gen8.xcodeproj/project.pbxproj` (added the extension target, embed, config), `P007FullPipelineBenchmarkTests.swift`
(relabelled MODELED_PROJECTION), `PRE_EXPOSURE_SLO.yaml` (per-route real evidence).

## 7. Known limitations
Real device latency, live Control Center / Dynamic Island rendering, on-device speech transcripts, multi-run p95/p99,
and unified ActivityAttributes are all PENDING R2 (signing). No production claim.
