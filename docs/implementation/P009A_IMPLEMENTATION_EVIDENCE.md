# P009A — Implementation Evidence

Status: lab `TESTED` (ALL §20 gates PASS) · device build/install `VERIFIED` · device item-group validation `PENDING` (user-gated).

## Code (new / changed)
| file | SHA-256 | role |
|------|---------|------|
| `packages/GuardianKit/Sources/GuardianCore/ContentIdentityHierarchyV1.swift` | 47f8f2d8a2ba1d2eaa61e42143541d546c711fb0f00c8505ecb1b010c67a735f | identity IDs/revisions, ShotSegmenterV5 (frozen V5 adapter), ShotDescriptor/BoundaryEvent, HierarchicalTemporalGraphV1 |
| `packages/GuardianKit/Sources/GuardianCore/ContentItemGroupingV1.swift` | f4b1c60ac44f4b60b0b5f0be7a41680f331e990d88706a9d2a69736f98340c9d | evidence graph, grouping engine + policy, item accumulator, item DNA, identity cache |
| `packages/GuardianKit/Sources/GuardianCore/OctopusBrainSkeletonV1.swift` | a4abd89ae82521b494e7b04b6ef3237f8dc56269b85607870d64b390e4bdce42 | meta-brain contracts, pack manifest/lifecycle, learning signal/bus, evolution pipeline, resource governor |
| `packages/GuardianKit/Sources/GuardianCore/HierarchicalCorpusV1.swift` | 2f9e63b4b1f4c43ac5ee80e57d1f255c94d45dc3fc8698730bb250258bcc79d8 | 24-scenario labeled corpus + splits + GroupingEvalV1 |
| `packages/GuardianKit/Tests/GuardianCoreTests/P009AHierarchicalBrainTests.swift` | — | 27 P009A tests (§28) |
| `GuardianBroadcastExtension/SampleHandler.swift` | 5dce29c4866e095ecd62c128c827ad557aa4c9bb4ed46a55d37813dc692dca0e | ShotSegmenterV5 + Tier-0 grouping wired; SHOT/ITEM logging; one analysis per item |

## Build / test evidence (2026-10-19)
- `swift test`: **308 tests, 0 failures** (281 prior + 27 P009A — all prior suites green, V5 untouched).
- Held-out (once, frozen): newP 1.000 · newR 0.944 · F1 0.971 · mergeP 1.000 · xMerge 0.0000 — ALL §20 gates PASS.
- Stress: 24-cut montage 0 explosion; 8 rapid items 7/7 boundaries, 0 collapse.
- `xcodebuild -scheme Gen8 … DEVELOPMENT_TEAM=47XQMQZLF6`: **BUILD SUCCEEDED**; `devicectl install`: OK
  (`com.gen8.guardian.dev`, iPhone 14 Pro Max iOS 26.6).
- §29 bundle baseline measured: 18 MB Debug bundle, 92 KB main exe, 0 model assets.

## V5 evidence preservation (§0)
All five locked artifacts re-verified (`shasum -c` OK): BEFORE `96a92d02…`, R1 `8510ee92…`, V3 `e0f23284…`,
V4 `f63c8de3…`, V5 `6626b5c1…`. No V5 threshold changed; `boundary-policy-v5` untouched; V5 tests all green.

## Traceability
REQ (feed-item identity above the shot sensor) → ADR (hierarchy canon §1; safety-first merge §7) → CONTRACT
(`item-grouping-policy-v1`, pack/learning/evolution contracts) → CODE (above) → TEST (308; §20 gates) → DEVICE
EVIDENCE (build+install done; item-group session pending) → RELEASE GATE (engineering acceptance). SourceKit
"No such module 'GuardianCore'" on the extension file remains an editor-index artifact (device build compiles clean).
