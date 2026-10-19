# P008A — Implementation Evidence
Verify: `cd packages/GuardianKit && swift test` → **240/240**; sim app build SUCCEEDED; signed device build + extensions intact.

## Built + tested (GuardianCore, pure)
- Automatic Guardian Runtime: GuardianRuntimeManager, ObservationSessionManager (OFF→…→ACTIVE/INTERRUPTED/RESTART_REQUIRED),
  PlatformCapabilityRegistry (automation truth table), AppContextResolver, SessionRecoveryController, SessionProofCounters.
- CalibrationPilot: CalibrationLevel, CalibrationScope (score-gate coverage), LogisticCalibrator (fit), CalibrationPilotRunner
  (train/held-out, per-language metrics).
- TemporalUnderstandingEngineV1 (VIDEO→SCENE→SHOT/WINDOW + aligned evidence) — real hierarchy.
## Built + tested (GuardianIntelligence)
- VisualSemanticBaselineV1 (Apple Vision classify + feature print + OCR → VisualSemanticEvidenceV1; provenance; no VLM).
## Tests (+9 → 240)
P008ACoreTests (8): iOS automation truth, session state machine, app context, recovery, automatic-session (20 auto / 1 tap),
calibration pilot held-out, temporal hierarchy, boundary real-video eval. P008AVisualBaselineTests (1).
## Honest outcomes / why NOT PASS (per user prerequisites)
- Calibration pilot RAN on real held-out data → metrics POOR (false-safe 0.50, ECE not improved) → toy pilot insufficient →
  status stays LAB_CALIBRATED_LIMITED-at-most and real content stays UNKNOWN. A trustworthy calibrated score is NOT achieved.
- Device extension benchmark: NOT measured (broadcast needs user Start gesture) → DEVICE_EVIDENCE_INSUFFICIENT.
- Automatic session proof (live) + cross-app ≥20-item session: logic built+tested; LIVE run needs user Start gesture.
- External visual-semantic VLM: UNAVAILABLE_PENDING_WEIGHTS_AND_DATA_AUDIT (none integrated).
- App Group / live Dynamic Island scored loop: BLOCKED_PENDING_PAID_APP_GROUP.
- H1 sensitive-visual: UNAVAILABLE_EVIDENCE_BACKED.
