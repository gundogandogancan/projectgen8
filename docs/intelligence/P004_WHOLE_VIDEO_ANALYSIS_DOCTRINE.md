# P004 — Whole-Video Analysis Doctrine

**Doc status:** `CANONICAL` · **Phase:** 4 · **Date:** 2026-10-18 · PROMPT 004 §2. **UNDERSTAND THE WHOLE CONTENT WITH THE MINIMUM NECESSARY COMPUTE.** NO full-FPS brute force.

## Canonical pipeline
```
VIDEO DISCOVERED → IDENTITY → EXISTING CONTENTDNA/TEMPORALGRAPH LOOKUP → FAST METADATA/TEXT PATH
→ SHOT/SCENE BOUNDARY PLAN → REPRESENTATIVE KEYFRAME/WINDOW SAMPLING
→ OCR/TEXT/LANGUAGE/SEMANTIC HEADS → VISUAL SAFETY/ENTITY/TOPIC HEADS
→ COARSE TEMPORAL MAP → UNCERTAINTY/RISK PRIORITY QUEUE → SELECTIVE DEEPENING
→ PERSONAL/FAMILY POLICY PROJECTION → PRE-EXPOSURE / ANALYSIS-AHEAD DECISIONS
```

## Implementation map
- Sampling: `WholeVideoSampler` (coarse-to-fine, duration-adaptive, mode-budgeted, bounded; short-dense vs long-coarse; extra samples near boundaries).
- Boundaries: `SceneBoundaryDetectorV1` (feature-diff + min-gap suppression; no per-frame heavy inference).
- Map: `CoarseTemporalMapV1` (windows: sampled/deepened/categories/uncertainty/value + coverage).
- Deepening: `DeepeningPlannerV1` (explicit versioned priority = uncertainty×imminence×policy×infoGain ÷ cost; early-exit below min priority).
- Ahead: `AnalysisAheadV2` (analyzed/coarse/deep/unknown leads + behind→hold/caution, never stale-safe).
- Fusion: `TemporalFusionV2` (visual-graphic dominance, text disambiguation, modality conflict ↓confidence, missing→UNKNOWN, repeated local risk → whole-video influence).
- Reuse: shared `ContentDNA V3` + `TemporalGraph V3`; `PersonalProjectionLayer` applies cheap personal policy (no re-analysis).

## Hard rules
No full-FPS scanning by default · never claim more coverage than measured · reuse before compute · deepen only where risk/value justifies · stay ahead of playback · keep the device calm · abstain honestly (UNKNOWN) when evidence insufficient.
