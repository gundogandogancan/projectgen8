# P006A — Implementation Evidence

**Scope:** Multimodal Personal Shield + Guardian Glyph Engine. Dual-evidence (D-0016) + P0-Q where user-facing.
**Verify:** `cd packages/GuardianKit && swift test` → **180/180 pass**; iOS simulator build → **BUILD SUCCEEDED**.

## 1. Code added
| File | Target | Purpose |
|------|--------|---------|
| `Sources/GuardianCore/ShieldV2.swift` | GuardianCore (pure) | `ShieldRuleV2`, input/match/action enums, matchers (exact/alias/source/sound-class/semantic-injected), `ShieldActionControllerV2` |
| `Sources/GuardianCore/ShieldIndex.swift` | GuardianCore | bounded layered index, `ShieldException`+engine (authority precedence), correction loop |
| `Sources/GuardianCore/ShieldEvaluatorV2.swift` | GuardianCore | composes index → matchers → exceptions → controller → `ShieldOutcome` |
| `Sources/GuardianCore/GuardianGlyph.swift` | GuardianCore | `GuardianGlyphEngine`, families, styles, `GuardianGlyphStabilizer`, `GlyphSurfaceState` staleness |
| `Sources/GuardianIntelligence/ShieldIntelligenceBridge.swift` | GuardianIntelligence | `ShieldSemanticDistance` (NLEmbedding), `ShieldImageReferenceIngestor` + `ShieldReferenceStore` + `ShieldVisualReferenceMatcher` (Vision feature print; no face biometric) |
| `Gen8/ShieldStudioModel.swift`, `Gen8/MyShieldView.swift` | app | My Shield studio tab (create rules, evaluate sample, preview glyph) |

## 2. Tests added (+26 → 180 total)
- `GuardianCoreTests/ShieldV2Tests.swift` (12): rule Codable/versioned; exact across structured/OCR/transcript; alias;
  source; sound-class; semantic + UNAVAILABLE; cross-language softening; **controller determinism (low never hides,
  unknown never safe)**; bounded index at 1000; exception precedence (user/guardian/floor); correction loop; E2E evaluator.
- `GuardianCoreTests/GuardianGlyphTests.swift` (10): family mapping; protection dominance; unknown/low never-safe;
  style selection; medical-wording ban; stabilization (rapid-swipe, stable-commit, immediate-protection); stale-never-safe.
- `GuardianCoreTests/ShieldBenchmarkTests.swift` (1): flat latency + constant matchers at 10/100/1000 rules.
- `GuardianIntelligenceTests/ShieldBridgeTests.swift` (5): real NLEmbedding ordering; evaluator w/ real distance;
  image fingerprint (no pixels); **real Vision feature-print discrimination (same logo > unrelated frame)**; unknown ref = UNAVAILABLE.

## 3. Intelligence evidence
- Correctness: deterministic matcher/controller mapping proven by table-driven tests.
- Real frameworks headless: NLEmbedding semantic ordering and Vision feature-print image matching both execute and
  discriminate (with honest `XCTSkip` if a model is unavailable — never a fake pass).
- Pre-exposure coverage: shield runs inside the existing pre-exposure path; `USER HARD SEMANTIC SHIELD` precedence (ADR-0007).
- Honest UNAVAILABLE: semantic (no embedding), music identity (Shazam), spoken-phrase (Speech), face/voice (by design).

## 4. Device-health evidence
- LAB microbenchmark: ~10µs/eval, flat across rule scale, `matchersRun=5` (bounded). See P006A_SHIELD_BENCHMARK.
- Real device CPU/battery/thermal: **PENDING_EXTERNAL_DEPENDENCY** (no signing team) — not claimed.

## 5. P0-Q UX
My Shield tab: 44pt targets, text labels on every glyph, destructive outcomes previewed (never silently applied),
UNKNOWN never shown as safe, glyph style selectable incl. OFF. iOS build succeeds.

## 6. Honest gaps (not claimed as done)
- Standalone consumer My-Shield screen + dedicated guardian editor: deferred (later product phase).
- Dynamic Island / Live Activity glyph rendering: device-gated (ActivityKit) — engine + staleness ready, surface PENDING.
- `ShieldVisualReferenceMatcher` requires the reference print to be in-memory (`ShieldReferenceStore`); cross-session
  durable visual matching needs a persisted-vector format (future), tracked honestly.
