# AUDIO_TRUTH_R9 — Real Audio Inference Correctness (the fake-AVAILABLE kill) + capability honesty

**Status tier: SYNTHETIC-TESTED (host-run) for the ladder/completion/timebase/queue; the on-device AVAILABLE path is
DEVICE_UNVERIFIED. This is a CORRECTNESS fix, not an accuracy claim.**

## 1. The R8 P0 defect (confirmed at HEAD 30df71f)

`GuardianBroadcastExtension/SampleHandler.swift → analyzeAudioWindowForItem()` set
`LiveAudioWindowEvidenceV1(availability: .available, events: [])` the instant a window's worth of buffers drained —
**without the SoundAnalysis classifier ever running**. `LiveAudioStreamSessionV1` existed but was never called from the
production path. A buffer arriving was being treated as "audio analyzed clean". That is a FAKE AVAILABLE and it fed the
world-model bridge + coverage UI as if the audio sense had run.

## 2. The fix (R9)

- **Honest ladder** (`LiveAudioAnalysisLadderV1.swift`): `AUDIO_BUFFER_RECEIVED → PCM_CONVERSION_SUCCEEDED →
  CLASSIFIER_INITIALIZED → CLASSIFIER_WINDOW_SUBMITTED → CLASSIFIER_RESULT_RECEIVED | ANALYSIS_COMPLETED_NO_EVENT` plus
  the honest non-analysis terminals (`ANALYSIS_FAILED / RESOURCE_DEFERRED / FORMAT_UNSUPPORTED / CAPTURE_UNAVAILABLE /
  DEVICE_UNVERIFIED`). `availability == .available` is reachable ONLY from the two real completion terminals.
- **Window-completion contract** (`LiveAudioWindowCompletionContractV1`): SUBMITTED ≠ RESULT_RECEIVED ≠ WINDOW_COMPLETE.
  A submitted-but-un-completed window is PENDING (UNAVAILABLE); a completion observed only after a REAL submission can
  become the verified `ANALYSIS_COMPLETED_NO_EVENT`; a timeout turns a stuck window into `ANALYSIS_FAILED`, never clean.
- **Real PCM path** (`LiveAudioPCMExtractorV1` + `LiveAudioStreamSessionV1.analyzeWindow`): a minimal short-lived
  AVAudioPCMBuffer COPY is extracted on the ReplayKit callback (owns its memory → safe after the callback returns); the
  heavy `SNAudioStreamAnalyzer` drive runs on a dedicated OFF-callback worker through `analyze → completeAnalysis` with
  the completion contract. The extension now CALLS this on the real production path.
- **Timebase** (`AudioFrameToPTSMapV1`): the analyzer frame domain is mapped to absolute ReplayKit PTS anchored to the
  REAL first-buffer PTS of the window; unmappable → UNBOUND (never a fabricated absolute stamp).
- **Bounded queue by bytes + duration** (`BoundedAudioQueueV1`): overflow drops oldest and counts the loss by item
  count OR byte budget (≈512KB) OR duration budget (≈4s).
- **Coverage honesty** (heartbeat `audioLadderStateRaw` + `LiveGuardianInsightView` "Ses analizi" row): the user sees
  the honest ladder state ("ses: analiz edildi / edilmedi / ertelendi / doğrulanmadı"); the OK dot is green only on a
  real classifier completion — never merely because the broadcast is live.

The mandated regression is pinned: **buffer received + analyzer never invoked → available MUST be false**
(`LiveAudioInferenceR9Tests.testBufferReceivedButAnalyzerNeverInvokedIsNotAvailable`). The synthetic end-to-end
(`testSyntheticPCMDrivesRealClassifierEndToEndOrReportsUnavailableOnHost`) drives OWNED synthetic PCM through the REAL
`SNAudioStreamAnalyzer` and asserts on the MECHANISM (a real completion flowed via the honest ladder) — it passed
on-host (SoundAnalysis genuinely completed a window on macOS), and reports `CLASSIFIER_UNAVAILABLE_ON_HOST` honestly
(XCTSkip) on a host that cannot run it — never a fake pass.

## 3. R7 adversarial set — FORMALLY REGRESSION-ONLY (mandate §7)

The R7 24-sentence adversarial set (`AdversarialPressureEvalR7Tests.swift`, `ADVERSARIAL_PRESSURE_R7.md`) is **hereby
formally marked REGRESSION-ONLY.** It is engineering-authored self-probing, not independent ground truth. No new model
(including the R9 FoundationModels conditional-pressure probe) may be tuned to this set and then reported as independent
success. Independent corpus readiness remains `PressureAnnotationOntologyV1`; the RWC rights/annotation/calibration gates
stay OPEN. Calibration PASS is NOT declared.

## 4. Foundation Models capability probe (P1-6)

`ConditionalPressureModelProbeV1` distinguishes the real rungs (SDK / OS / device / model-ready / inference-succeeds /
policy-permitted) via the framework's OWN `SystemLanguageModel.default.availability` (read behind
`canImport(FoundationModels)` + an availability gate). It delivers the §6.1 STRUCTURED OUTPUT CONTRACT
(`ConditionalPressureStructuredOutputV1`: speaker/target/conditional-structure/requested-action/mechanism/
counter-evidence/uncertainty/evidence-span) plus the hard guardrail validator (`rejectUnsupportedFields` — a field the
input text does not support is REJECTED and nulled). The result NEVER drives a production action (experimental,
isolated). **SDK interface honesty: the build agent could not read the installed FoundationModels `.swiftinterface`
(SDK path outside the sandbox) — reported `SDK_UNVERIFIED_BY_AGENT`; the contract + validator + capability-report
mechanism is the proven deliverable, and a host/device run with the verified generation surface replaces the nil in
`tryStructuredProbe` with a real validated structure.**
