# P009C-R1 — Persistence Law V2 (F-1 closeout)

## Root cause (audit F-1, probe-proven)
`WorldModelPersistenceLawV1` accepted ANY string after an `entity:` prefix; `EntityGraphV1` canonicalized
provider label text verbatim; the shipped leak test planted tokens in OCR only. A `visualLabels` token
reached durable DNA as `entity:object:<token>`.

## The V2 law (NO token blacklist — a vocabulary law)
1. **Typed durable semantics:** `DurableSemanticAtomV1` + `DurableEntityVocabularyV1` (versioned,
   CLOSED provider-label → atom map). Flow: `provider label → canonical mapper → validated durable atom`,
   else **ephemeral/UNKNOWN** (text-free canonical `entity:unmapped:<kind>#n`; raw label stays in-memory
   for lab display only). `raw provider string → entity:<raw> → durable DNA` is structurally impossible.
2. **PersistenceLawValidatorV2:** per-FIELD classification — ALLOWED_DURABLE_CANONICAL (closed registries:
   taxonomy concepts, vocabulary atoms, intent/event/emotion enums, contradiction outcomes, fixed mesh
   label literals), ALLOWED_DERIVED_NUMERIC, ALLOWED_VERSION_METADATA (strict grammars), and
   FORBIDDEN_RAW_OR_RECONSTRUCTIVE. Structured labels admit NUMERIC tails only. **No prefix-only acceptance.**
3. **ContentDNAPersistenceAuditorV1:** recursive Mirror traversal of `FinalContentDNAV1`; every string
   classified; **unregistered/unknown fields fail CLOSED** (`UNKNOWN_SCHEMA`). Runs inside `finalize()` —
   any violation refuses with `privacyViolation`.
4. V1 helper hardened: `entity:` strings lawful only as vocabulary members.

## Evidence (bounded wording — what the tests actually prove)
All-ingress planted-token tests (visual labels, OCR, speech, audio classes, symbols, direct entity
observation, expert provenance, free-form expert labels) show no planted token in any serialized durable
DNA field, and the field-by-field audit returns clean, for the tested ingress set and the current DNA
schema. This is a structural-law proof over the registered schema — future fields fail closed by design;
it is not a claim about channels that do not exist yet.
