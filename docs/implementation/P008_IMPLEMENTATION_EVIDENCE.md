# P008 — Implementation Evidence
Verify: `cd packages/GuardianKit && swift test` → **231/231**; sim app build SUCCEEDED; signed device build + both
extensions installed (P007C/D) intact.

## Built + tested (GuardianCore, pure, headless)
- `MultimodalContentUnderstandingV1` + `ModalEvidenceSignal` (provenance; no naked label).
- `CrossModalEvidenceGraphV1` + `CrossModalEvidenceFuser` (agreement boost / conflict penalty / missing-modality; NOT averaging).
- `PersonalSuitabilityScoreV1` + `SuitabilityFusionV1` (score≠confidence; UNKNOWN gate on coverage+calibration; hard
  Shield/safety precedence; floors/caps; seed-weights-v1-UNCALIBRATED).
- `ContentBoundaryDetectorV2` (+benchmark) — motion-within-item vs NEW item.
- `ContentIdentityResolverV2` — EXACT/STRONG/PROVISIONAL/UNKNOWN; no weak-identity ContentDNA reuse.
- `CalibrationMetrics` (ECE/Brier/MAE/PRF1/false-safe) + `SuitabilityEvalExample`; status UNAVAILABLE_INSUFFICIENT_DATA.
- Made `AdmissionState` Codable (additive).

## Real-provider fusion (P008-B)
`P008RealEvidenceTests` (GuardianMediaTests): real Vision OCR + real SoundAnalysis on owned fixtures → understanding with
per-signal provenance + rawMediaRetention="none"; low coverage + no calibration → score honestly UNKNOWN.

## Tests (+12 → 231)
`P008CoreTests` (11): provenance, agreement-boost/conflict-penalty, coverage-gate UNKNOWN, calibration-gate,
hardShield/safetyFloor precedence, score≠confidence, stability, boundary V2, boundary benchmark, identity V2, calibration metrics.
`P008RealEvidenceTests` (1).

## Honestly UNAVAILABLE / BLOCKED / pending (not faked)
- Visual-semantic model: UNAVAILABLE_PENDING_RIGHTS_CLEAR_CANDIDATE (none verified).
- Calibration: UNAVAILABLE_INSUFFICIENT_DATA → system shows UNKNOWN, never an uncalibrated number.
- TR/EN separate EVALUATION results: pending the calibration dataset (architecture separates them; no eval data yet).
- H1 sensitive-visual: UNAVAILABLE_EVIDENCE_BACKED (unchanged).
- iOS cross-process handoff + live Dynamic Island score from cross-app content: BLOCKED_PENDING_PAID_APP_GROUP.
- Real-device Instagram/Reels scored proof (§30): requires user broadcast gesture + the paid handoff → not performed.
- Device latency/resource for the new heads: NOT fabricated; LAB only / pending device run.
- Full `TemporalUnderstandingEngineV1` hierarchy: boundary V2 + existing WholeVideoAnalyzer cover temporal; the full
  chapter/scene/shot engine is contract-level this turn.
