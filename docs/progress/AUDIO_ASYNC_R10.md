# AUDIO_ASYNC_R10 — True Async Audio + Ownership + Completion Truth (R10 §1–§5)

Status tier: **synthetic-tested** (pure state machines + the real SoundAnalysis path where the host can run it).
Device (iPhone) end-to-end chain still DEVICE_UNVERIFIED (no device). Microphone NEVER opened. No raw-audio
persistence / network / cloud transfer.

## §1 — The R9 production defect that was FIXED

R9's `analyzeAudioWindowForItem` ran `audioWorkerQueue.sync { analyzeWindow(...) }` INSIDE the heavy per-item
evaluation on the ReplayKit serial VIDEO callback. Although the analysis dispatched to a worker queue, the caller
BLOCKED (`.sync`) waiting for the SoundAnalysis window to finish — so the video decision path waited on audio.

**Fixed:** the window is now SUBMITTED ASYNC (`audioWorkerQueue.async`) and the heavy path RETURNS IMMEDIATELY. The
video frame path never waits on SoundAnalysis. While a window is in flight the world-model audio coverage is a DISTINCT
`AUDIO_PENDING` state (≠ AVAILABLE), surfaced to the user as "ses: analiz sürüyor".

## §1 — Apply-or-drop revalidation (ASYNC CALLBACK ≠ SAFE TO APPLY)

New pure type `AudioAsyncRevalidatorV1` (in `AsyncAudioAnalysisCoordinatorV1.swift`). On async completion the (real,
already-analyzed) result is revalidated against the LIVE identity via an `AudioApplyTicketV1` snapshot. EVERY field
must still match or the result is DROPPED + counted (never silent). The mandated matrix is pinned by tests:

| completion scenario                | decision                 |
|------------------------------------|--------------------------|
| same item, same policy/family/session, Guardian on | APPLIED (progressive same-item update) |
| user swiped to a new item (revision/generation advanced) | DROPPED_ITEM_CHANGED |
| Guardian turned off / went idle    | DROPPED_GUARDIAN_OFF     |
| child/family profile revision changed | DROPPED_FAMILY_CHANGED |
| shield policy revision changed     | DROPPED_POLICY_CHANGED   |
| capture stopped / session ended    | DROPPED_SESSION_ENDED    |
| a fresher window for the same item was submitted | DROPPED_SUPERSEDED |

Precedence is explicit and ordered (session/capture first, then Guardian-on, then item identity, then policy/family,
then supersede). A VALID completion applies the audio evidence and runs a BOUNDED progressive re-adjudication (§5).

## §2 — One ownership discipline

New `AudioHandoffStoreV1` is the SINGLE serial-queue-confined store that owns the derived bounded hand-off
(count + bytes + duration, via `BoundedAudioQueueV1`) AND the OUTSTANDING-window accounting under ONE discipline:
shared caps (max bytes, max duration, max outstanding windows = 2), a memory HIGH-WATER mark, release-on-completion,
and a session-end PURGE (no cross-session leakage — pinned by test). `@unchecked Sendable` with the documented
invariant: EVERY property is accessed only inside the serial queue (no un-serialized path). The SoundAnalysis-typed
PCM copies remain in SampleHandler under an `NSLock` and are released at window completion. The video callback appends
a derived sample and returns immediately (never blocked).

## §3 — Completion truth (verified against real SoundAnalysis)

The R9 `LiveAudioStreamSessionV1.analyzeWindow` completion contract is unchanged and still the single authority for
`.available` (a real result, or a VERIFIED completed-no-event; a submitted-but-pending window is PENDING → UNAVAILABLE;
a timeout → analysisFailed). The R9 synthetic-PCM-through-real-SNAudioStreamAnalyzer end-to-end test still passes where
the host can run inference (otherwise it skips honestly as CLASSIFIER_UNAVAILABLE_ON_HOST). Consecutive windows are
isolated (the analyzer is torn down + re-armed per window — `teardown()` after each `completeAnalysis()`).

## §4 — Firewall on the async path

The §3/§4 generation+item firewall now triggers on the ASYNC COMPLETION (via `AudioAsyncRevalidatorV1`), not just the
old sync path. The ticket carries session + item revision + generation + policy revision + family revision; the bridge's
own generation firewall is a second line of defense (a late REAL `.available` for a prior generation is kept UNAVAILABLE
on the new item — pinned by `LiveAudioInferenceR9Tests.testLateAudioCompletionForPriorItemIsDroppedByBridgeGenerationFirewall`).
Adjacent-window merge discipline is inherited unchanged from `ReelsAudioEventV1` (adjacent-window merge only; no
cross-window-gap merge).

## §5 — Progressive audiovisual world model

`SampleHandler.progressivelyReadjudicateCurrentItemWithAudio` re-runs the EXISTING frozen bridge
(`WorldModelEvidenceBridgeV1`) + child overlay (`ChildAgePolicyEngineV1`) + adjudicator
(`GuardianFamilySurfaceAdjudicatorV1`) for the SAME item with the item's captured text/context snapshot PLUS the new
`.audioEvent` evidence — NOT a second timeline/safety engine. If the canonical surface CHANGES, the decision epoch
advances and the change is recorded in the timeline with provenance (previous reason → new reason, changeReason =
`audio-evidence-arrived-same-item`) reusing the R4 `recordSurfaceChange` mechanism. If nothing changes, no event and no
epoch move (honest: nothing new). An audio event alone never declares psychological harm; it only widens the scope of
the existing risk assessment.

## §P1-7 — UX

The heartbeat now carries the PENDING audio ladder rung (`CLASSIFIER_WINDOW_SUBMITTED`) for the decision's item while a
window is in flight, so the coverage row reads "ses: analiz sürüyor" and never implies audio ran. `LiveGuardianInsightView`
reads `audioLadderStateRaw` (R9 wiring, unchanged); PENDING maps to the submitted rung (UNAVAILABLE for coverage, but
distinguishable from a hard deferral). No fake positive status.

## Tests

`AsyncAudioInferenceR10Tests` (18 tests): the full apply-or-drop matrix, the ownership store (outstanding-window bound,
byte high-water, session-end purge, drain firewall), PENDING≠AVAILABLE, the strengthened FM validator, and the real FM
inference call-path. All R9 audio tests (`LiveAudioInferenceR9Tests`, `LiveAudioEvidenceR8Tests`) still pass.
