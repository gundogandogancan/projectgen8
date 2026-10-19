# P009C-R1 — Cross-Language Adversarial Bank (results)

`testCrossLanguageCollisionMatrix` + `testUnknownLocaleUsesExactTokensOnBoth` (P009CR1ClosureTests) — all pass:

| Case | Result |
|---|---|
| lesson / reason / season / person / sponsor / sonar (EN) vs TR `son` | 0 hits each |
| mixed TR/EN ("my son went to the lesson", lang=en) | 0 TR hits (partitioned) |
| `son şans` phrase (TR) | hits (real token+phrase) |
| hashtags `#lesson`, usernames `@sonmez`, URLs, camelCase `LessonPlan`, `season's` | 0 hits |
| `ŞİMDİ acele` (TR uppercase, dotted İ) | hits (tr-locale lowercasing) |
| `SON` with lang=en | 0 hits (EN list has no such token) |
| NFC: decomposed `ölümcül` (combining diaereses) | hits (normalized) |
| punctuation/emoji boundaries (`hemen!`, `son😂şans`) | correct tokenization |
| suffixed TR forms (`hemens`, `şimdiki`) | 0 hits (exact tokens only — conservative) |
| TR text containing EN trigger substrings (`nevruz` vs `now`) | 0 hits |
| broken phrase (`last happy chance`) | 0 hits; contiguous `last chance` hits |
| unknown locale (nil) | exact-token on both locales; `lesson` still safe; real TR token found |

Honest framing: this bank proves MATCHING-LAW correctness, not real-world linguistic coverage. The
no-stemming limitation is declared in P009C_R1_LANGUAGE_AWARE_LEXICON.md.
