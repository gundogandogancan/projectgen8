# DESIGN SYSTEM CONSTITUTION (P0-Q)

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** PROMPT 000A §2, §12; Bible §103, §107, §596–§612; Prompt 000 §42. Companion to `GUARDIAN_VISUAL_CONSTITUTION.md`. **P0-Q is a release gate** (D-0013): no engineering shortcut may force poor UX.

## Design principles
Minimal · elite · premium · understandable · native · calm · accessible. NASA behind, one signal in front. Prefer **native platform components** over custom reimplementations (iOS: SwiftUI system components, SF Symbols, native materials).

## Tokens (defined as semantic, values per platform)
- **Color:** semantic roles only — `aligned/beneficial` (green-teal), `informational/neutral` (cool blue), `caution` (amber), `strong-caution/do-not-watch` (soft coral), `unknown/analyzing` (grey). No neon, no rainbow, no toy gradients, no "dark/black moral" color. **Color is never the only signal** (§603) — pair with icon/shape/text/haptic.
- **Typography:** platform-native type ramp; **Dynamic Type / text scaling** supported.
- **Spacing / radius / elevation(material):** consistent scale; native materials/blur where idiomatic.
- **Motion:** subtle, premium, purposeful; **reduced-motion** honored; no attention-hijacking motion (§608).
- **Haptics:** meaningful, optional, as an accessibility alternative to color/motion.

## Light / dark behavior
Full light + dark support; semantics preserved across appearances; contrast meets accessibility floors in both.

## Components (native-first)
cards · sheets · alerts · navigation · lists · loading/skeletons · toasts. Custom components only where a native one cannot express the Guardian surface (Pure Bar / heatmap).

## Mandatory states per surface (§107)
normal · loading · empty · error · offline · degraded · permission-denied · insufficient-data · low-confidence (`?`) · stale · conflicting-evidence · retry · recovery · success · undo · accessibility-mode · localization. **Never a stale Protected state.**

## Accessibility (ACC-001; §103, §559)
VoiceOver/TalkBack/Narrator · Dynamic Type · high contrast · reduced motion · captions · keyboard/remote nav · color-independent warning semantics · the tiny Guardian surface MUST have an accessible expanded target.

## Subscription / paywall quality rules
honest, no dark patterns, no fake scarcity, no hidden subscription behavior (§110); trial state always clear; privacy/security essentials never behind the paywall.

## Child / adult visual adaptation (§590)
Role-adaptive disclosure (Adult/Teen/Child); child mode is guardian-governed; color + accessibility semantics constant across roles.

## Measurable P0-Q acceptance criteria (PROMPT 000A §2)
frame stability · animation smoothness (target device fps) · state clarity · accessibility pass · reduced-motion correctness · Dynamic Type correctness · safe-area correctness · Dynamic Island / native surface behavior · loading/error/offline/degraded coverage · **no score jitter** · **no stale Protected state**.

## Phase-0 status
Constitution only; no UI built. Enforced by UX-001 (Pure Bar + disclosure), UX-002 (P0-Q gate), ACC-001.
