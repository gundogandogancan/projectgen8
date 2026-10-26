# MULTIMODAL_INVENTORY_R7 — Honest OCTOPUS Coverage + Next-Modality Recommendation

**Status tier: INVENTORY (code-grounded). Implementation of a new modality is NOT claimed in this round — the honest
inventory + a ranked recommendation IS the deliverable (mandate §7).**

## 0. The one fact that governs everything

The live cross-app path is the **ReplayKit broadcast extension** (`GuardianBroadcastExtension/SampleHandler.swift`).
It processes **VIDEO ONLY** — `processSampleBuffer(_:with:)` begins with `guard type == .video else { return }`. It
derives cheap per-frame signatures + event-gated on-device **Vision OCR** (`BroadcastOCRRunnerV1`). The world-model
bridge (`WorldModelEvidenceBridgeV1`) therefore declares **speech / audio-event / music / symbol / high-risk-visual**
as honest `ExpertEvidenceV2.unavailable` on this path — `soundEvents: []` is NEVER "audio analyzed clean".

So: **production multimodal coverage today = TEXT (OCR) + narrow personal VISUAL reference (luma signature match).**
Everything else is either lab-only (file-based) or UNAVAILABLE. This inventory maps each gap against three real
constraints: installed SDK, the ReplayKit extension lifecycle (RAM ~50 MB budget, thermal, audio-capture support),
and calibration/rights gates.

## 1. Per-modality inventory

| Modality | What EXISTS in the repo today | Live ReplayKit path | Blocked by | Marginal protection / cost |
|---|---|---|---|---|
| **Text (OCR)** | `BroadcastOCRRunnerV1` (Vision VNRecognizeText), `LanguageOCRExpertV1`, stance/register/targeted-pressure adapters | ✅ **LIVE** (event-gated, rate-limited, single-pass per R7 §4) | — | n/a (shipped) |
| **Personal visual reference** | `PhotoShieldLumaMatcherV1` (perceptual luma signature vs user references) | ✅ **LIVE** (per-item, thermal-gated) | — | narrow (user's own images only) |
| **Speech → text** | `SpeechTranscriberV2/V3` (SFSpeechRecognizer, on-device TR/EN) — **FILE-based** (`transcribeFile(url:)`), lab path only | ❌ UNAVAILABLE | Extension captures no audio buffer; `SFSpeechRecognizer` on a live RPSampleBuffer audio stream = unproven + RAM/thermal cost + TCC mic authorization semantics in a broadcast extension | HIGH value, HIGH cost/risk |
| **Audio events (SoundAnalysis)** | `GeneralAudioHeadV1` (real `SNClassifySoundRequest` v1) + `ReelsAudioEvidenceProviderV1` + `SoundRuleSafetyV1` — **FILE-based** (`SNAudioFileAnalyzer(url:)`), lab path | ❌ UNAVAILABLE | Same no-audio-capture gap; needs an `SNAudioStreamAnalyzer` fed from `type == .audioApp` buffers (extension currently drops them) | **HIGH value, MEDIUM cost** (classifier is built-in, streaming API exists) |
| **Music / emotional tone** | `MusicIntelligence.swift` (minimal), no real music-emotion classifier | ❌ UNAVAILABLE | No audited music-emotion model; calibration gate | LOW value now, HIGH cost |
| **General visual high-risk (H1)** | `HighRiskVisualSafetyRegistryV1` — ALL classes `UNAVAILABLE_EVIDENCE_BACKED`, provider NONE | ❌ UNAVAILABLE (by law) | No rights-clear audited dataset; H1 calibration gate is an explicit OPEN blocker | HIGH value, VERY HIGH cost (dataset + calibration) |
| **General object/entity** | Vision feature-print used for item identity (`Tier1ItemIdentityV1`), NOT semantic object labels | ❌ UNAVAILABLE as semantic understanding | No verified entity model (R7 §5 alias stays TEXT-only by design) | MEDIUM value, HIGH cost |
| **Narrative fusion** | `NarrativeTimelineV1`, `ContentWorldModelV1`, `ContradictionResolverV1` exist; progressive re-adjudication wired | PARTIAL (text-driven) | Richer fusion needs the above modalities first | derivative of inputs |

## 2. Ranked by marginal-protection-per-cost

1. **Audio-event analysis (SoundAnalysis streaming)** — BEST ratio. The classifier (`SNClassifySoundRequest`
   `.version1`) is already wrapped and proven in the repo; the only new work is (a) accepting `type == .audioApp`
   buffers in the extension and (b) swapping `SNAudioFileAnalyzer` → `SNAudioStreamAnalyzer`. It adds genuinely NEW
   signal (screaming, alarms, gunshots, distress sounds) that TEXT/OCR cannot see, and SoundAnalysis is a low-RAM,
   on-device, no-network classifier. Highest protection-per-cost.
2. **Speech → text (on-device SFSpeechRecognizer)** — HIGH value (spoken manipulation/threats OCR misses) but HIGHER
   cost/risk: continuous recognition on a live stream is RAM/thermal heavy and the mic-authorization story inside a
   ReplayKit *broadcast upload* extension is unproven — must be verified against current Apple docs on device.
3. **H1 visual high-risk** — HIGH value, VERY HIGH cost. Stays UNAVAILABLE until a rights-clear audited dataset +
   independent calibration exist. Do NOT bypass the H1 gate (constitution/mandate §7).
4. Music-emotion / general object-entity — deferred (low value-per-cost now).

## 3. RECOMMENDATION

**Next modality = AUDIO-EVENT ANALYSIS via SoundAnalysis streaming**, because:
- The real classifier + evidence-provider + sound-rule-safety path already EXIST in GuardianMedia (`GeneralAudioHeadV1`,
  `ReelsAudioEvidenceProviderV1`, `SoundRuleSafetyV1`) — it is reuse, not a new brain.
- It is the one gap where the **capture + SDK + evidence chain are all already present**; only the live-stream wiring
  (accept `audioApp` buffers → `SNAudioStreamAnalyzer` → the existing `AudioClassification` evidence → the bridge's
  currently-UNAVAILABLE `.audioEvent` slot) is missing.
- It respects the resource law: SoundAnalysis is on-device, low-RAM, and can be thermal-gated exactly like the photo
  shield (skip under serious/critical), so it fits the ~50 MB / thermal budget.

### Why it was NOT implemented this round (honest)

- Wiring live audio capture into the ReplayKit broadcast extension changes the capture contract (audio buffers, a new
  `SNAudioStreamAnalyzer` lifecycle, buffer backpressure) and its RAM/thermal cost is **DEVICE_UNVERIFIED** — it must
  be measured on a real device before it can claim "LIVE", per the dual-evidence rule. The R7 budget was spent on the
  P0 decision-integrity fixes (thermal child-safety, family revision, world-model→surface, single-pass) which are
  release-blocking. The narrowest honest audio slice is the explicit R8 candidate.
- The bridge already exposes the exact seam: `.audioEvent` is a declared-UNAVAILABLE record today; the audio slice
  replaces that one record with a real `SNClassifySoundRequest` streaming result (one-line contract change on the
  evidence side) once the capture + device measurement land.

## 4. Honest coverage statement (for the scorecard)

> GEN8 live cross-app coverage = **TEXT(OCR) + narrow personal VISUAL reference**. Speech, audio events, music,
> general high-risk visual, and general object/entity are **UNAVAILABLE** on the live path and declared so in the
> world model. The next real capability is audio-event analysis (SoundAnalysis streaming), recommended with the
> evidence above; it is NOT yet wired or device-measured.
