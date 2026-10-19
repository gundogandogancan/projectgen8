# P009B — Expert Contract (`MultimodalExpertV2` / `ExpertEvidenceV2`)

**File:** OctopusRuntimeV2.swift · **Tested:** P009BExpertMeshTests (27 tests)

## Protocol

```swift
protocol MultimodalExpertV2 {
    var domain: ExpertDomainV2 { get }
    var availability: ExpertAvailabilityV2 { get }   // REAL_RUNTIME / REAL_BUT_LAB_ONLY / CONTRACT_ONLY / UNAVAILABLE
    var modelVersion: String { get }
    var resourceCost: Double { get }                 // 1 cheap … 10 heavy; drives cheapest-sufficient routing
    func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2
}
```

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

## Availability truth (as shipped)

| Expert | Availability | Why |
|---|---|---|
| Vision, OCR/Language, AudioEvent, Speech, Music(detection), Benefit, Attention | REAL_BUT_LAB_ONLY | real providers exist (P002–P006) but device-proof for the mesh path is pending |
| Symbol, Temporal, SafetyEvidence | REAL_RUNTIME | pure derived-input heuristics; run anywhere |
| Music identity (which song) | UNAVAILABLE | no licensed identification asset — honest `music-identity:UNAVAILABLE` |
| H1 visual safety dimensions | UNAVAILABLE | no rights-clear model; carried open blocker |
