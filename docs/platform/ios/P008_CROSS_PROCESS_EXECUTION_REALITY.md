# P008 — iOS Cross-Process Execution Reality (HARD GATE, §31)
Audited; do NOT architect production around unreliable paths.
- **ReplayKit Broadcast Upload Extension** (only official cross-app capture): runs in a SEPARATE process with a tight
  (~50 MB) memory budget. Reliable: cheap perceptual/boundary detection, deterministic Shield/admission, light text.
  Unreliable/unsafe at scale: heavy Vision/VLM on broadcast frames → must stay EXTENSION_FAST_PACK only.
- **Containing app while another app is foreground:** NOT guaranteed meaningful background compute. Do not assume app-side
  heavy models run live during an external-app broadcast.
- **Official IPC / shared container:** App Group (shared container, Darwin-notify payloads) is the sanctioned mechanism —
  but **App Groups require a PAID Apple Developer Program** (proven BLOCKED on the current free team in P007B). Without it
  the extension↔app handoff and cross-process Live Activity update are **BLOCKED_PENDING_PAID_APP_GROUP**.
- **ActivityKit update context:** `Activity<T>.activities` is per-process; the broadcast extension cannot update the app's
  Live Activity without App Group / push token (paid). The extension computes + logs the stabilized state; it cannot push
  the Dynamic Island live on the free team.
## Gate verdict
Cross-app CAPTURE + cheap in-extension understanding = REAL + installed. Cross-process HANDOFF to app pipeline +
live Dynamic Island score/glyph = BLOCKED pending paid App Group. Full iOS cross-app intelligence is NOT claimed until
that handoff is available. This is a hard, documented boundary — not worked around.
