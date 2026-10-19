# P009C — Privacy

## Privacy classes (§20) — `WorldModelPrivacyClassV1`
EPHEMERAL_RAW_INPUT / DERIVED_EPHEMERAL / DERIVED_CACHEABLE (live world model) /
PERSISTABLE_NONRECONSTRUCTIVE (final DNA) / FORBIDDEN_PERSISTENCE. Only the non-reconstructive class may
enter durable DNA (`mayEnterDurableDNA`).

## Proven laws (tests) — R1 CORRECTED WORDING (audit F-1/F-3)
- ~~"Raw leak impossibility"~~ RETRACTED as overclaim: the original guarantee covered OCR-planted tokens
  only, and the prefix whitelist let a `visualLabels` token persist as `entity:object:<token>`
  (audit F-1, probe-proven). R1 closes it with a STRUCTURAL law, stated with bounded wording:
  **for every tested ingress** (visual labels, OCR, speech, audio classes, symbols, direct entity
  observation, expert provenance, free-form expert labels) planted tokens cannot reach durable DNA,
  because durable strings must be closed-registry canonical atoms or strict-grammar metadata
  (`PersistenceLawValidatorV2`), the FULL payload is audited field-by-field with unknown fields failing
  CLOSED (`ContentDNAPersistenceAuditorV1`), and unmapped entities stay ephemeral
  (`DurableEntityVocabularyV1`). See `P009C_R1_PERSISTENCE_LAW_V2.md`.
- `EpisodeObservationV1.sourceText` is EPHEMERAL (context-tag heuristics only); episodes/DNA carry
  canonical labels, never the text.
- No person identification, no sensitive traits (entity-graph structural guards, tested).
- World-model cache: confirmed identity only, TTL + eviction, collision/revision/generation invalidation;
  provisional models never cached.
- No network (GuardianCore unchanged — zero networking); no hidden persistence; bounded everything (§21).
- Emotional load describes CONTENT, never the user.

## Carried
C2 App Group, proof-log beta decision, child policy contract-only — unchanged, restated in open blockers.
