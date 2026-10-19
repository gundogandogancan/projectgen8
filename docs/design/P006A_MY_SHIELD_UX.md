# P006A — My Shield UX

The user-facing surface for creating and reviewing personal shield rules, and previewing the Guardian glyph.
Implemented as the **"My Shield"** tab in GuardianLab (`Gen8/MyShieldView.swift`, `Gen8/ShieldStudioModel.swift`).

## 1. Where it lives
GuardianLab segmented control: **Short-form · Long-form · My Shield**. My Shield is gated by the same `guardianEnabled`
toggle (Guardian OFF ⇒ no evaluation).

## 2. Sections
1. **Guardian glyph preview** — live `GlyphToken` for the current sample; style picker (Minimal / Emoji / Off).
   When the glyph is not a safety claim, it shows "Not a safety claim" (truthful; never implies all-clear).
2. **Sample content** — a text field; "Evaluate" runs `ShieldEvaluatorV2` and shows `state → action`
   (hide actions are tinted to make destructive outcomes obvious before they are ever applied to real content).
3. **Add a shield rule** — label + type (Exact text / Concept / Entity / Sound class) + action (Warn / Ask / Hide).
4. **Active rules** — list with type + action, each deletable.

## 3. UX honesty rules (P0-Q)
- Hide/skip actions are only ever *previewed* against sample text here; nothing is silently removed.
- Low-confidence outcomes render as `ALLOW_WITH_NOTE` — the user sees a note, not a disappearance.
- `UNKNOWN` outcomes never render with a positive/safe glyph.
- Rule creation, edit, and delete are immediate and local; no network, no sync.

## 4. Accessibility
Minimum 44pt touch targets (`GTokens.minTouch`), text labels on every glyph, VoiceOver-friendly controls, no
color-only signaling (icon + label + text summary).

## 5. Family / Child authority (§42)
A rule's `authority` (`user` / `guardian` / `systemSafetyFloor`) governs override: a guardian-authored child rule is
**not** overridable by an ordinary user exception (`ShieldExceptionEngine` enforces this), and a system safety floor is
never overridable. The My Shield UI surfaces authority on each rule (future: separate guardian editor). This reuses the
P000A child-safety precedence (ADR-0007) — teen autonomy and guardian authority handled together.

## 6. Functional-state surfacing (006C §12)
Each rule row shows its `ShieldRuleFunctionalState` (ACTIVE / PAUSED / EXPIRED / REFERENCE_REAUTHORING_REQUIRED /
CORRUPT / MIGRATING). A rule needing re-authoring shows **"Protection unavailable — Update reference"** (tinted), the
rule is **not** silently deleted and **not** shown as active. A non-functional durable record never reads as protecting.

## 7. Status
In-app Shield Studio + My Shield: **DONE** (iOS build succeeds), now with durable persistence (006B) + functional-state
display (006C). Standalone consumer surface + guardian editor screen + image-picker ingestion UI: deferred to a later
product phase. Dynamic Island glyph surface: device-gated (see glyph system §7).
