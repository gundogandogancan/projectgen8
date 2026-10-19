# P009B — Vision Brain (`VisionExpertV1`)

**Availability:** REAL_BUT_LAB_ONLY · **Cost:** 5 · **File:** ExpertArmsV1.swift

- **Provider reuse:** consumes labels produced by the real P002/P003 Vision providers
  (`GuardianIntelligence/VisionProviders.swift`, `VisualSemanticBaselineV1.swift`) via `ExpertInputV2.visualLabels`
  — GuardianCore never touches Vision.framework directly.
- **Output:** `scene:<label>` evidence only. No person identity, no demographic traits, no face
  recognition (structurally absent — the expert only maps label strings).
- **OOD:** provider confidence < 0.15 → `oodIndicator=true`, low-confidence abstention.
- **Unavailable:** no visual input in bundle → explicit `.unavailable(reason: "no-visual-provider-input")`.
- **H1 boundary:** visual SAFETY classification (violence/explicit/self-harm imagery) is NOT this expert
  and remains UNAVAILABLE (see P009B_SAFETY_EVIDENCE.md). This expert produces scene evidence only.
- **Calibration:** `.implementedUncalibrated`. No score meaning.
