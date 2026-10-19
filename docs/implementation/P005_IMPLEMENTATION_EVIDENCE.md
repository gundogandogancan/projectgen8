# P005 IMPLEMENTATION EVIDENCE

**Doc status:** `CANONICAL` · **Phase:** 5 · **Date:** 2026-10-18 · PROMPT 005 §37. No fabricated values.

## Build & test
- `swift test` → **137 tests, 0 failures** (macOS, Swift 6.3, headless). Prior 125 all green.
- iOS app `xcodebuild` (iPhone 17 Pro sim) → **BUILD SUCCEEDED**.
- Revalidation: PASS (`P005_PRIOR_EVIDENCE_REVALIDATION.md`).

## New target: `GuardianMedia` (AVFoundation — platform/media layer)
Core stays AVFoundation-free. New: `SyntheticVideo` (AVAssetWriter MP4 generator — OWNED fixtures), `MediaAssetSource` (async metadata), `VideoFrameProvider` (sparse AVAssetImageGenerator, ephemeral), `AudioProviderV1`, `SpeechTranscriptionAdapter`, `WholeVideoAnalyzerV1` (E2E orchestrator + cache).

## Real-media proof (headless)
- **Generated real MP4 → decoded sparse frames → real Vision OCR read "GUARDIAN" from a decoded frame** (`RealMediaDecodeTests`).
- **Scene change detected via feature-print on decoded frames.**
- **E2E analyzer** produced TemporalGraph V4 + ContentDNA V4 from real media; "EARTHQUAKE DISASTER" overlay → **4 flagged windows via real OCR→MDD** (`WholeVideoAnalyzerTests`, benchmark).

## §38 acceptance (all met)
1 prior pass ✅ · 2 AVFoundation ingestion ✅ · 3 sparse extraction ✅ · 4 decoded→OCR/visual ✅ · 5 scene detection ✅ · 6 audio provider ✅ · 7 transcription **real-adapter / explicitly UNAVAILABLE w/ verified reason** ✅ · 8 TR/EN speech truthfully documented ✅ · 9 WholeVideoAnalyzerV1 → TemporalGraph V4 ✅ · 10 ContentDNA V4 no raw media ✅ (test) · 11 short-form real pre-exposure ✅ (analyzer on short clip) · 12 long-form warn/ask/skip ✅ · 13 alternate-cut safe ✅ · 14 cache reuse avoids work ✅ · 15 cancellation no stale ✅ · 16 idle no loop ✅ · 17 memory/storage bounds ✅ (bounded caches + ephemeral) · 18 E2E benchmark runs ✅ · 19 metrics labeled LAB/PENDING ✅ · 20 device claims only if measured ✅ (none) · 21 no silent cloud ✅ · 22 no unneeded permissions ✅ · 23 no production-accuracy claim ✅.

## Memory / storage discipline (§22, §23)
Frames ephemeral (no array retains all frames; no full-video pixel-buffer cache). ContentDNA/TemporalGraph caches bounded (ContentDNAStore LRU; analyzer cache keyed by contentID.version). No full PCM copy. No transcript history in memory (transcription unavailable). Memory-pressure behavior defined in `DEVICE_NATIVE_RUNTIME_CONSTITUTION` + ResourceGovernor.

## Idle / cancellation (§21, §26)
Idle test: constructing analyzer does 0 work (no decode/OCR/semantic/timer/network). Cancellation: `VideoFrameProvider` + analyzer check `Task.isCancelled` between frames; cancelled Task returns `.cancelled` or completes safely (no crash, no stale success). AVAssetImageGenerator single-image call isn't mid-cancellable — stale results discarded between frames (documented).

## ContentDNA V4 / TemporalGraph V4
ContentDNA V4 adds mediaDuration + scene boundaries + OCR-derived text + representative hashes (derived) — NO raw frames/PCM (test: no `Data` fields). TemporalGraph V4 segments carry headTask + model versions + sampled/deepened + version anchors.

## Device
`PENDING_EXTERNAL_DEPENDENCY`; device-health gate = `LAB_NO_OBVIOUS_DEGRADATION` (NOT device-certified). `P005_DEVICE_EVIDENCE.md`.

## Known limitations
Transcription UNAVAILABLE in lab (no spoken fixture + unverified assets + no network). Audio = track-detection + window planning (no full PCM extraction yet). Fixtures are short synthetic clips (long-form device/manual). Scene detection is feature-print-diff (small-fixture caveat). No device energy/thermal (no Team). No production accuracy claim.

## Files changed
GuardianMedia (new target, 5 source). GuardianCore +2 (AudioWindowPlanner; ContentDNA V4 fields; TemporalGraph V4 fields from P004 reused). Tests +3 (RealMediaDecode, WholeVideoAnalyzer, RealMediaBenchmark). Package.swift (GuardianMedia target). Docs: 7 P005 docs + ml/evaluation artifact. No app/product-UI redesign.
