# GEN8 Controlled Reels Player — App Review Note (short)

_Last updated: 2026-10-24. Scope: the first real in-app filtering experience. This is a reviewer-facing note, not a documentation tour._

## What GEN8 does in its OWN player
In the **Kontrollü Oynatıcı** (Controlled Reels Player) tab, GEN8 plays **our own local, app-generated videos** on our own `AVPlayer`. Before the user is exposed, GEN8 analyses the content it is about to show (on-device Apple Vision OCR over the opening frames of the local file) and applies the user's own personal-shield rules:
- **No match → the video plays** (real image + audio).
- **A real, confident match to a user rule → the video is hidden**: the `AVPlayer` is paused, audio is muted/removed, the video layer is detached, and an opaque Guardian cover is shown (no last-frame or thumbnail leak). The cover offers: *Atla · Yine de göster · Kuralı düzenle · Neden gizlendi?*
- **Insufficient evidence → an explicit "we're not sure" decision screen.** UNKNOWN is never auto-played as "safe" and never scored.

Because this content is app-owned and local, the hide/skip actions **genuinely execute** here. No 0–100 score is ever produced or shown.

## What GEN8 can and cannot do in OTHER apps
For third-party apps (e.g. a social feed), GEN8 uses the **ReplayKit broadcast upload extension** — the only official iOS whole-screen path. There it performs **permitted, user-initiated analysis and surfaces a WARNING only**. It does **not** hide, pause, auto-swipe, or control another app's feed, and it uses **no private API**. This limit is stated honestly in the UI and in the "Neden?" explanations ("…başka bir uygulama olduğu için içeriği gizleyemeyiz; yalnızca uyarıyoruz").

## Permission flow
- The controlled player needs **no special permission** — it plays local app content and runs on-device Vision OCR in-process.
- Cross-app observation requires the user to **start a system broadcast** (the iOS red-bar screen broadcast), which the user explicitly initiates and can stop at any time. The system broadcast indicator is the user's observation cue.

## Personal data — where and how much
- Personal shield **rules** are stored **on-device only**, in the app's App Group container (file protection complete). They are user-editable and fully deletable ("Tüm kuralları sil").
- **Raw frames / screen recordings are never persisted.** Pre-exposure analysis uses ephemeral decoded frames (released immediately); only derived text/decision metadata is used, and sensitive content is not stored beyond the live evaluation.
- No private user activity enters any training pool; no cloud fallback for the on-device OCR/Speech paths.

## How a reviewer tests the first filtering experience
1. Launch the app → enter **GuardianLab'e gir**.
2. Open the **My Shield** tab → add a rule: text `spoiler`, action **Hide** (or use "Örnek kurallarla başla" on a fresh install).
3. Open the **Reels** tab. GEN8 generates three local demo clips and evaluates each **before** playing:
   - "Calm cooking b-roll" → **plays**.
   - "Season finale reaction" (its frames contain the word *SPOILER*) → **hidden** (paused + muted + covered) with the Guardian shield.
   - "Unlabeled clip" (no legible early text) → **explicit decision screen** (UNKNOWN, not auto-played).
4. Tap **Yine de göster** on the hidden clip → it plays (override is scoped to that clip only).
5. Go back to **My Shield**, change the rule, return to **Reels** → the current clip re-evaluates **live** (no restart).

## ScreenCaptureKit eligibility (brief, non-blocking)
`ScreenCaptureKit` is primarily a **macOS** capture API; on iOS the supported cross-app capture path remains the **ReplayKit broadcast extension**, which is what GEN8 uses. If/when a first-party iOS capture surface with comparable, review-safe guarantees becomes available, GEN8's cross-app analysis could migrate to it — but this is **not required** for the controlled player, which depends on neither ReplayKit nor ScreenCaptureKit (it analyses its own in-process `AVPlayer` content). No capability is promised that the platform does not support.
