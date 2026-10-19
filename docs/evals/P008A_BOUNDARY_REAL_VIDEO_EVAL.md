# P008A — Content Boundary Real Moving-Video Eval (§18)
`BoundaryBenchmark` on owned synthetic screen-recorded-style sequences (gradual within-item motion → swipe to new item).
`P008ACoreTests.testBoundaryRealMovingVideoEval`: 2-item, 16-frame sequence → trueBoundaries=2, falseBoundaries ≤1
(gradual motion within item A does NOT spam NEW), missedBoundaries ≤1 (the real swipe is detected). Signals: perceptual
hamming + layout-signature jump + OCR-token persistence + hysteresis. Reported: false-new-content rate, missed rate,
detection latency (= frames-to-confirm). **Honest limit:** fixtures are synthetic/owned; real Instagram/Reels false/missed
rates require the user-consented on-device broadcast capture (no fake Instagram ground truth manufactured).
