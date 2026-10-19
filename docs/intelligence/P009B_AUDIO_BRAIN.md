# P009B — Audio Event Brain (`AudioEventExpertV1`)

**Availability:** REAL_BUT_LAB_ONLY · **Cost:** 4 · **File:** ExpertArmsV1.swift

- **Provider reuse:** consumes sound classes from the real P005/P006 SoundAnalysis provider
  (`GuardianMedia/GeneralAudioHeadV1.swift`) via `ExpertInputV2.soundEvents`.
- **Validated class set (only these are mapped):** speech, music, siren, alarm, crowd, applause,
  silence, nature, water, traffic, engine, noise. Anything else is counted as
  `audio:unsupported-classes:N` — honest, never interpreted (tested: `testAudioUnsupportedClassHonest`).
- **TUNE-discovered defect (fixed before freeze):** when ALL classes were unsupported the explicit
  `audio:no-validated-events` marker was suppressed by the unsupported-count label. Fix: the marker is
  now emitted whenever zero classes validate, alongside the count. Found by corpus scenario
  `unsupported-audio-classes` on TUNE seed 0; fix verified on HELD-OUT seed 1.
- **OOD:** unsupported > validated → `oodIndicator=true`.
- **Unavailable:** no audio provider input → `.unavailable(reason: "no-audio-provider-input")`
  (corpus `absent-audio`).
