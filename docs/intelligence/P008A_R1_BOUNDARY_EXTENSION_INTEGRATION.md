# P008A-R1 — Boundary V2 Extension Integration (§2,§3,§4)
Root cause: the production `SampleHandler` used `ContentChangeDetector` (pure aHash), NOT the tested
`ContentBoundaryDetectorV2`; on real moving video the aHash tripped on every motion → 406 triggers / 168 analyzed.
## Fix (one canonical engine, no divergence)
- `ContentBoundaryEngineV2` (GuardianCore) is now THE boundary commit engine, used by BOTH lab tests and the broadcast
  extension. It wraps the classifier (perceptual + layout + optional text persistence) and adds HYSTERESIS (settle),
  minimum DWELL, and DEBOUNCE between committed NEW events — so motion within one item never commits, rapid swipes still do.
- `ContentBoundaryPolicyV2` (versioned `boundary-policy-v2`): perceptualSame/New, layoutNew, settleFrames, minDwellFrames,
  debounceFramesBetweenNew, textPersistenceOverlapSame, ambiguousCommitsNew. No magic constants in SampleHandler; the
  policy revision is logged every session.
- `BoundaryCapabilityProfile`: EXTENSION_FAST (ocrEnabled=false — 50 MB budget; layout on) vs APP_FAST (ocr on). The
  extension's OCR-off simplification is EXPLICIT, not a hidden divergent heuristic.
- SampleHandler flow: CMSampleBuffer → aHash (8×8) + layout hash (4×4 band) → `engine.process` → ONLY `committedNew`
  invokes the deterministic Shield/admission (→ UNKNOWN). OCR off in extension (periodic/app-side only).
