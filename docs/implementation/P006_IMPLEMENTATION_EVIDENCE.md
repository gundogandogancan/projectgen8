# P006 IMPLEMENTATION EVIDENCE

**Doc status:** `CANONICAL` · **Phase:** 6 · **Date:** 2026-10-18 · PROMPT 006 §47. No fabricated values.

## Build & test
- `swift test` → **154 tests, 0 failures** (macOS, Swift 6.3, headless). Prior 137 green.
- iOS app `xcodebuild` (iPhone 17 Pro sim) → **BUILD SUCCEEDED** (in-app Guardian toggle wired).

## New runtime (GuardianCore, pure, tested)
GuardianActivationController (single source of truth; OFF cancels; relaunch-safe; no false Protected) · ContentObservationEnvelope + perception ports · TextSourceMerge (structured>OCR, dedupe, conflict) · ContentComplexityProfile · IntelligenceOrchestrator (FAST/DEEP/skip; cached→nothing; not-all-heads) · ComputeBudgetPlanner (cloud OFF; thermal→ECO) · SubSecondAdmission (cache short-circuit; deep non-blocking; real timing) · NextContentQueue (bounded, drop low-prob, dedupe) · MultimodalDisagreementCouncil · LiveContentMode · LanguageCapabilityRegistry (no threshold inheritance) · AudioWindowPlanner.

## New media (GuardianMedia, real Apple frameworks)
GeneralAudioHeadV1 (**real Apple Sound Analysis**, de-risked headless) · MusicIntelligence (M1 music/non-music real; M3 loudness real PCM RMS; M2 Shazam UNAVAILABLE honest; M5 personal policy) · SpeechTranscriberV2 (**attempts real on-device SFSpeechRecognizer, local-first, no cloud** → UNAVAILABLE in lab, honest) + SyntheticAudio (OWNED tone + synthesized-speech fixtures).

## §46 acceptance (all met)
1 prior pass ✅ · 2 Control Center capability verified (doc, RCOV) ✅ · 3 toggle compiles where permitted (in-app toggle real; Control extension device-gated, documented) ✅ · 4 GuardianActivationState single-source-of-truth ✅ · 5 universal envelope ✅ · 6 text first-class beyond OCR ✅ · 7 TR/EN speech real-attempt / evidence-backed UNAVAILABLE ✅ · 8 general audio real (Sound Analysis) ✅ · 9 music arch + music/non-music real ✅ · 10 no lyric scraping ✅ · 11 LanguageCapabilityRegistry ✅ · 12 adaptive orchestrator ✅ · 13 compute budget ✅ · 14 next-content ready states ✅ · 15 sub-second benchmark runs ✅ · 16 deep non-blocking ✅ · 17 bounded resource routing ✅ · 18 catastrophe matrix ✅ · 19 FMEA/chaos plan ✅ · 20 never silent safe ✅ · 21 GuardianLab V4 multimodal (debug routes + toggle) ✅ · 22 no runtime MCP dependency ✅ · 23 no new unapproved skill install ✅ · 24 no fake "all languages" ✅ · 25 no fake "zero battery" ✅ · 26 no production SLO without device ✅.

## Benchmarks (LAB)
Sub-second: fast-path fusion p50 ~1.7µs, cache ~0µs (<1s; fusion compute only, not full media). Long-content: 60s→18 samples, 3600s→32 (sublinear). Real-media E2E (P005): ~192–218 ms/short clip. Artifacts in `ml/evaluation/results/`.

## ContentDNA / TemporalGraph
ContentDNA V4 extended with `audio: ContentDNAAudio` (speech/soundEvents/isMusic/musicIdentity-metadata/loudness/locale) — **no raw PCM, no lyrics** (Codable; structural no-`Data` test). TemporalGraph V4 unchanged (provider/version attribution retained).

## Device
Device gate remains `PENDING_EXTERNAL_DEPENDENCY`; device-health `LAB_NO_OBVIOUS_DEGRADATION` (not certified). No fabricated energy/thermal/CPU.

## Known limitations
Control Center WidgetKit extension not compiled (no Team / iOS-18 baseline ADR pending) — in-app toggle is the real fallback. Speech transcription UNAVAILABLE in lab (device + assets + authorization needed). Shazam UNAVAILABLE (entitlement/network). Only EN+TR LAB_SUPPORTED (not CERTIFIED). Sub-second numbers are fusion-compute LAB, not device SLO. No production/accuracy claim.

## Files changed
GuardianCore +6 (GuardianActivationState, MultimodalRuntime, Orchestration, LanguageRegistry, AudioWindowPlanner + ContentDNAAudio). GuardianMedia +4 (SyntheticAudio, GeneralAudioHeadV1, MusicIntelligence, SpeechTranscriberV2). Tests +4. App (Guardian toggle). Docs: 10 P006 docs + AGENT_REGISTRY runtime manifest + resilience dir.
