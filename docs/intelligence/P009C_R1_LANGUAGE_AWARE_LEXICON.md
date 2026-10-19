# P009C-R1 — Language-Aware Lexicon (F-2 closeout)

## Root cause (audit F-2, probe-proven)
`LexMatch` used lowercased substring containment across ALL locales regardless of `detectedLanguage`:
EN "les**son**" matched the TR urgency token `son`, polluting educational content with
urgency/manipulation concepts and structurally suppressing topic-shift events.

## Fix
- `LanguageAwareTokenizerV1`: NFC normalization + locale lowercasing (Turkish dotted/dotless I handled
  via `tr_TR`), Unicode letter/number word boundaries — **no substring matching anywhere**.
- `LexiconMatcherV2`: exact token matches + deterministic contiguous multiword phrases; **locale
  partitioning** — a known language consults ONLY its own term list; unknown language applies exact-token
  rules on both (never substring). Cross-language bridging happens only via the explicit taxonomy
  (`SemanticTaxonomyV1`), never inside matching.
- `lexicon-v1-supplement-r1` (versioned, additive; `Lexicons.swift` lists untouched): explicit base forms
  that substring accidents previously hid — mortality: deadly/kill/kills/ölümcül; fear:
  threaten/threatens/threatened/tehlikeli.
- Context-tag cues tokenized (emoji/punctuation cues stay character-based); `sourceLanguage` threaded
  through `EpisodeObservationV1`.

## Proven (cross-language adversarial matrix, `testCrossLanguageCollisionMatrix`)
lesson/reason/season/person/sponsor/sonar never trigger TR `son`; mixed TR/EN partitioned; hashtags/
usernames/URLs/camelCase/apostrophes safe; `ŞİMDİ`→`şimdi` (tr casing); decomposed Unicode normalizes;
broken phrases don't match; suffixed TR forms are not exact tokens (declared limitation below).

## Declared limitations
No morphological stemming: Turkish agglutinative suffixed forms ("felaketi", "dersini") do not match
their stems — matching is strictly conservative (fewer hits, never false ones). The supplement vocabulary
is the honest mechanism for adding explicit forms, versioned per addition.
