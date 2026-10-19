# P008A-R3 — Privacy Recheck

Status: source-level `VERIFIED`; device-container recheck `PENDING` (repeat after the fresh V4 run, §29).

## Design invariants (re-audited in source for V4 + calibration mode)
- Raw `CVPixelBuffer` locked read-only, sampled in place (region aHashes + histogram + 16×16 projection reads),
  unlocked in the same call (`segmentFrame`). Never copied to a persistent buffer, written to disk, or uploaded.
- Retained state is derived only: a bounded `recent` ring (≤40) of `SegmentFrameV4` (6 UInt64 + two 16-elt Double
  vectors + 4 ints), a ≤40 motion-energy baseline, a ≤8 POST buffer, 6 reliability EMAs, counters. No frame/image/audio.
- Audio sample buffers ignored (`guard type == .video`). OCR OFF. Segment correctness does not depend on OCR.
- **Calibration mode (§13)** logs ONLY derived scalars (`CALIB f=… energy=… scale=… normJump=… state=… mode=…`) —
  no raw frames, audio, OCR text, or content titles. No reconstructive features persisted (§14).
- Persisted telemetry = one derived text log `Documents/gen8_crossapp_proof.log` (`SEGMENT`/`CALIB`/`BROADCAST_*`,
  all `score=UNKNOWN`). No raw media, no content identity text.

## Device-container recheck after the fresh run (targets)
raw frame files 0 · audio 0 · video 0 · OCR transcript 0 · content upload none · only derived `.log`.
```
xcrun devicectl device copy from --device C7C6CE6E-B577-558A-8992-DC6C1F492B39 \
  --domain-type appDataContainer --domain-identifier com.gen8.guardian.dev.GuardianBroadcast \
  --source Documents --destination ./ext_container_P008A_R3
# find ext_container_P008A_R3 -type f  → expect only *.log
```
(Prior V3 run's container recheck was `ZERO_VERIFIED_ON_DEVICE` — only the derived log, 0 media; V4 keeps the same
discipline. Confirm again on the fresh V4 session.)

## Device-container recheck RESULT (V4 fresh run, 2026-10-19) — PASS
`find /tmp/ext_container_P008A_R3 -type f` returned exactly ONE file: `gen8_crossapp_proof.log` (derived text,
175,011 bytes). Media sweep (`mp4/mov/png/jpg/jpeg/heic/wav/m4a/caf/yuv/raw`) = **0 files**.
| recheck target | result |
|----------------|:------:|
| raw frame / audio / video files | 0 / 0 / 0 |
| OCR transcript history | 0 (OCR off) |
| content upload | none (cloud=false every start) |
| persisted telemetry | derived-only `.log`; all 73 commits `score=UNKNOWN` |
| calibration data | none (session ran `calibration=false`) |

Privacy gate = **PASS** on the real V4 session (`ZERO_VERIFIED_ON_DEVICE`). The accuracy over-count (§26) is
unrelated to privacy — the engine over-committed but persisted no raw media and no numeric score.
