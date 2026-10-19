# P003 — Adversarial Eval v1

**Doc status:** `CANONICAL` · **Phase:** 3 · **Date:** 2026-10-18 · PROMPT 003 §24. Tracks tricky inputs and expected (non-fabricated) behavior. Implemented in `AdversarialEvalTests` + head/fusion tests.

| Adversarial case | Expected behavior | Where tested | Status |
|---|---|---|---|
| Neutral medical education | DISEASE_ILLNESS *topic* present; NOT auto-hidden (policy decides) — truth separate | `testNeutralMedicalEducationIsTopicNotHidden`, `testMDDTopicPresenceIsNotTruthClaim` | ✅ |
| Clickbait title, neutral body | intent = advertisement from CTA cues | `testClickbaitTitleNeutralBodyIntent` | ✅ |
| Turkish disaster (not EN) | TR disaster label via TR lexicon (no EN-threshold leak) | `testTurkishDisasterNotMissed` | ✅ |
| Semantic-shield alias (TR) | alias matched → high | `testShieldAliasMatch` | ✅ |
| Empty/too-short text | abstain → UNKNOWN (no guess) | `testEmptyTextAbstains`, head guards | ✅ |
| Unrelated text vs shield rule | no match → no silent hide | `testShieldNoMatchDoesNotHide` | ✅ |
| Low-confidence concept match | caution, not hide | fusion `testMediumShieldCautionNotHidden` | ✅ |
| Medical-truth vs exposure policy | truth intact; policy may still NOT_RECOMMEND | `testPositiveExposureTruthPolicySeparation` | ✅ |
| **Pending** (need labeled media/real set): euphemism, misspelling, OCR noise, text-in-image, contradictory caption/image, satire, historical-violence context, false visual logo cues | documented; require golden-v2 + H1 visual | — | ⏳ |

**False-hide / false-allow:** recorded per case; abstentions never counted as hidden positives (eval harness). Pending cases are explicitly NOT claimed as passing.
