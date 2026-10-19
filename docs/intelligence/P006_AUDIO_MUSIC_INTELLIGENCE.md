# P006 — Audio & Music Intelligence

**Doc status:** `CANONICAL` · **Phase:** 6 · **Date:** 2026-10-18 · PROMPT 006 §8–§11, §28, §35. Music ≠ speech. No copyrighted lyric scraping. Raw audio ephemeral.

## General audio (§9) — REAL
`GeneralAudioHeadV1` uses **Apple Sound Analysis** (`SNAudioFileAnalyzer` + built-in `version1` classifier) — queries the ACTUAL classifier (no invented classes). Proven headless (de-risk test ran on generated audio). Outputs top classes + confidence + `coreML` provenance; empty → honest UNKNOWN.

## Music stack (§10)
- **M1 music/non-music:** `GeneralAudioHeadV1.isMusic` (Sound Analysis "music" class) — **REAL**.
- **M2 song identity (ShazamKit):** `ShazamIdentityAdapter` → **UNAVAILABLE in lab** (no entitlement/network; never faked; identity ≠ meaning).
- **M3 audio characteristics:** `AudioCharacteristicsV1` — real RMS loudness/peak from bounded PCM window (ephemeral) — **REAL**.
- **M4 lyrical/spoken semantics:** only when lawful transcript exists; **no lyric scraping**.
- **M5 personal music policy:** `PersonalMusicPolicy` (artist/source exclusions, stimulation preference) — preference, **not universal truth**.

## Speech (§8) — attempted, honest
`SpeechTranscriberV2` attempts real on-device `SFSpeechRecognizer` (requires authorization + `supportsOnDeviceRecognition`; `requiresOnDeviceRecognition = true` — **no network/cloud fallback**). In the headless lab → **UNAVAILABLE** (authorization not granted / assets unverified). Spoken fixtures generated via `AVSpeechSynthesizer` (OWNED). TR/EN verification deferred to device gate. No microphone permission for file analysis (§12).

## Audio/Music ContentDNA (§11)
`ContentDNAAudio` (reusable, non-personal): speechAvailable · soundEventTimeline · isMusic · musicIdentity (metadata, rights-tracked) · loudnessRMS · languageLocale · engineVersions. **No raw PCM; no copyrighted lyrics.**

## Audio resource budget (§28)
Coarse sound-class first; speech only when speech present/policy requires; music recognition only when useful; no repeated Shazam for same identity; no transcript when captions suffice; no full-hour transcription before exposure (sparse windows via `AudioWindowPlannerV1`).
