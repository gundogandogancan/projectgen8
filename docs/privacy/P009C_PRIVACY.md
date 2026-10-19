# P009C — Privacy

## Privacy classes (§20) — `WorldModelPrivacyClassV1`
EPHEMERAL_RAW_INPUT / DERIVED_EPHEMERAL / DERIVED_CACHEABLE (live world model) /
PERSISTABLE_NONRECONSTRUCTIVE (final DNA) / FORBIDDEN_PERSISTENCE. Only the non-reconstructive class may
enter durable DNA (`mayEnterDurableDNA`).

## Proven laws (tests)
- **Raw leak impossibility:** a unique token planted in OCR text never appears in any finalized DNA
  field (`testRawTextCannotLeakIntoDurableDNA`); additionally EVERY durable string must match the
  canonical-form whitelist (`WorldModelPersistenceLawV1`) or finalization refuses with `privacyViolation`.
- `EpisodeObservationV1.sourceText` is EPHEMERAL (context-tag heuristics only); episodes/DNA carry
  canonical labels, never the text.
- No person identification, no sensitive traits (entity-graph structural guards, tested).
- World-model cache: confirmed identity only, TTL + eviction, collision/revision/generation invalidation;
  provisional models never cached.
- No network (GuardianCore unchanged — zero networking); no hidden persistence; bounded everything (§21).
- Emotional load describes CONTENT, never the user.

## Carried
C2 App Group, proof-log beta decision, child policy contract-only — unchanged, restated in open blockers.
