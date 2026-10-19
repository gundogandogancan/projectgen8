# GUARDIAN VISUAL CONSTITUTION

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §596–§612 (governs), §458–§463/§579–§595 (Star, now optional), §167–§171, §300, §602–§603; Prompt 000 §3, §R. Resolution: **D-0006 (Pure Bar default supersedes persistent Star).**

## Core doctrine
**NASA behind. One signal in front.** The visible Guardian is minimal; massive intelligence stays hidden.

## Default + display modes (§597–§598)
- **DEFAULT = `PURE_BAR`** — a pure adaptive color bar, no number, no star.
- User-selectable modes:
  - `PURE_BAR` (default)
  - `BAR_SCORE` (bar + numeric when user wants it)
  - `STARLINE` (Star + line, brand-forward)
  - `HIDDEN_BACKGROUND` (no persistent surface; still protecting)
  - `AUTO` (adapts to context/surface)
- The **Star ★** is a **brand symbol, not a mandatory HUD** (§600). It remains available as a mode and as the brand mark; it is not forced to be persistently visible.
- The numeric score is **available, not forced** (§601).

## Progressive disclosure ladder (§599; Prompt 000 §3)
```
L0  PURE ADAPTIVE COLOR BAR            (default)
L1  TAP   → SCORE + SHORT STATUS
L2  EXPAND→ WHY + PROTECTION + EVIDENCE + MATCHED RULE
L3  LONG-FORM → TEMPORAL HEATMAP + FLAGGED SEGMENTS + SKIP CONTROLS
```

## Color semantics (§602; Prompt 000 §3) — and color is never the only signal (§603)
| Color | Meaning |
|---|---|
| refined green/teal | aligned / beneficial |
| restrained cool blue | informational / neutral |
| refined amber | caution |
| soft coral/red | strong caution / do-not-watch |
| grey | unknown / analyzing (`?`) |

**No neon, no rainbow cycling, no toy gradients, no attention-hijacking motion.** No black/"dark moral" classification. Every color meaning is **also** conveyed by text/icon/shape/haptic so it is accessible (ACC-001).

## Bar morphology & motion (§604, §606–§608)
- Short-form: stable bar; morph is subtle, premium, reduced-motion-aware (§608).
- Long-form: bar can morph into a **temporal heatmap** showing upcoming flagged segments (§606, L3).
- Stability engine prevents flicker/jitter; never flash a stale safe/green state (§587, §101).

## Capability-truthful presentation (hard rule)
The surface must **never show a false `PROTECTED` state** (§210, D-0004). On surfaces where we cannot pre-filter (native third-party feeds), the surface warns/analyzes and states coverage honestly — it does not imply feed control (§234, §47). `grey/?` is shown when unknown; it is **not** "safe."

## Role-adaptive (§590)
Adult / Teen / Child variants differ in disclosure and controls (child mode is guardian-governed), while color + accessibility semantics stay constant.

## Platform surfaces (capability-dependent — see PLATFORM_CAPABILITY_MATRIX)
iPhone Dynamic Island / Live Activities (pure-bar first, §605) · in-app / Safari extension where no system surface · Android edge/overlay where permitted · macOS/Windows/Linux menu-bar/tray/compact or extension · browser fixed safe-area bar · TV overscan-safe corner badge (§300) · XR peripheral ambient · Watch/Wear glance. Do not emulate unsupported cross-app overlay behavior (§5720 capability gap).

## Settings (user control — §609–§610)
Users choose display mode, numeric visibility, motion level, and per-device preference. Defaults are Pure Bar + reduced motion + color-independent signals on.

## Glyph semantic firewall (006B §10 — binding)
The Guardian glyph has TWO axes: content character (humor/learning/music/calm/…) and guardian/admission state
(strong-protection/shield-match/caution/unknown/analyzing/aligned). Display precedence is absolute:
`STRONG_PROTECTION > SHIELD_MATCH > CAUTION/CONFLICT > UNKNOWN/ANALYZING > CONTENT CHARACTER`. A positive content glyph
can NEVER override a protection/admission signal (a humorous video matching a hard Shield shows "Matches your Shield",
not 🙂). Stale / out-of-order surface state downgrades to UNKNOWN, never a stale positive. Labels are plain and
non-diagnostic (no "healthy" claim). See `docs/design/P006B_GLYPH_SEMANTIC_FIREWALL.md`.

## Phase-0 status
Design constitution only; no UI built. Implemented/proven by **UX-001** (Pure Bar + disclosure) and **ACC-001** (accessibility),
plus **GLY-001/GLY-002** (glyph engine + firewall + ordering, headless-tested).
