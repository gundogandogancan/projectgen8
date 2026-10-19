# P006B — Implementation Evidence

**Scope:** correctness closeout of P006A. No new product scope, no new skills/MCP/models.
**Verify:** `cd packages/GuardianKit && swift test` → **192/192**; iOS simulator build → **BUILD SUCCEEDED**.

## 1. Semantics correction (§1,§2,§3,§4)
- `ShieldMatchState` split into determinable (`NO_MATCH`, `MATCH_LOW/MEDIUM/HIGH/EXACT`) and non-determinable
  (`MATCHABILITY_UNKNOWN`, `MATCHER_UNAVAILABLE`, `EVIDENCE_CONFLICT`). `isMatch` / `isNonDeterminable` / `matchRank`.
- `ShieldActionControllerV2.decide` → `(ShieldLayerDecision, ShieldAction?)`; UNKNOWN/UNAVAILABLE → `NO_SHIELD_DECISION`
  (abstain, nil action). Low → NOTE (no silent hide).
- `GlobalAdmissionController` is the ONLY origin of strict HOLD. Normal mode proceeds on abstention; strict holds only
  with controlled surface **and** an expected-but-unavailable modality.
- Rule-specific routing via `effectiveMatchers` + `matcher.handles(inputType)`: a missing music matcher cannot warn a
  text item; a missing speech matcher cannot hold an image. Proven by `testMissingMusicMatcherDoesNotPoisonItem`.

## 2. Cross-language (§9)
`SemanticTextMatcher` consults an injected `CrossLanguageConceptBridge`. Verified canonical bridge keeps HIGH; unverified
downgrades one tier; unavailable → MATCHABILITY_UNKNOWN. Never downgrades on locale-string difference alone; never
upgrades on MT output. `testCrossLanguageBridgeDrivenNotMechanical`.

## 3. Durability (§5,§6,§7,§8)
- `PersonalShieldStore` protocol + `FileBackedPersonalShieldStore`: Application Support, atomic writes, SHA-256 payload
  checksum (corruption detection), iOS `FileProtectionType.complete`, versioned snapshot + migration hook.
- `DerivedReferenceFeature`: versioned derived-vector format with engine id/revision + checksum; incompatible revision →
  rule `referenceReauthoringRequired` (inactive; never silently "works").
- `ShieldIndex`: reverse-map removal (O(tokens)), crash-safe rebuild, active-only shortlist (paused/expired/reauthoring
  excluded), deleted-rule-cache safety.
- `ShieldStoreManager.loadAndRebuild` ties it together off the main actor.

## 4. Glyph firewall (§10,§11,§12)
Two axes (`GlyphContentCharacter` / `GlyphGuardianState`); `primaryFamily` enforces
`STRONG_PROTECTION > SHIELD_MATCH > CAUTION > UNKNOWN/ANALYZING > CONTENT`. Plain wording, no "healthy".
`GlyphSurfaceController` enforces content-identity + monotonic sequence ordering and never shows a stale/old positive.

## 5. App
`ShieldStudioModel` now loads/persists via `ShieldStoreManager` (durable across relaunch), uses the new
`PersonalShieldDecision` API, and drives the glyph through the firewall. `MyShieldView` updated accordingly. iOS builds.

## 6. Tests (+11 → 192)
`P006BShieldCloseoutTests` (9) + `ShieldDurabilityBenchmarkTests` (1) + rewritten `ShieldV2Tests`/`GuardianGlyphTests`.
Per-target: GuardianCoreTests 132, GuardianIntelligenceTests 42, GuardianMediaTests 18. See P006B_TEST_EVIDENCE_MANIFEST.

## 7. Device health (§16)
- Warm lookup flat ~13 µs at all scales (durable path). delete/update O(tokens). **Correction (see 006C §9 /
  P006C_STARTUP_INDEX_BEHAVIOR):** the index IS rebuilt **once per launch** from durable rules (derived, off-main,
  O(N)); it is incremental within the session. (Earlier "no full reindex per launch" wording was imprecise.)
- O(N²) rebuild regression found and fixed (13.9 s → 67 ms at 10k). Cold load is O(N) and runs off the main actor
  (proven in 006C `testStartupRunsOffMainActor`); idle stays idle (no background vector rebuild loop). Memory bounded by rule count.

## 8. Known limitations
- `ShieldStoreManager.loadAndRebuild` is synchronous-throwing; the app is responsible for invoking it off-main at
  launch (lab harness seeds ~2 rules so this is immaterial there). Documented, not hidden.
- Cross-language certified-pair registry is a stub (`DefaultCrossLanguageBridge` = conservative) until real certification
  data exists; a real bridge backed by `LanguageCapabilityRegistry` is future work.
- Durable cross-session **visual** matching: **RESOLVED in 006C** — replaced the in-memory `VNFeaturePrintObservation`
  with a serializable derived signature (pHash/dHash/normalized vector, Strategy A) that the matcher consumes from disk
  after a true relaunch. See `docs/intelligence/P006C_VISUAL_REFERENCE_PERSISTENCE_CONTRACT.md`.
- Device CPU/battery/thermal + calibration remain `PENDING_EXTERNAL_DEPENDENCY` (no signing team).
