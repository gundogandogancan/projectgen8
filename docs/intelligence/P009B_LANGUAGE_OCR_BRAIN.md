# P009B — Language/OCR Brain (`LanguageOCRExpertV1`)

**Availability:** REAL_BUT_LAB_ONLY · **Cost:** 3 · **File:** ExpertArmsV1.swift

- **Provider reuse:** consumes OCR text from the P002 Vision OCR provider and language ID from the P003
  `NLTextSignalProvider` path; lexical analysis uses the REAL P003 `Lexicons` (TR+EN:
  mortality, diseaseIllness, disaster, severeAccident, warConflict, medicalHospital, urgency, scarcity,
  fear, anger, repeatedCTA, clickbait). No duplicate lexicons were written.
- **Output labels:** `language:<code>`, `topic:mortality|disease|disaster`, `pattern:manipulation-language`,
  `pattern:emotional-language`.
- **Honest abstention:**
  - non-TR/EN input → `UNSUPPORTED_LANGUAGE`, calibrationStatus `.unavailable`, no topic guessing
    (tested: `testOCRUncertaintyAndUnsupportedLanguage`, corpus `unsupported-language`).
  - noisy/garbage OCR (low alphanumeric ratio) → confidence 0.2, `oodIndicator=true`, no topic labels
    (corpus `noisy-ocr` forbids `topic:`).
- **Privacy:** raw OCR text is never copied into evidence labels (asserted: `testEvidencePrivacyDerivedOnly`).
