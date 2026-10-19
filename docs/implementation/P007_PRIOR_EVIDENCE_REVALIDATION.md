# P007 — Prior Evidence Revalidation (PROMPT 007 §0)

Re-ran before any 007 change. No invariant regressed → proceeded.

| Check | Method | Result (2026-10-18) |
|-------|--------|---------------------|
| All test targets | `swift test` per target | GuardianCoreTests **135/135**, GuardianIntelligenceTests **47/47**, GuardianMediaTests **18/18** = **200/200** |
| iOS simulator build | `xcodebuild … iPhone 17 Pro … CODE_SIGNING_ALLOWED=NO` | **BUILD SUCCEEDED** |
| Shield durability | `ShieldDurabilityBenchmarkTests` | warm lookup ~12.8µs p50 flat 10→10k; cold load O(N) 217µs→67ms; first decision <29µs |
| P006 sub-second admission | `--filter SubSecond` | PASS (fast admission non-blocking) |
| P006B/P006C persistence | relaunch + functional visual durability tests | PASS (durable signatures survive teardown) |
| P005 real-media benchmark | existing media tests | PASS |
| UNKNOWN/UNAVAILABLE semantics | Shield + glyph tests | PASS (abstain, never stale-safe) |

Unique-count lineage: 154 (P006) → 181 (P006A) → 192 (P006B) → 200 (P006C) → 007 builds on 200.
No regression. Revalidation OK.
