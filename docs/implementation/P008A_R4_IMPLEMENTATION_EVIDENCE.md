# P008A-R4 — Implementation Evidence

Status: lab `TESTED` · device build/install `VERIFIED` · fresh device validation `PENDING` (user-gated).

## Code (new / changed)
| file | SHA-256 | role |
|------|---------|------|
| `packages/GuardianKit/Sources/GuardianCore/ContentSegmenterV5.swift` | 2f621aee8c6bdfa23bf3ebf8ddcb4b0ae038ce3c0edddac915aa6e12b2163821 | SegmentStateV5/ReasonV5, SwipeGateStateV1, DeviceMotionProfileV2, ContentBoundaryPolicyV5 (time-based), TemporalSwipeGateV1, regionalReplacementRatio, BoundaryEvidenceAccumulatorV5 |
| `packages/GuardianKit/Sources/GuardianCore/FixtureGeneratorV5.swift` | 19196d2c7c88e185e55833ff9dda7b31972152f3096e3e64ccf2de4e5816c171 | timestamped fixtures + continuous-pan + cadence rendering + 4-way split + SegmentEvalV5 |
| `packages/GuardianKit/Tests/GuardianCoreTests/P008AR4SegmenterV5Tests.swift` | — | 14 R4 tests (§27) |
| `GuardianBroadcastExtension/SampleHandler.swift` | d817b893a3f6973a4b1b7110aad8b0957d3215026a5b988e2a88d5f983fa9917 | frozen V5 wired, PTS-timestamped process, schema-V5 SEGMENT + evidence-build MOTION logging, 8×8 projections |

## Build / test evidence (2026-10-19)
- `swift test`: **281 tests, 0 failures** (267 prior + 14 R4). Held-out `P=1.000 R=0.882 F1=0.938 dup=0 fp=0`;
  cadence 60/30/20/jitter/drop = 14/15/15/15/15; stress pathological slices all 0 false.
- `xcodebuild -scheme Gen8 -destination id=<device> DEVELOPMENT_TEAM=47XQMQZLF6`: **BUILD SUCCEEDED**.
- `devicectl device install app`: installed `com.gen8.guardian.dev` on iPhone 14 Pro Max iOS 26.6.

## §19 extension integration
ONE canonical `BoundaryEvidenceAccumulatorV5(policy: .frozenV5)` shared by lab + extension — no separate path. The
extension-safe profile keeps the full state machine + policy revision; evidence build adds derived-only per-frame
telemetry at compile/env level (no App Group). No app-specific logic, no private API, no hardcoded pixel coordinates.

## Removed / changed from V4
`swipeConfirmRelief` (the relief failure mode) is GONE — swipe is supporting evidence via TemporalSwipeGateV1.
Frame-count dwell/refractory → time-based (ms). 16×16 projections → 8×8 (§17).

## Traceability
REQ (cross-app persistent-segment sensor) → ADR (ReplayKit-only) → CONTRACT (`boundary-policy-v5`) → CODE → TEST
(281, held-out/stress/cadence gated) → DEVICE EVIDENCE (build+install done; fresh V5 session pending) → RELEASE GATE
(engineering acceptance, not production certification). SourceKit "No such module 'GuardianCore'" on the extension
file is an editor-index artifact; the Xcode build links it and compiled cleanly.
