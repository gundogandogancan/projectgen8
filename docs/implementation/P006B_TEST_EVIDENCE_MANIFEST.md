# P006B — Test Evidence Manifest (reproducible, reconciled counts)

Reconciles the earlier inconsistent aggregates (P006 "154", P006A "180→181").
**Those were not contradictions — they were snapshots at different times:** 154 = end of P006; 181 = end of P006A
(adds Shield + Glyph + one benchmark); 192 = end of P006B (adds the closeout + durability suites).

## Commands & environment
- Package test command: `cd packages/GuardianKit && swift test`
- Per-target command: `swift test --filter <TargetName>`
- Simulator build: `xcodebuild -scheme Gen8 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
- Toolchain: Swift 6.3 / Xcode 26.6 / macOS 26.4 dev host; iOS 26.x simulator. Timestamp: 2026-10-18.

## Per-target results (counts are TARGET-LOCAL, not cumulative)

```text
GuardianCoreTests:          132/132   (0 failed, 0 unexpected)
GuardianIntelligenceTests:   42/42    (0 failed, 0 unexpected)
GuardianMediaTests:          18/18    (0 failed, 0 unexpected)
TOTAL UNIQUE TEST CASES:    192/192
```

- The `swift test` all-tests aggregate also reports **Executed 192 tests, with 0 failures**, matching the sum of the
  three target-local counts above (no double-counting; there are no parameterized/duplicated invocations).
- Some tests contain honest `XCTSkip` branches (e.g. NLEmbedding or Vision unavailable on a runtime). On this host none
  skipped; where a model is absent they skip rather than fake a pass.

## Build result
`** BUILD SUCCEEDED **` (iOS simulator, code signing disabled).

## 006B deltas vs 006A (181 → 192, +11 in GuardianCoreTests)
- `P006BShieldCloseoutTests` (9): routing isolation, strict-mode hold vs proceed, persistence relaunch proof,
  deleted-rule-cache, incompatible-feature reauthoring, corruption detection, glyph surface ordering safety,
  authority precedence audit, cross-language bridge.
- `ShieldDurabilityBenchmarkTests` (1), and the existing `ShieldV2Tests`/`GuardianGlyphTests` were rewritten (net +1).

If any test had failed, this phase would STOP with `FIX REQUIRED`. None failed.
