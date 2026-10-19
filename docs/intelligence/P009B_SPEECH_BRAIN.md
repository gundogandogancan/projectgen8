# P009B — Speech Brain (`SpeechExpertV1`)

**Availability:** REAL_BUT_LAB_ONLY · **Cost:** 6 · **File:** ExpertArmsV1.swift

- **Provider reuse:** consumes transcripts from the real P005 `SpeechTranscriberV3`
  (GuardianMedia, on-device SFSpeechRecognizer) via `ExpertInputV2.speechTranscript` +
  `speechAvailable`. The honest-UNAVAILABLE pattern from P005 is preserved: recognizer not granted /
  not on-device / no audio → `speechAvailable=false`.
- **Unavailable law:** `speechAvailable == false` → explicit `.unavailable(reason: "speech-recognizer-unavailable")`,
  never an empty-transcript guess (tested: `testSpeechUnavailableHonest`; corpus `speech-only` expects
  abstention from absent modalities).
- **Output:** `speech:present` + lexical topic evidence over the transcript using the same real P003
  lexicons as the OCR brain (one lexicon source of truth).
- **Privacy:** transcripts stay in the input bundle; evidence carries labels only.
