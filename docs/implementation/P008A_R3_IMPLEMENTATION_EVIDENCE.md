# P008A-R3 — Implementation Evidence

Status: lab `TESTED` · device build/install `VERIFIED` · fresh device validation `PENDING` (user-gated).

## Code (new / changed)
| file | SHA-256 | role |
|------|---------|------|
| `packages/GuardianKit/Sources/GuardianCore/ContentSegmenterV4.swift` | 0b44538f8c81342058ab951ffb9462a081c0a6a26007554e89a120905104afbd | SegmentFrameV4, RobustMotionBaseline, TemporalRegionReliabilityV1, DeviceMotionProfileV1, ContentBoundaryPolicyV4, BoundaryEvidenceAccumulatorV4, CoherentTranslationV4 |
| `packages/GuardianKit/Sources/GuardianCore/RealisticFixtureGeneratorV4.swift` | fa7da7ab4c55dfe8e5823c870ab313944439d47cce0f33cb9736cfd457df2799 | profile-parameterized fixtures, TUNE/HELD-OUT/STRESS, SegmentEvalV4 |
| `packages/GuardianKit/Tests/GuardianCoreTests/P008AR3SegmenterV4Tests.swift` | — | 14 R3 tests (§31) |
| `GuardianBroadcastExtension/SampleHandler.swift` | 992655aaa393044879ce40f1807c47bfabcc244bbf3b312e737b2fd38c55d7bb | frozen V4 wired; segmentFrame (regions+projections) in place; schema-V4 `SEGMENT` + derived-only `CALIB` logging |

## Build / test evidence (2026-10-19)
- `swift build` (GuardianKit): Build complete.
- `swift test`: **267 tests, 0 failures** (253 prior + 14 R3). Held-out `P=1.000 R=0.889 F1=0.941 dup=0.000 fp=0.000`.
- `xcodebuild -scheme Gen8 -destination id=<device> DEVELOPMENT_TEAM=47XQMQZLF6`: **BUILD SUCCEEDED**
  (SampleHandler compiled in GuardianBroadcastExtension).
- `devicectl device install app`: installed `com.gen8.guardian.dev` on iPhone 14 Pro Max iOS 26.6.

## §19 extension integration
ONE canonical `BoundaryEvidenceAccumulatorV4(policy: .frozenV4)` shared by lab + extension — no separate algorithm
path. The extension-safe profile keeps the full semantic state machine + policy revision; optional expensive signals
(e.g. feature-print, §22) are not enabled. No app-specific logic, no private API, no hardcoded pixel coordinates.

## §22 optional feature-print escalation — EVALUATED, DEFERRED
A Vision feature-print escalation for AMBIGUOUS high-motion candidates was considered. Rejected for the cheap 50 MB
broadcast extension: it adds a Vision dependency + per-ambiguous-frame latency/memory the extension budget can't
absorb, and the cheap path already achieves precision 1.000 with the only gaps in the genuinely-ambiguous overlap
zone (error budget per §28). Revisit if a future profile shows ambiguity is material on real device.

## Traceability
REQ (cross-app persistent-segment detection) → ADR (ReplayKit-only capture) → CONTRACT (`boundary-policy-v4`) →
CODE (above) → TEST (267, held-out/stress gated) → DEVICE EVIDENCE (build+install done; fresh V4 session pending) →
RELEASE GATE (engineering acceptance, not production certification). SourceKit "No such module 'GuardianCore'" on the
extension file is an editor-index artifact; the Xcode build links it and compiled cleanly.
