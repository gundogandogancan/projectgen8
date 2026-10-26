# FM_INFERENCE_R10 — First Real Apple Foundation Models Structured Inference (R10 §6/§7/§8)

Status tier: **synthetic-tested + REAL-INFERENCE-OBSERVED-ON-HOST** (macOS build host). Device (iPhone) Tier-1 still DEVICE_UNVERIFIED.
This experiment NEVER drives a production Guardian decision (constitution rule 8/20). Isolated, experimental, measure-only.

## §6 — What was built

`ConditionalPressureModelProbeV1` now contains the FIRST REAL FoundationModels call-path, written against the
authoritative installed-SDK interface (`/tmp/FoundationModels.swiftinterface`, iOS 26.5 simulator module):

- A `@Generable` output type `ConditionalPressureModelDraftV1` with `@Guide`-annotated fields
  (speaker / target / conditionalStructure / requestedAction / evidenceSpan / coercionPresent / counterEvidence[]).
  Verified against the interface: `@Generable` macro (line 15), `@Guide` (lines 23/31), and that `String` / `String?` /
  `[String]` / `Bool` / enum properties are all Generable-conformable.
- `runStructuredInference(inputText:)`:
  1. reads `SystemLanguageModel.default.availability` (real enum: `.available` / `.unavailable(.deviceNotEligible |
     .appleIntelligenceNotEnabled | .modelNotReady)`);
  2. on `.available`, creates `LanguageModelSession(instructions:)` (String init, interface line 338);
  3. calls `respond(to:generating:options:)` with `ConditionalPressureModelDraftV1.self` and
     `GenerationOptions(temperature: 0.0)` (interface lines 380-381, 1324) — the REAL guided-generation surface;
  4. measures session-init latency + generation latency;
  5. passes the raw model output through the STRENGTHENED grounding validator before returning;
  6. on an ineligible host returns the PRECISE reason string `INFERENCE_UNAVAILABLE(<enum case>)` (honest deliverable).
- Error handling: a `LanguageModelSession.GenerationError` (guardrail / decoding / rate-limit / context-window) is
  caught and reported as `INFERENCE_GENERATION_FAILED(...)` — never a fabricated output.

## §6.1 — Strengthened validator (fabricated relations rejected)

`validateGrounded(candidate:inputText:)` adds, on top of R9's token-presence reject pass:
- **whole-token grounding** for `speaker`/`target` — a claimed relation sharing no WHOLE folded input token is rejected
  (`speaker:ungrounded` / `target:ungrounded`), catching hallucinated people/targets that a loose substring check missed;
- **verbatim contiguous span** check for `evidenceSpan` — a span that is not a literal (normalized) substring of the
  input is rejected, and the mechanism resting on it is dropped (`evidenceSpan:notVerbatim`).
TR-aware folding (case + diacritics, tr_TR locale). Pinned by `AsyncAudioInferenceR10Tests` (3 validator tests).

**Real generation ≠ verified semantic truth** (mandate §6). The tests assert only the GUARDRAIL held (every surviving
span is verbatim), NEVER that the model classified each counter-example correctly.

## §6/§7 — What was OBSERVED on this host

On the macOS build host the availability gate returned `.available` and generation GENUINELY RAN: the counter-example
probe test (`testCounterExampleProbesRunOrSkipHonestly`) did NOT hit `XCTSkip` and executed ~10s of real generation
across the TR+EN probe set; `testRealInferenceRunsOrReportsPreciseUnavailableReason` ran a real session (~1.4s).
This is the first VERIFIED on-host FoundationModels inference in the project. Latencies are measured per call
(`sessionInitMs` / `generationMs`) and reported through `ConditionalPressureInferenceResultV1`.

Counter-example probe set exercised (mandate §6): conditional guilt (TR+EN), conditional-trust coercion, supportive
unconditional (must-not-flag), explicitly non-coercive, neutral everyday talk. Per-case model correctness is NOT a
detection-accuracy claim and is kept out of the production gate.

## §7 — EXTENSION POLICY VERDICT: `EXPERIMENTAL_ON_DEVICE_APP`

FoundationModels is **NOT wired into the GuardianBroadcastExtension**, by decision:

- The ReplayKit broadcast upload extension runs under a HARD memory budget (~50 MB; the Phase-B THERMAL_SERIOUS
  incident proved how little headroom exists). A LanguageModelSession + on-device model assets are far outside that
  envelope; loading them inside the extension would risk the OS jetsamming the extension mid-capture (killing the
  user's actual protection).
- The extension lifecycle is short and preempted; model session init cost is unpredictable there.
- Running FM in the APP (foreground, full memory budget) proves the capability; it does NOT prove the same capability
  survives inside the extension while a THIRD-PARTY app (Instagram/YouTube) is also foreground. Those are different
  resource regimes — the app result must never be presented as an extension result.

Therefore Tier-1 model support stays `EXPERIMENTAL_ON_DEVICE_APP`. A future change-request may add an APP-side
experimental surface (never auto-wired into the extension; never a production decision input).

PRIVACY: FoundationModels is on-device. No network provider fallback exists or will be added. No content leaves device.

## §8 — Evaluation gate (unchanged, honest)

Any FM result on the R7 adversarial sentences is **regression-diagnostic only** — the R7 corpus is engineering-authored
(TP=2 FN=7 Recall=0.22), NOT general world truth. The independent-corpus requirement (rights-permission, distinct
annotators, held-out split, TR-EN-mixed, hard negatives, disagreement→UNKNOWN) remains **BLOCKED** (no rights/annotators).
The R8 PressureAnnotationOntology and P009E / RWC preregistration locks are intact. A model producing good explanations
is NOT evidence of detection accuracy (mandate §8).
