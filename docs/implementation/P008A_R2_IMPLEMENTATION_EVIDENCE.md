# P008A-R2 — Implementation Evidence

Status: lab `TESTED` · device build/install `VERIFIED` · fresh device session `DEVICE_VERIFIED_NEGATIVE`
(ran 2026-10-19; `boundary-policy-v3` over-detects on real content: 477 committed vs ~20 → **FIX REQUIRED**).
Evidence: `docs/evals/artifacts/P008A_R2_AFTER_crossapp_device_v3.log` SHA-256
`e0f2328440f494ff5d0283e5f606ac8882e6702d6a5bce34488932f1f32f1148`. Lab generalization did NOT transfer —
fixture within-item motion magnitude was unrepresentative of real device content (see DEVICE_VALIDATION_RESULTS §16/§17).
Per §17 the run is archived; the policy is NOT retuned to it.

## Code (new / changed)
| file | SHA-256 | role |
|------|---------|------|
| `packages/GuardianKit/Sources/GuardianCore/ContentBoundaryV3.swift` | f347ab31fdcd62aefa3a761019bdaa39eeec9b63e4f4ee67b3f5f9b27b9734c4 | MultiRegionSignature, PolicyV3, AccumulatorV3 |
| `packages/GuardianKit/Sources/GuardianCore/BoundaryFixtureHarnessV3.swift` | 23094e14c4218c8f59a16488b62be90652caf975bbff49d4f13292af82946ddd | owned fixtures + eval harness |
| `packages/GuardianKit/Tests/GuardianCoreTests/P008AR2BoundaryV3Tests.swift` | — | 7 V3 tests |
| `GuardianBroadcastExtension/SampleHandler.swift` | 064702f9ef9c17b2531adf5fac1723331428b78f140ec4c24ddc7050b863cfd5 | extension wired to frozen V3, schema-V3 logging |

## Build / install evidence (2026-10-19)
- `swift build` (GuardianKit): Build complete.
- `swift test`: **253 tests, 0 failures**. Held-out: `P=1.000 R=0.917 F1=0.957 dup/item=0.000`.
- `xcodebuild -project Gen8.xcodeproj -scheme Gen8 -configuration Debug -destination id=<device>
  DEVELOPMENT_TEAM=47XQMQZLF6`: **BUILD SUCCEEDED** (SampleHandler compiled in GuardianBroadcastExtension).
- `devicectl device install app`: installed bundleID `com.gen8.guardian.dev`.

## Extension wiring summary
- One canonical engine shared with lab: `BoundaryEvidenceAccumulatorV3(policy: .frozenV3)` — no separate
  extension heuristic, no app-specific code, no private API, no hardcoded pixel coordinates.
- `processSampleBuffer` → `Self.multiRegionSignature(px)` (in-place, normalized sub-rects) →
  `boundary.process(sig)`; downstream analysis only on `committedNew`.
- Logs: `BROADCAST_STARTED … policy=boundary-policy-v3 profile=EXTENSION_FAST`,
  `TRANSITION seq … state … policy … D … dynThr … agree … strong … committed … firstTrustworthyMs …
  memoryMB … thermal … lowPower … score=UNKNOWN …`, `BROADCAST_FINISHED … contentSeq … peakMemoryMB …`.

## Traceability
REQ (cross-app pre-exposure boundary detection) → ADR (ReplayKit-only capture) → CONTRACT
(ContentBoundaryPolicyV3 `boundary-policy-v3`) → CODE (above) → TEST (253, held-out gate) →
DEVICE EVIDENCE (build+install done; fresh session pending) → RELEASE GATE (R2 = engineering
acceptance, not production certification).

## SourceKit note
Editor index may show "No such module 'GuardianCore'" for SampleHandler.swift outside Xcode; this is an
index artifact — the Xcode project links GuardianCore and the device build compiled the file cleanly.
