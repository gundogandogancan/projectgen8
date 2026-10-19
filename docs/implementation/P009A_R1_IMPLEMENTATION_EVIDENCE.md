# P009A-R1 — Implementation Evidence
Status: lab `TESTED` (ALL Tier-0/Tier-1/device-like gates PASS) · device build/install `VERIFIED` · fresh device run `PENDING`.
| file | SHA-256 | role |
|------|---------|------|
| `Sources/GuardianCore/ProfileAwareGroupingV2.swift` | 6537dba1d05eb7b86f8495663c1d3c96b74d6348656c72c468891c7d8c7bae73 | profiles, Tier-0 evidence components, PolicyV2, EngineV2, coalescer, thermal contract |
| `Sources/GuardianCore/Tier0CorpusV1.swift` | 6e512c4a33a8628e28ff6f56a98e344e5eeafc506e1e8955fd2a453db1f40f76 | style/content-decoupled 24-scenario corpus + 4 splits + device-like + Tier0EvalV1 |
| `Tests/GuardianCoreTests/P009AR1Tier0Tests.swift` | — | 15 R1 tests (§25) |
| `GuardianBroadcastExtension/SampleHandler.swift` | 27da814946f4389e1a7a38ca73750e70aada619c655a417e5c05c3f380f9c72a | V2 Tier-0 wired + coalescer + profile/ceiling logging |
Build/test (2026-10-19): `swift test` **323 tests, 0 failures** (308 prior green — v1 engine/policy untouched).
Gates: T0 held-out ALL PASS (newP 1.000 / newRexp 1.000 / mergeP 1.000 / xM 0.0000 / ambRate 0.133 / avoided 0.48);
T0 stress (montage 23/23, rapid 7/7); device-like (ratio 1.00, 0 false merge, 43% avoided); T1 regression clean.
`xcodebuild` BUILD SUCCEEDED; `devicectl` installed `com.gen8.guardian.dev`.
No device-run retuning: the archived P009A run contributed only statistical shape to the device-like generator.
