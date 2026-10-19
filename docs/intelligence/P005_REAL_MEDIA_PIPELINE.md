# P005 — Real Media Pipeline

**Doc status:** `CANONICAL` · **Phase:** 5 · **Date:** 2026-10-18 · PROMPT 005 §14–§17. AVFoundation lives in `GuardianMedia` (platform layer); `GuardianCore` stays AVFoundation-free.

## WholeVideoAnalyzerV1 (orchestrator, actor)
```
ASSET LOAD → IDENTITY(contentID+version) → CACHE? (ContentDNA/TemporalGraph reuse)
→ METADATA (async AVURLAsset.load) → SAMPLE PLAN (WholeVideoSampler, bounded)
→ REAL SPARSE DECODE (VideoFrameProvider / AVAssetImageGenerator, ephemeral)
→ SCENE SIGNALS (Vision feature-print distance) → OCR (Vision over decoded frames)
→ LANGUAGE (NaturalLanguage) → SPECIALIST HEADS (MDD/attention over OCR text)
→ TimedSignals → TemporalGraph V4 → COVERAGE → ContentDNA V4 → cache store
```
Every stage: cancellable (Task.isCancelled between frames), signposted (`GuardianSignposter`), traceable, bounded. **No full-FPS loop.** Audio: `AudioProviderV1` detects track; `AudioWindowPlannerV1` plans coarse/refine/skip windows (short dense / long sparse / cache wins). Transcription: `SpeechTranscriptionAdapter` → UNAVAILABLE in lab (honest; no silent cloud).

## TemporalGraph V4 (from real media)
Segments carry real start/end + headTask attribution + categories + confidence + sampled/deepened + modelVersions (`[VNRecognizeTextRequest, mdd-head-v1]`). Alternate-cut/version anchors retained (wrong version → skip refused, tested).

## ContentDNA V4 (reusable, non-personal)
Stores: media duration, scene boundaries, OCR-derived text, coverage, model-pack version, rights state, derived summaries. **Never** raw frames/PCM/screenshots or personal final score (structural test: no `Data` fields).

## Reuse & invalidation
Cache keyed by `contentID.version`. Second pass → reuse (0 re-decode; tested). Alternate cut (version change) → not reused (tested). Personal policy change does NOT trigger heavy reanalysis (personal projection layer applies policy over shared map).

## Privacy / local-first
Local fixtures only; no network on the analysis path; frames/audio ephemeral; no transcript auto-added to training.
