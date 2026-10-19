# P005 — Apple Media & Speech Capability Report

**Doc status:** `PARTIAL — VERIFIED(compile/headless) + RCOV(device/docs)` · **Phase:** 5 · **Date:** 2026-10-18 · PROMPT 005 §2.
"VERIFIED(headless)" = compiles & runs on this macOS (Swift 6.3) in `swift test`. Device behavior/locale/current-doc specifics remain **RCOV** (Prompt 000 §54). No invented features. Current async APIs used; no deprecated sync paths.

| API | Status | Min OS (RCOV) | Privacy | Network | Permission | Cancellation | Notes |
|---|---|---|---|---|---|---|---|
| `AVURLAsset.load(.duration/.tracks)` (async) | **VERIFIED(headless)** | iOS16/macOS13 | local | none | none | Task.isCancelled checked | used in MediaAssetSource |
| `AVAssetTrack.load(.naturalSize/.nominalFrameRate)` | **VERIFIED(headless)** | iOS16+ | local | none | none | — | metadata |
| `AVAssetImageGenerator.image(at:)` (async) | **VERIFIED(headless)** | iOS16/macOS13 | local, ephemeral | none | none | per-call; discard between frames | sparse frame extraction |
| `AVAssetWriter` (+pixel-buffer adaptor) | **VERIFIED(headless)** | iOS/macOS | local | none | none | — | generates OWNED synthetic fixtures |
| `AVAssetReader` (audio) | RCOV | iOS16+ | local | none | none | yes | audio track reader (windowed; full PCM not copied) |
| Vision `VNRecognizeTextRequest` | **VERIFIED(headless over decoded frames)** | long-avail; revised iOS18 | local | none | none | request-level | OCR on decoded frames |
| Vision `VNGenerateImageFeaturePrintRequest` | **VERIFIED(headless)** | iOS13+ | local | none | none | — | scene similarity/boundaries |
| `SpeechAnalyzer` / `SpeechTranscriber` | **RCOV / not verified in lab** | iOS26/macOS26 (RCOV) | local on-device (RCOV) | **must not fallback to cloud** | speech-recognition (RCOV) | RCOV | see Speech Support Matrix — lab UNAVAILABLE |
| `SFSpeechRecognizer` (older) | RCOV | iOS13+ | on-device subset | avoid network | speech-recognition | yes | fallback behind availability only; no silent cloud |
| `ProcessInfo.thermalState / isLowPowerModeEnabled` | **VERIFIED** | long-avail | local | none | none | — | ResourceGovernor |

## Decisions
- **Media decode path is VERIFIED headless** (generate → load → sparse decode → OCR/feature-print). This is the P005 moat and it works.
- **Transcription is UNAVAILABLE in the headless lab** (no spoken-audio fixture; on-device locale asset installability unverified without network; network fallback forbidden). Implemented as a production-shaped adapter returning UNAVAILABLE — never faked, never silent cloud. See `P005_SPEECH_SUPPORT_MATRIX.md`.
- **No microphone permission** requested for local-file analysis (§12). Any future speech permission needs exact reason + user-visible explanation + denied-fallback.
- All device-level timing/energy remains RCOV (no Team/device) — see `P005_DEVICE_EVIDENCE.md`.
