# P008A-R4 — Privacy Recheck

Status: source-level `VERIFIED`; device-container recheck `PENDING` (repeat after the fresh V5 run, §24).

## Design invariants (re-audited for V5 + evidence build)
- Raw `CVPixelBuffer` locked read-only, sampled in place (region aHashes + histogram + 8×8 projection reads),
  unlocked in the same call. Never copied, written, or uploaded.
- Retained state derived-only: bounded `recent` ring + baseline + step/POST windows + reliability EMAs + counters.
  No frame/image/audio retained.
- Audio ignored (`guard type == .video`). OCR OFF; segmentation does not depend on it.
- **Evidence build (§5)** logs ONLY derived scalars (`MOTION … energy/scale/disc/repl/postMs/swipe/state`) — no raw
  frames, audio, OCR text, titles, or app-private content. Release builds disable the high-volume `MOTION` logging.
- Timestamps come from `CMSampleBufferGetPresentationTimeStamp` (timing only, not content).
- Persisted telemetry = one derived text log `Documents/gen8_crossapp_proof.log` (`SEGMENT`/`MOTION`/`BROADCAST_*`,
  all `score=UNKNOWN`). No raw media, no content identity text.

## Device-container recheck after the fresh run (targets)
raw frame 0 · audio 0 · video 0 · OCR transcript 0 · content upload none · only derived `.log`.
```
xcrun devicectl device copy from --device C7C6CE6E-B577-558A-8992-DC6C1F492B39 \
  --domain-type appDataContainer --domain-identifier com.gen8.guardian.dev.GuardianBroadcast \
  --source Documents --destination ./ext_container_P008A_R4
# find ext_container_P008A_R4 -type f  → expect only *.log
```
(V3 and V4 runs both rechecked `ZERO_VERIFIED_ON_DEVICE` — only the derived log, 0 media. V5 keeps the same
discipline; the evidence build adds MORE derived scalars but still zero raw media. Confirm again on the fresh V5 run.)

## Device-container recheck RESULT (V5 fresh run, 2026-10-19) — PASS
`find /tmp/ext_container_P008A_R4 -type f` returned exactly ONE file: `gen8_crossapp_proof.log` (derived text,
194,250 bytes). Media sweep (`mp4/mov/png/jpg/jpeg/heic/wav/m4a/caf/yuv/raw`) = **0 files**.
| recheck target | result |
|----------------|:------:|
| raw frame / audio / video files | 0 / 0 / 0 |
| OCR transcript history | 0 (OCR off) |
| content upload | none (cloud=false every start) |
| persisted telemetry | derived-only `.log`; 57/57 commits `score=UNKNOWN` |
| evidence-build MOTION data | none (session ran `evidence=false`) |

Privacy gate = **PASS** (`ZERO_VERIFIED_ON_DEVICE`). The accuracy over-count (§22) is unrelated to privacy.
