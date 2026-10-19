# P005 — Speech Support Matrix (TR / EN)

**Doc status:** `RCOV` · **Phase:** 5 · **Date:** 2026-10-18 · PROMPT 005 §32. **No silent fallback to cloud.** Lab = headless macOS (no spoken-audio fixture, no verified locale assets, network forbidden).

| Aspect | English (en) | Turkish (tr) |
|---|---|---|
| Supported locale (platform) | RCOV (likely yes) | RCOV (likely yes) |
| On-device transcription | RCOV | RCOV |
| Installed asset in lab | **NO (unverified)** | **NO (unverified)** |
| Downloadable asset | RCOV — must be **explicit**, never during Guardian analysis | RCOV — explicit |
| Requires permission | speech-recognition (RCOV) — **not** requested for local-file analysis in P005 | same |
| Requires network | **must be NO** (local-first; cloud fallback forbidden) | same |
| Runtime availability (lab) | **UNAVAILABLE** (no spoken fixture; assets unverified) | **UNAVAILABLE** |
| Fallback | abstain → UNKNOWN (never cloud, never faked) | abstain → UNKNOWN |
| Minimum OS | RCOV (SpeechAnalyzer iOS26 / SFSpeechRecognizer iOS13) | RCOV |

## Status
`SpeechTranscriptionAdapter` returns `UNAVAILABLE` in the lab (honest). Real TR/EN transcription verification requires: a device, installed/verified locale assets, and a spoken-audio fixture — deferred to the device gate. No audio is sent to any network service.
