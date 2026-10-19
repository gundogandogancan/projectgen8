# P006B — Glyph Semantic Firewall

> A positive content glyph must NEVER override a protection / admission signal.

## 1. Two separate axes (`GuardianCore/GuardianGlyph.swift`)
- **Content character** (`GlyphContentCharacter`): `humor, learning, music, calm, creativity, entertainment, neutral,
  none`. Describes what the content *is*. Never a safety claim.
- **Guardian / admission state** (`GlyphGuardianState`): `strongProtection, shieldMatch, cautionConflict, unknown,
  analyzing, aligned`. Safety-bearing.

## 2. Firewall precedence (`GuardianGlyphEngine.primaryFamily(content:guardian:)`)
```
STRONG_PROTECTION  >  SHIELD_MATCH  >  CAUTION / CONFLICT  >  UNKNOWN / ANALYZING  >  CONTENT CHARACTER
```
Content character is shown **only** when the guardian axis is `aligned`. Any non-aligned guardian state wins.
Example (tested): a humorous video matching a hard Shield rule renders **"Matches your Shield" / 🛡️**, never 🙂.

## 3. Guardian axis derivation (006B §1 respected)
`guardianState(for:)` maps Shield match states honestly:
- explicit strong protection → `strongProtection`
- `MATCH_EXACT/HIGH/MEDIUM` → `shieldMatch`
- `EVIDENCE_CONFLICT` → `cautionConflict`
- `MATCHABILITY_UNKNOWN` / `MATCHER_UNAVAILABLE` → `unknown`
- `NO_MATCH`/`MATCH_LOW` with low coverage or low engine confidence → `unknown`; else `aligned`

## 4. Wording (§11) — plain, non-diagnostic, no "healthy" claim
`Humor · Learning · Calm · Music · Creativity · Entertainment · Caution · Matches your Shield · Strong protection ·
Unknown · Analyzing · Neutral`. A test bans diagnostic/medical terms **and** the word "healthy" from every label.
`GlyphToken.isTruthfulSafeClaim` is false for `unknown`/`analyzing`; `isProtectionSignal` is true for the guardian
families so the UI can enforce the firewall at render time too.

## 5. Dynamic Island ordering & stale safety (§12) — `GlyphSurfaceState` + `GlyphSurfaceController`
Surface state carries `contentID` + monotonic `sequence` + `staleAfterNanos`. The controller:
- rejects an **out-of-order** lower-sequence update for the same content (keeps current),
- on a **content change** (`contentChanged`) immediately shows `analyzing` (app-controlled truth — never a stale
  positive),
- treats a **delayed update for old content** (lower sequence, different id) as `unknown` — never the old positive glyph,
- `invalidate()` (app paused / Guardian off) → `unknown`,
- `render(now:)` past `staleAfterNanos` → `unknown` (never stale-green).
All four scenarios (A→B switch, delayed A after B, paused/off, stale) are covered by `testGlyphSurfaceOrderingSafety`.

## 6. Relation to Guardian Visual Constitution
This firewall is the binding rule behind the Pure Bar / glyph surfaces: the protection/admission axis always has display
priority over content-character cues. See `docs/design/GUARDIAN_VISUAL_CONSTITUTION.md` (updated for 006B).
