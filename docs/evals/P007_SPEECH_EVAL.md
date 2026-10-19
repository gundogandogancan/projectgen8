# P007 — Speech Eval (TR / EN V3)

Path: `SpeechTranscriberV3` (GuardianMedia) — on-device only (`requiresOnDeviceRecognition = true`), file analysis
(no microphone), **no cloud fallback**. Honest availability probe before any transcription.

## Availability probe (the verifiable truth)
`probe(localeID:)` reports `recognizerExists / isAvailable / supportsOnDevice / authorizationStatus / verdict`.
Verdict ∈ { `READY`, `BLOCKED_NO_RECOGNIZER_FOR_LOCALE`, `BLOCKED_NOT_AUTHORIZED`, `BLOCKED_NO_ON_DEVICE_ASSET`,
`BLOCKED_RECOGNIZER_UNAVAILABLE` }.

## Lab-host result (2026-10-18, macOS test runner)
The project-owned fixtures are synthesized (`AVSpeechSynthesizer.writeSpeech`) for EN and TR. On the headless CLI test
runner, `SFSpeechRecognizer` authorization is not granted and on-device assets are not provisioned, so the probe
returns a **BLOCKED_\*** verdict and `transcribe` abstains with `availability = .unavailable` — **no fabricated
transcript** (test `testSpeechV3FixtureTranscribeOrHonestBlocker` asserts exactly this branch). This is the acceptable
§7 outcome: "produce exact verified blocker."

| Fixture | Locale | Lab verdict | Transcript | WER | Notes |
|---------|--------|-------------|------------|-----|-------|
| EN neutral | en-US | BLOCKED_* (no auth/asset on CLI) | — | — | runs on a provisioned device |
| EN topic-sensitive | en-US | BLOCKED_* | — | — | |
| TR neutral | tr-TR | BLOCKED_* | — | — | |
| TR topic-sensitive | tr-TR | BLOCKED_* | — | — | |
| noisy variant | en-US | BLOCKED_* | — | — | degradation measurable only on device |
| code-switching | tr-TR/en | BLOCKED_* | — | — | behavior measurable only on device |

## What is proven vs pending
- **Proven (lab):** the real on-device path is wired, probes truthfully, abstains honestly, never uploads, never fakes.
- **PENDING_EXTERNAL_DEPENDENCY (device):** actual TR/EN transcripts, WER, timestamp accuracy, noisy degradation, and
  code-switching behavior require a provisioned device with authorization + on-device assets (signing team).
- Tiny synthesized fixtures could never be called production WER regardless (§8).
