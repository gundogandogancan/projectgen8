# P009B — Expert Contract (`MultimodalExpertV2` / `ExpertEvidenceV2`)

**File:** OctopusRuntimeV2.swift · **Tested:** P009BExpertMeshTests (27 tests)

## Protocol

```swift
protocol MultimodalExpertV2 {
    var domain: ExpertDomainV2 { get }
    var availability: ExpertAvailabilityV2 { get }   // R1 5-tier: REAL_RUNTIME_DEVICE_PROVEN /
                                                     // REAL_RUNTIME_NOT_DEVICE_PROVEN / REAL_IN_PROCESS_LAB_ONLY /
                                                     // CONTRACT_ONLY / UNAVAILABLE
    var modelVersion: String { get }
    var resourceCost: Double { get }                 // 1 cheap … 10 heavy; drives cheapest-sufficient routing
    func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2
}
```

**R1 F5 classification law:** the tier comes from ACTUAL wiring + evidence. DEVICE_PROVEN needs a
physically exercised on-device run; NOT_DEVICE_PROVEN needs a production (non-DEBUG) in-app consumer;
LAB_ONLY = real code exercised in-process (tests / DEBUG HUD / real-provider trace test) only.
Renaming an enum value never changes a tier — `testAvailabilityTruthMatchesRuntime` asserts the runtime
constants against this doc's table.

## Evidence record (every field mandatory, honesty-bearing)

`ExpertEvidenceV2`: domain · labels · features · confidence · coverage · uncertainty · oodIndicator ·
inputModalityAvailable · shot/item IDs + `itemProvisional` · provenance (producer←provider chain) ·
modelVersion · resourceCost · privacyClass (`derivedNonReconstructive`) · latency · calibrationStatus ·
generation · stale.

## Laws

1. **Honest unavailability:** an expert that cannot run returns `.unavailable(domain, reason:)` —
   `inputModalityAvailable=false`, confidence 0, calibrationStatus `.unavailable`. Never a guess.
2. **Derived input only:** `ExpertInputV2` carries provider-derived results (OCR text, visual labels,
   sound classes, transcripts) — never raw frames/audio. GuardianCore stays Apple-framework-free.
3. **No calibrated claims:** no expert may return `.implementedCalibrated` in P009B
   (asserted: `testScoreDisplayImpossibleInP009B`).
4. **Generation-stamped:** every evidence record carries the generation it was computed for; the
   Meta-Brain discards mismatches (stale firewall).
5. **Abstention over fabrication:** unsupported language → `UNSUPPORTED_LANGUAGE`; unsupported audio
   classes → counted, not interpreted; zero validated events → explicit `audio:no-validated-events`.
6. **No identity/person traits:** vision labels are scene-level (`scene:`); no face identity, no
   demographic inference.

## Availability truth (as shipped — R1 corrected; audit F5 closed)

| Expert | Availability | Why |
|---|---|---|
| ALL 10 arms (vision, languageOCR, speech, audioEvent, music-presence, symbol, temporal, safetyEvidence, benefitEvidence, attentionPressure) | REAL_IN_PROCESS_LAB_ONLY | real code + real providers exist and the REAL path (real Vision OCR → adapter → mesh) is exercised in-process; but the only in-app consumer is the DEBUG HUD — no production (non-DEBUG) consumer and no device-proven run exist yet. The previous REAL_RUNTIME labels on 5 arms were availability inflation (audit F5) and are retracted. |
| Music identity (which song) | UNAVAILABLE | no licensed identification asset — honest `music-identity:UNAVAILABLE` |
| H1 visual safety dimensions (+self-harm/drugs/gambling/dangerous/profanity) | UNAVAILABLE | no rights-clear model; carried open blocker |

Upgrade path: REAL_RUNTIME_NOT_DEVICE_PROVEN requires a production consumer wiring; DEVICE_PROVEN
requires the §14 user-gated physical run — and only the experts actually exercised in that run upgrade.
