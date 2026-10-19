# P009C — ContentDNA Finalization + Revision (`ContentDNAFinalizerV1`)

## Finalization gates (§13 — every one re-verified in the finalizer, tested)

authoritative `IdentityResolutionSnapshotV1` (confirmed + APP_FULL_TIER1 authority — the R1 F7 law) ·
current generation (model AND snapshot) · no unresolved split/merge, no strongNew/conflict ·
model readiness + confirmed status · NO provisional-marked evidence (evidence-level, not caller claims) ·
item/revision/generation subset checks (no foreign/cross-generation evidence) · provenance + episodes
exist (structural integrity) · minimum evidence quality (0.25) · **persistence law**: every durable
string must be a canonical form (`WorldModelPersistenceLawV1`) — raw OCR/transcript text is structurally
refused (`privacyViolation`), proven by the planted-token leak test.

Refusals are typed: notAuthoritative / staleGeneration / unresolvedSplitMerge / insufficientEvidence /
provisionalEvidence / structuralCorruption / privacyViolation / foreignEvidence.

## DNA payload

concept IDs, canonical entities, intent hypotheses (+ambiguity flag), narrative labels, ordered event
kinds, safety/benefit/manipulation/emotional evidence, coverage, monotone maxRisk, uncertainty +
knowledge state, OOD, contradiction outcomes, provenance count, mesh/world-model/taxonomy versions,
`PERSISTABLE_NONRECONSTRUCTIVE` privacy class, TTL. **No raw transcript/OCR/frame/audio — by law and by test.**

## Revision (§14 — tested `testDNAFinalizeHappyPathAndRevisions`)

States: CANDIDATE → CONFIRMED → REVISED / INVALIDATED / SUPERSEDED.
Triggers: new strong evidence → REVISED · identity split/merge → INVALIDATED · model/taxonomy version
change → SUPERSEDED · stale cache → INVALIDATED · validated local correction → REVISED.
`auditTrail` is append-only provenance of every transition.
