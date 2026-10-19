# P006A — Guardian Glyph System

A small, premium, ambient glyph that communicates **content state** — in the Pure Bar, in-app surfaces, and (where the
platform allows) the Dynamic Island / Live Activity. It is a *calm status cue*, never a diagnosis, never a fake "safe".

## 1. Families (`GlyphFamily`, `GuardianCore/GuardianGlyph.swift`)
`analyzing`, `neutral`, `unknown`, `learning`, `humorPositive`, `creativity`, `calmNature`, `music`, `entertainment`,
`caution`, `shieldMatch`, `strongProtection`.

## 2. Mapping (`GuardianGlyphEngine.family`)
Precedence inside the glyph (mirrors ADR-0007 safety-first ordering):
1. strong protection / HIGH or EXACT shield → `strongProtection`
2. MEDIUM / CONFLICTING shield → `shieldMatch`
3. coverage unknown / shield UNKNOWN or UNAVAILABLE / engine confidence < 0.45 → `unknown`
4. music → `music`
5. dominant benefit → `learning` / `humorPositive` / `creativity` / `calmNature` / `entertainment`
6. otherwise → `neutral`

## 3. Truthfulness (§21, §24)
Each `GlyphToken` carries `isTruthfulSafeClaim`. It is **false** for `unknown` and `analyzing` — the UI must not render
these as "all clear". A **stale** Live Activity state (`GlyphSurfaceState.render(now:)` past `staleAfterNanos`) is
**downgraded to UNKNOWN** — a stale surface can never keep showing the old safe glyph.

## 4. Medical-wording safety (§23)
Glyph labels are deliberately non-diagnostic ("Calm", "Learning", "Heads-up", "Protected"). A test asserts no label
contains diagnostic terms (`diagnos`, `disease`, `disorder`, `cure`, `treat`, `patient`, `symptom`). The glyph never
implies a health condition of the user or the content.

## 5. Stabilization — no jitter (§22, `GuardianGlyphStabilizer`)
- A family commits only after it is observed consistently (`requiredStreak`, default 2) for the **same** content, above
  `minConfidence` (default 0.45).
- A content change resets to `analyzing` → rapid swiping never commits a positive family (no flicker).
- Safety families (`strongProtection`, `shieldMatch`, `caution`) commit **immediately** — protection must not lag.

## 6. User style (§19) — `GlyphStyle`
`MINIMAL` (SF Symbol only), `EMOJI` (adds an emoji), `OFF` (no glyph), `AUTO`. `OFF` returns no token. Accessible:
every family has a text `label`; symbol names are capability-truthful candidates (UI verifies SF Symbol availability).

## 7. Dynamic Island / Live Activity (§24) — capability-truthful
The glyph is a *role*, not a promise. The Pure Bar is the primary, always-available surface (in-app). Dynamic Island /
Live Activity rendering is **device-gated** (ActivityKit) and documented as `PENDING_EXTERNAL_DEPENDENCY` until a
signing team exists — the engine already emits `GlyphSurfaceState` with staleness so the eventual widget cannot show a
stale-safe state. No claim is made that we control any third-party app's UI (Rule 18/19).

## 8. Haptics / Control Center
Haptic policy: at most a single subtle cue on a *new* strong-protection commit; no haptic on neutral/positive glyph
changes (no nagging). Control Center relation is the P006 activation toggle (single source of truth); the glyph reflects
state, it does not control activation.

## Tests
`GuardianCoreTests/GuardianGlyphTests.swift` (10): families, protection dominance, unknown-never-safe, style, medical
wording, stabilization (rapid + stable + immediate-protection), stale-never-safe.
