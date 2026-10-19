# PROMPT P009C-R1 — PRIVACY PERSISTENCE LAW + LANGUAGE-AWARE LEXICON FIX

**RECOMMENDED MODEL:** Claude Fable
**EFFORT:** High / maximum practical reasoning
**MODEL SWITCH:** `/model` → Fable
**VERIFY:** `/status`

## 0. ENTRY VERDICT
Independent P009C audit verdict:
`FIX CRITICAL P009C FINDINGS`

Binding findings:

### F-1 HIGH — durable DNA privacy leak
A unique token inserted into `visualLabels` can persist into durable ContentDNA as `entity:object:<token>`.
Reported root path:
- persistence whitelist accepts `entity:` prefix
- EntityGraph canonicalizes provider label text directly
- sanitizer does not restrict durable entity vocabulary
- previous planted-token test covered OCR only

### F-2 MEDIUM — cross-language substring false match
English `lesson` matches Turkish urgency token `son`, contaminating manipulation/topic semantics.

Additional audit findings:
- privacy docs overclaim impossibility
- HELDOUT docs misdescribe content
- STRONG_RISK_DOMINANT production path remains only partially wired / honestly limited
- WorldModelCache lacks foreign-evidence purity gate
- persistence whitelist covers only a subset of DNA fields
- uncertainty aggregation has optimistic MIN behavior
- leakage auditor misses cross-language near-duplicates
- benchmark JSON churn/dead-test hygiene issue

P009D remains CLOSED until re-audit PASS.

## 1. GITHUB DISCIPLINE
Use `GEN8_GITHUB_EVIDENCE_WORKFLOW_v1.0.md`.

Create branch:
`phase/p009c-r1`

Do not work directly on locked main.

For each atomic fix:
- focused tests
- commit
- push
- record SHA

Before audit:
- full suite green
- clean tree
- push all
- create tag `gen8-p009c-r1-audit-candidate`
- report exact SHA/tag

Do not amend/squash audited commits after audit starts.

## 2. LOCK AUDIT EVIDENCE
Preserve:
- P009C audit report
- AUDIT5 probes
- commit `b648cb1`
- implementation commit `aaa0cf6`
- all prior locked artifacts

Create `docs/audit/P009C_R1_FINDINGS_LOCK.md`.

## 3. F-1 — TYPED DURABLE SEMANTICS
Do not blacklist the planted token.

Create:
- `DurableSemanticAtomV1`
- `DurableEntityVocabularyV1`
- `PersistenceLawValidatorV2`

Separate:
A. provider/free-form semantic label = ephemeral only
B. canonical durable semantic atom = schema-controlled, versioned, non-reconstructive

Required flow:
`provider label → canonical mapper → validated durable atom`
else `UNKNOWN/UNMAPPED`.

Forbidden:
`raw provider string → entity:<raw> → durable DNA`.

## 4. FULL DNA FIELD-BY-FIELD PERSISTENCE AUDIT
Build `ContentDNAPersistenceAuditorV1`.

Recursively inspect every durable field:
- topics
- entities
- intents
- narrative representation
- temporal structures
- safety
- benefit
- manipulation
- emotional load
- contradictions
- provenance summaries
- model/taxonomy metadata
- every future string-like payload

Every field classification:
- ALLOWED_DURABLE_CANONICAL
- ALLOWED_DERIVED_NUMERIC
- ALLOWED_VERSION_METADATA
- FORBIDDEN_RAW_OR_RECONSTRUCTIVE
- UNKNOWN_SCHEMA → fail closed

No prefix-only acceptance.

Plant unique tokens through:
- visual labels
- OCR
- speech
- audio
- symbol
- entity
- topic
- intent
- contradiction reason
- provenance
- narrative/event path

No planted token may appear anywhere in final durable DNA serialization/debug form.

## 5. ENTITY GRAPH CANONICALIZATION
EntityGraph cannot persist arbitrary provider strings.

Use typed categories/canonical IDs:
- PERSON_PRESENT
- ORGANIZATION_CANONICAL_ID
- PLACE_CANONICAL_ID
- PRODUCT_CANONICAL_ID
- OBJECT_CONCEPT_ID
- ACTIVITY_CONCEPT_ID
- EVENT_CONCEPT_ID
- ABSTRACT_CONCEPT_ID
- BRAND_CANDIDATE_CANONICAL when supported

Unmapped free-form visual labels remain ephemeral/UNKNOWN.
Never infer person identity from image.

## 6. F-2 — LANGUAGE-AWARE TOKENIZATION
Create:
- `LanguageAwareTokenizerV1`
- `LexiconMatcherV2`

Requirements:
- Unicode-aware exact token boundaries
- punctuation-aware phrase matching
- locale partitioning
- Turkish case handling
- no substring matching
- deterministic multiword phrases
- cross-language canonical bridge only when explicitly invoked

Must prove:
`lesson` ≠ TR `son`.

## 7. CROSS-LANGUAGE ADVERSARIAL BANK
Add:
- lesson/reason/season/person vs `son`
- mixed TR/EN
- hashtags/usernames
- URLs
- camelCase
- apostrophes
- dotted/dotless I
- Unicode normalization
- punctuation/emoji
- Turkish words containing English trigger substrings
- EN words containing TR trigger substrings

No trigger unless valid token/phrase in correct locale.

## 8. WORLD-MODEL CACHE PURITY
Create `WorldModelEvidencePurityGateV1`.

Before write/read verify:
- evidence belongs to current item/revision
- generation matches
- provenance scope matches
- no foreign ShotID/item
- no stale evidence
- schema/model/taxonomy compatible

Foreign evidence → reject/invalidate/reanalyze.

## 9. UNCERTAINTY REVIEW
Audit all uncertainty combiners.

Adding:
- missing modality
- conflict
- OOD
- identity ambiguity

must never spuriously reduce uncertainty.

Prefer separate axes; use MAX for blocking uncertainty where appropriate.
Add monotonicity/property tests.

## 10. STRONG-RISK RUNTIME TRUTH
Either wire a real supported production/in-app path or keep it explicitly LAB_ONLY/NOT_DEVICE_PROVEN.
HUD/docs/capability matrix must match.
No capability inflation.

## 11. LEAKAGE AUDITOR V2
Extend with:
- Unicode normalization
- language-aware token shingles
- authored-template fingerprints
- translation-equivalent template IDs for same authored family
- phrase overlap
- structural event-sequence fingerprints

Do not consume CAL_RESERVED labels/content beyond allowed fingerprint metadata.

## 12. DOC CORRECTIONS
Fix:
- privacy impossibility language
- HELDOUT description
- runtime/device truth
- scenario counts
- cache purity status
- finalizer field coverage

Use evidence-bounded wording.

## 13. REPO HYGIENE
Prevent unrelated benchmark JSON churn.
Restore unrelated generated files.
Fix dead test condition.
Update .gitignore/artifact rules if needed.

## 14. TESTS
All prior tests including unmodified AUDIT5 remain green.

Add privacy tests for every ingress, recursive schema coverage, unknown future field fail-closed.
Add lexicon collision matrix and Unicode/locale cases.
Add cache foreign-evidence tests.
Add uncertainty monotonicity tests.
Add capability truth tests.

## 15. EVAL FLOW
TUNE only for legitimate defect fixes → freeze → HELD_OUT/STRESS/OOD once.
CAL_RESERVED untouched.
No threshold tuning to examples.

## 16. OPTIONAL DEVICE/HUD
If easy, physically validate:
- source banner
- real provider trace
- no raw visual label in durable DNA
- language handling on actual OCR

Do not claim DEVICE_PROVEN without proof.

## 17. REQUIRED DOCS
Create/update:
- docs/audit/P009C_R1_FINDINGS_LOCK.md
- docs/privacy/P009C_R1_PERSISTENCE_LAW_V2.md
- docs/intelligence/P009C_R1_DURABLE_SEMANTIC_ATOMS.md
- docs/intelligence/P009C_R1_LANGUAGE_AWARE_LEXICON.md
- docs/intelligence/P009C_R1_WORLD_MODEL_CACHE_PURITY.md
- docs/intelligence/P009C_R1_UNCERTAINTY_REVIEW.md
- docs/evals/P009C_R1_CROSS_LANGUAGE_ADVERSARIAL.md
- docs/evals/P009C_R1_LEAKAGE_AUDITOR_V2.md
- docs/implementation/P009C_R1_IMPLEMENTATION_EVIDENCE.md

## 18. FINAL REPORT
Return:
1. ACTIVE MODEL / EFFORT
2. GITHUB BRANCH / COMMITS / PUSH STATUS
3. AUDIT EVIDENCE LOCK
4. F-1 ROOT CAUSE
5. DURABLE SEMANTIC ATOM ARCHITECTURE
6. FULL DNA PERSISTENCE AUDIT
7. ENTITY CANONICALIZATION
8. F-2 LANGUAGE ROOT CAUSE
9. TOKENIZER / LEXICON MATCHER
10. CROSS-LANGUAGE ADVERSARIAL RESULTS
11. CACHE PURITY GATE
12. UNCERTAINTY REVIEW
13. MULTIMODAL RUNTIME TRUTH
14. LEAKAGE AUDITOR V2
15. DOCUMENTATION CORRECTIONS
16. REPO HYGIENE
17. TUNE / FREEZE
18. HELD_OUT
19. STRESS / OOD
20. PRIVACY RESULTS
21. TESTS
22. KNOWN LIMITATIONS
23. FILES CHANGED
24. AUDIT-CANDIDATE TAG / SHA
25. STATUS

Status exactly one:
`READY FOR INDEPENDENT P009C-R1 RE-AUDIT`
`FIX REQUIRED`
`BLOCKED`

Then STOP.
Do not start P009D.
