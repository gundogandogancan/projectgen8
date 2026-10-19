# P007B — TR/EN Speech Device Eval

## State
- The app target links GuardianCore + GuardianIntelligence only (NOT GuardianMedia), and has no UI to trigger
  file transcription on device. So on-device TR/EN transcription was **not exercised through the installed app**.
- The real on-device adapter (`SpeechTranscriberV3`, GuardianMedia) + its honest probe exist and are LAB-proven:
  on the lab host the probe returns `BLOCKED_NOT_AUTHORIZED` (no on-device assets/authorization), never a fake transcript.

## To obtain device speech evidence (pending)
Link GuardianMedia into the app (or an on-device test target), add a debug action to run the project-owned TR/EN/noisy/
code-switching fixtures through `SpeechTranscriberV3` on the device, and record probe verdict + transcript + WER/CER +
latency + locale/asset state. On-device assets may require explicit, system-managed download.

## Status
`DEVICE_SPEECH_NOT_EXERCISED (no in-app trigger / GuardianMedia not linked to app); LAB adapter honest-UNAVAILABLE stands`.
No silent cloud; no microphone permission used.
