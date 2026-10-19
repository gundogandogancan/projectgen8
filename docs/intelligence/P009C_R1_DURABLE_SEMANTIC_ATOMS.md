# P009C-R1 — Durable Semantic Atoms (`DurableSemanticAtomV1` / `DurableEntityVocabularyV1`)

Two string classes, structurally separated (F-1 architecture):

**A. Provider/free-form semantic label** — EPHEMERAL ONLY. Lives in `ExpertInputV2`, mesh evidence
labels, `EntityNodeV1.ephemeralLabel`, HUD/lab display. Never serialized durably.

**B. Canonical durable semantic atom** — schema-controlled, versioned (`durable-entity-vocab-v1`),
non-reconstructive. Typed kinds: PERSON_PRESENT, ORGANIZATION/PLACE/PRODUCT_CANONICAL_ID,
OBJECT/ACTIVITY/EVENT/ABSTRACT_CONCEPT_ID, BRAND_CANDIDATE_CANONICAL. Produced ONLY by the closed
mapper; the vocabulary is authoritative for an atom's kind (e.g. `classroom` = PLACE).

`EntityNodeV1.durableAtomID: String?` — nil marks ephemeral/UNKNOWN nodes; the DNA finalizer persists
`compactMap { $0.durableAtomID }` only. Unmapped nodes keep text-free canonical IDs
(`entity:unmapped:<kind>#n`). Person identity from images remains structurally impossible (presence-signal
whitelist + forbidden-fragment guard unchanged). Vocabulary growth = new vocab version → DNA supersede
(taxonomy/model-change revision law applies).
