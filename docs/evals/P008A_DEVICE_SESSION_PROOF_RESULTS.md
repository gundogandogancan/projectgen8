# P008A — Real Device Automatic-Guardian Session Proof (REAL, 2026-10-19)
Source: user-consented ReplayKit broadcast on iPhone 14 Pro Max (iPhone15,3, iOS 26.6). Evidence pulled derived-only via
`devicectl device copy from` the broadcast-extension container → `Documents/gen8_crossapp_proof.log` (30 KB). No raw
frame/audio taken or persisted. Instagram: ~20 real content items changed, then app-switches and back, then stopped.

## Sessions (interruption → one-tap restart observed)
- Session 1: frames=525, changes=111, analyzed=44, heavy=44, reuse=0 → FINISHED
- Session 2: frames=3033, changes=295, analyzed=124, heavy=120, reuse=4 → FINISHED
- Two BROADCAST_STARTED/FINISHED pairs = one interruption (app-switch/back) requiring a one-tap restart (iOS ONE_TAP_RESTART, as predicted).

## Audited fields (REAL, from the log)
| Field | Value |
|-------|-------|
| content transitions (boundary triggers) | 406 (111 + 295) |
| contents analyzed | 168 (heavy 164 + reuse 4) |
| cache reuse | 4 |
| heads invoked | per-frame cheap aHash change-detector (×3558); deterministic Shield+Admission (×168). NO OCR/Vision/semantic in-extension. |
| firstTrustworthyMs | n=164, **p50=0.079 ms, p95=0.185 ms, max=1.276 ms, min=0.049 ms** |
| scoreOrUnknown | **UNKNOWN for all 164** (correct: no OCR/calibration in-extension → no number) |
| confidence/coverage | minimal in-extension coverage → score gate → UNKNOWN (no uncalibrated number) |
| manual actions | 2 (one Start tap per session; the 2nd = restart after interruption) |
| interruption / recovery | 1 interruption → 1 one-tap restart |
| raw media persisted | **0** (container holds only the derived .log; no .mp4/.caf/.jpg/.mov) |

## PASS sub-items (confirmed on real hardware)
- **Privacy (§24):** extension container inspected → ONLY `Documents/gen8_crossapp_proof.log`; zero media files; log header `ephemeral=true persistToDisk=false cloud=false`. No content/training upload path.
- **Automatic-session (§22):** within each session, hundreds of content transitions auto-observed; Gen8 NEVER reopened per item; only the Start tap was manual.
- **Session recovery (§23):** interruption → one-tap restart, exactly as the iOS capability truth table states (no silent resume claim).
- **UNKNOWN gating:** every analyzed real-Instagram item → UNKNOWN (no uncalibrated score shown).
- **Fast-path latency (§16):** in-extension first-trustworthy p95 = 0.185 ms (deterministic cheap path), real device.

## FAIL / incomplete (why this device proof is FIX REQUIRED)
- **Content-boundary accuracy on real moving video:** the SHIPPED extension uses the P007D cheap aHash `ContentChangeDetector`
  (not the P008A `ContentBoundaryV2`). On real moving Instagram video it OVER-DETECTED: **124 analyzed vs ~20 real items**
  (and 406 transitions). High false-new-content rate. The fix (ContentBoundaryV2: layout + OCR-persistence + hysteresis)
  EXISTS in code + is lab-tested, but is NOT yet wired into the broadcast extension on the device.
- **Resource evidence (§16):** CPU / memory high-water / thermal / energy were NOT captured (no Instruments trace this
  run; SampleHandler logs only latency + counters) → `DEVICE_EVIDENCE_INSUFFICIENT` for those.
- **Surface delivery (§17):** scores/glyph still computed extension-local only; Dynamic Island live update remains BLOCKED_PENDING_PAID_APP_GROUP.

## Verdict for THIS device proof
`FIX REQUIRED` — privacy / automatic-session / recovery / UNKNOWN-gating / sub-ms latency PASS on real hardware; but
boundary over-detection (ContentBoundaryV2 not deployed to the extension) + missing CPU/memory/thermal evidence must be
closed, then re-run. No uncalibrated score was produced.
