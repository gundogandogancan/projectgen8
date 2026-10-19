# P006C — Test Evidence Manifest (reproducible, reconciled)

## Commands & environment
- `cd packages/GuardianKit && swift test` · per-target: `swift test --filter <Target>`
- iOS build: `xcodebuild -scheme Gen8 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
- Swift 6.3 / Xcode 26.6 / macOS 26.4 host; iOS 26.x simulator. Timestamp 2026-10-18.

## Per-target results (TARGET-LOCAL, not cumulative)
```text
GuardianCoreTests:          135/135   (0 failed, 0 unexpected)
GuardianIntelligenceTests:   47/47    (0 failed, 0 unexpected)
GuardianMediaTests:          18/18    (0 failed, 0 unexpected)
TOTAL UNIQUE TEST CASES:    200/200
```
All-tests aggregate also reports **Executed 200 tests, with 0 failures** — equals the target sum (no double-count).
Build: `** BUILD SUCCEEDED **`.

## Lineage (reconciled across phases)
154 (P006) → 181 (P006A) → 192 (P006B) → **200 (P006C, +8)**.

## 006C deltas (+8)
- `GuardianIntelligenceTests` +5 (42→47): `P006CVisualDurabilityTests` (6: distance debug, functional relaunch match,
  variants demonstrated, store reauthoring on incompatible revision, delete removes signature, startup off-main) minus
  one removed adversarial text-vs-solid discriminate test in `ShieldBridgeTests`; plus the new signature-ingestion and
  incompatible-revision tests there. Net +5.
- `GuardianCoreTests` +3 (132→135): `P006CCoreTests` (audio durability classification, functional states, startup index
  determinism).

## 006C-specific coverage (per §14)
- functional visual relaunch match ✓ (`testFunctionalRelaunchMatch` — true teardown boundary)
- negative image after relaunch ✓ (same test, negative control)
- incompatible revision ✓ (`testStoreMarksReauthoringOnIncompatibleRevision`, `testIncompatibleSignatureRevisionUnavailable`)
- reauthoring state ✓ (`testFunctionalStates`, store test)
- derived-signature deletion ✓ (`testDeletingRuleRemovesDerivedSignature`)
- startup index behavior ✓ (`testStartupIndexRebuiltDeterministically`)
- no MainActor blocking by persistence/index setup ✓ (`testStartupRunsOffMainActor`)
- audio durability truth state ✓ (`testAudioReferenceDurabilityClassification`)

If any test had failed, the phase would STOP with `FIX REQUIRED`. None failed.
