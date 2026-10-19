# P006C — Implementation Evidence

**Scope:** narrow closeout — make reference-based Shield rules FUNCTIONALLY durable + tell the startup-index truth.
No new product scope, no new skills/MCP/models. **Verify:** `swift test` → **200/200**; iOS build → **SUCCEEDED**.

## 1. The contradiction, resolved
P006B §13 implied image rules survive relaunch; §18 admitted live matching depended on an in-memory
`VNFeaturePrintObservation`. Resolved by **Strategy A**: a serializable, matcher-consumable derived signature under our
control that needs no live framework object at compare time.

## 2. Vision feature-print serialization finding (§3)
`VNFeaturePrintObservation` conforms to `NSSecureCoding` (per framework headers) and exposes `data`/`elementType`/
`elementCount`/`revision`, so it *can* be archived. **But Apple does not document stability of that representation
across process relaunch, OS updates, or Vision request-revision changes, and `computeDistance` requires compatible
revision/element layout.** We do not infer stability → we do NOT depend on persisted Vision feature prints.

## 3. Chosen strategy — A (serializable derived signature)
- `GuardianCore/VisualSignature.swift`: `PersistedVisualReferenceSignature` (aHash64 + dHash64 + normVec256),
  `VisualSignatureComponent` (versioned, checksummed), pure `VisualSignatureComparator`.
- `GuardianIntelligence/VisualSignatureEngine.swift`: CGImage → signature via grayscale downsample (no Vision, no face
  detection, raw discarded).
- `ShieldImageReferenceIngestor` → `(signature, DerivedReferenceFeature)`; `ShieldVisualReferenceMatcher.match(frame:reference:)`
  consumes a persisted signature; `decodeSignature(_:)` reconstructs it from durable bytes.

## 4. Functional relaunch (§5) — proven
`testFunctionalRelaunchMatch`: ingest+persist in one scope → scrub local copies → brand-new store/index/matcher →
load from disk → match same (MATCH_HIGH/MEDIUM) and reject unrelated. No shared in-memory object crosses the teardown.

## 5. Variants (§6)
Demonstrated: exact, lossless re-encode, downscale resize (all MATCH_HIGH; structured fixtures). Negative controls:
different pattern + solid → NO_MATCH. Undemonstrated (documented, not claimed): brightness/contrast, crop, rotation.

## 6. Engine revision / reauthoring (§7,§8)
Incompatible `engineRevision`/`compatibilityVersion`/format or checksum failure → comparator `MATCHER_UNAVAILABLE`;
`ShieldStoreManager.loadAndRebuild` marks the rule `REFERENCE_REAUTHORING_REQUIRED` (or `CORRUPT` on checksum fail).
New explicit `ShieldRuleFunctionalState` {ACTIVE, PAUSED, EXPIRED, REFERENCE_REAUTHORING_REQUIRED, MATCHER_UNAVAILABLE,
CORRUPT, MIGRATING}; `isActive` ⇔ ACTIVE only. Non-functional records never read as protecting.

## 7. Startup index truth (§9,§10)
Corrected wording: the index IS rebuilt once per launch from durable rules (derived, not persisted, crash-safe,
deterministic). `loadAndRebuild` is non-`@MainActor`; `testStartupRunsOffMainActor` proves off-main build. Benchmark
rerun (P006C_REFERENCE_DURABILITY_BENCHMARK): warm lookup flat ~13 µs; cold load O(N), 69 ms @10k off-main.

## 8. Audio reference durability (§11) — truth only
`AudioReferenceDurability.classify`: SOUND_CLASS = FUNCTIONALLY_DURABLE; AUDIO_REFERENCE / SPOKEN_REFERENCE =
METADATA_ONLY; MUSIC_TRACK / MUSIC_ARTIST = MATCHER_UNAVAILABLE (ShazamKit unavailable). No implied parity with visual.

## 9. My Shield UX (§12)
`MyShieldView` shows each rule's functional state; a reauthoring rule shows "Protection unavailable — Update reference"
and is tinted — the rule still exists, is not silently deleted, and is not shown as active.

## 10. Privacy / deletion (§13)
No raw image persisted; no face biometric; on-device-only; `ShieldStoreSnapshot.deleteRule` removes the rule AND its
derived signatures (`testDeletingRuleRemovesDerivedSignature`).

## 11. Known limitations
- Brightness/crop/rotation robustness not demonstrated (documented).
- Perceptual hashing needs spatial structure; sparse text-on-white is adversarial — tests use structured fixtures.
- Live camera/stream frame capture is not part of this phase (matcher takes a `CGImage`); device gate PENDING.
- Thresholds locked from synthetic LAB fixtures; real-image calibration remains UNAVAILABLE_INSUFFICIENT_DATA.

## 12. Files changed
New: `GuardianCore/VisualSignature.swift`, `GuardianIntelligence/VisualSignatureEngine.swift`,
`Tests/.../P006CVisualDurabilityTests.swift`, `Tests/.../P006CCoreTests.swift`, 5 docs.
Changed: `ShieldV2.swift` (functional states, audio classification, corrupt/migrating), `PersonalShieldStore.swift`
(deleteRule, corrupt detection, engine defaults, feature accessor), `ShieldIntelligenceBridge.swift` (durable
ingestor/matcher), `ShieldBridgeTests.swift`, `ShieldDurabilityBenchmarkTests.swift`, app `ShieldStudioModel.swift` +
`MyShieldView.swift`. Doc updates: persistence/index, privacy model, My Shield UX, resilience, traceability.
