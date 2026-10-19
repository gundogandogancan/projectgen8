# P008A-R2 — Privacy Recheck

Status: source-level `VERIFIED`; device-container recheck `PENDING` (repeat after the fresh V3 run, §19).

## Design invariants (unchanged by V3, re-audited in source)
- Raw `CVPixelBuffer` is locked read-only, sampled in place, and unlocked in the same call
  (`multiRegionSignature`). It is never copied to a persistent buffer, never written to disk, never uploaded.
- The only retained state is derived: a `MultiRegionSignature` (6×UInt64 + 4 ints) for `prev`, a ≤12
  rolling `Double` window, and integer counters. No frame, no image, no audio buffer is kept.
- OCR is OFF in the extension (no text transcript produced or stored). Boundary correctness does not
  depend on OCR (held-out passes with OCR disabled).
- Audio sample buffers are ignored (`guard type == .video`). No audio file is created.
- Persisted telemetry = a single derived text log `Documents/gen8_crossapp_proof.log` (counters + the
  derived `TRANSITION`/`BROADCAST_*` lines, `score=UNKNOWN`). No raw media, no OCR text.

## Expected device-container state after the fresh run (recheck targets)
- raw frame files = 0
- audio files = 0
- video files = 0
- OCR transcript history = 0
- content upload = none (no network egress of content)
- only derived telemetry present

## Recheck command (run after the user's session)
```
xcrun devicectl device copy from --device C7C6CE6E-B577-558A-8992-DC6C1F492B39 \
  --domain-type appDataContainer --domain-identifier com.gen8.guardian.dev.GuardianBroadcast \
  --source Documents --destination ./ext_container_P008A_R2
```

## Device-container recheck RESULT (V3 fresh run, 2026-10-19) — PASS
`find /tmp/ext_container_P008A_R2 -type f` returned exactly ONE file:
`gen8_crossapp_proof.log` (derived text, 150,688 bytes). Media-extension sweep
(`*.mp4 *.mov *.png *.jpg *.jpeg *.heic *.wav *.m4a *.caf *.yuv *.raw`) = **0 files**.

| recheck target | result |
|----------------|:------:|
| raw frame files | 0 |
| audio files | 0 |
| video files | 0 |
| OCR transcript history | 0 (OCR off) |
| content upload | none (cloud=false logged every start) |
| persisted telemetry | derived-only `.log` (counters + `TRANSITION`/`BROADCAST_*`, all `score=UNKNOWN`) |

Privacy gate = **PASS** on the real V3 session. (Note: the accuracy failure in §16 is unrelated to privacy —
the engine over-committed but never persisted any raw media or score.)
