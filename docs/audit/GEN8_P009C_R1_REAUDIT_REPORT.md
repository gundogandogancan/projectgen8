# GEN8 — INDEPENDENT P009C-R1 RE-AUDIT REPORT
## Privacy persistence law + language-aware lexicon closeout — fresh-context verification

**Mandate:** `docs/audit/prompts/GEN8_INDEPENDENT_P009C_R1_REAUDIT.md` · **Date:** 2026-10-19
**Audited tag:** `gen8-p009c-r1-audit-candidate` = `28a17e11838c62752430c425f13b6e1e1cc3dc5c` (branch `phase/p009c-r1`)
**Prior verdict entering:** `FIX CRITICAL P009C FINDINGS` (report `GEN8_P009C_INDEPENDENT_AUDIT_REPORT.md`, SHA `fe04cfcb…` — byte-intact)

---

## 1. AUDITOR SESSION
Fresh clean session, no builder context inherited. Read-only first; all mandatory checks 1–10 executed;
10 fresh adversarial probes authored ADD-ONLY in
`packages/GuardianKit/Tests/GuardianCoreTests/AUDIT6_P009CR1Probes.swift` with the auditor's OWN unique
tokens (`gw7…` family — never the builder's fixtures, so any fixture-token blacklist would be useless;
none exists: the only "blacklist" strings in Sources are comments stating the law is NOT a blacklist).
No production source or existing test was modified — zero probes required a source change.

## 2. GIT / REPO INTEGRITY — **VERIFIED**
- `git rev-parse gen8-p009c-r1-audit-candidate` = `28a17e1…c3dc5c`; `git describe --tags` = tag exact; HEAD = tag; tree clean before probing.
- Prior locked commits ALL ancestors, history unrewritten: `b648cb1` ✓ `aaa0cf6` ✓ `42b96a2` ✓ `4ce238f` ✓.
- Prior locked artifacts byte-identical across the R1 range (AUDIT2/3/4 probe files, AUDIT3 frozen copy,
  P009B re-audit report, P009B/P009C findings locks; P009C audit report SHA matches the lock doc).
- `git remote -v` EMPTY — push is an honestly-declared EXTERNAL_EXECUTION_DEPENDENCY (stated identically
  in `P009C_R1_FINDINGS_LOCK.md`, implementation evidence, and open blockers). Not rewritten history.
- R1 delta `b648cb1..28a17e1` is 35 files, all R1-scoped (new law sources, lexicon V2, purity gate,
  closure tests, 9 docs, the 3 pre-declared AUDIT5 inversions, benchmark-writer gating). The two
  benchmark JSONs in the delta are the F-8 restorations; after TWO full suite runs under this audit the
  tree stayed clean — **benchmark churn is gone** (writers gated behind `GEN8_WRITE_BENCHMARKS=1`).

## 3. ORIGINAL AUDIT REGRESSION — **DELTA = MANIFEST, EXACTLY**
- Frozen original `docs/audit/AUDIT5_P009CProbes_ORIGINAL_LOCKED.swift.txt` SHA-256 =
  `97ec7e22e391d60d443bae4ea988d4cd40542c19583b324082e8acdd88b3cdcf` — matches the lock doc.
- `diff frozen ↔ active AUDIT5_P009CProbes.swift` = exactly THREE hunks, each annotated
  `// P009C-R1 FIX INVERSION`, matching the pre-declared manifest in `P009C_R1_FINDINGS_LOCK.md`:
  F-2 probe (urgency/manipulation asserts flipped + education-intact strengthening), F-1 probe
  (leak asserts flipped + `isLawfulDurable` rejection + mapped-atom-persists strengthening), F-5 final
  assert (cache lookup nil + counted-rejection strengthening). Every added assert is strictly
  STRENGTHENING inside the three pre-declared probes; nothing else in the file changed; no probe
  weakened or deleted. **Nothing beyond the manifest.**
- All other 20 AUDIT5 probes run byte-identical and green.

## 4. F-1 PRIVACY VERDICT — **CLOSED (structural vocabulary law, probe-proven)**
- Law implementation verified in source: `DurableSemanticAtomsV1.swift`
  (`DurableEntityVocabularyV1` closed 24-entry map; `PersistenceLawValidatorV2` per-field closed-set /
  strict-grammar classification with NO prefix-only acceptance; `ContentDNAPersistenceAuditorV1`
  Mirror-recursive full-payload audit, UNKNOWN_SCHEMA fail-closed), enforced inside
  `ContentDNAFinalizerV1.finalize` (violation → `privacyViolation` refusal). V1 helper hardened:
  `entity:` lawful only as vocabulary members.
- **Auditor probe (fresh tokens):** planted 8 distinct `gw7…` tokens simultaneously through visual
  labels, OCR, speech transcript, audio classes, symbol glyph context, temporal/narrative topic
  annotation, direct entity observation, custom-expert free-form labels, NESTED provenance
  (`nested→inner(tok)→leaf`), feature-map KEYS, and the identity snapshot's `evidenceProvenance`.
  Finalization succeeded on the mapped semantics (law ≠ blacklist) and the FULL recursive debug
  serialization of `FinalContentDNAV1` (every stored property, any depth) contains NONE of the tokens;
  field-by-field audit clean; `entity:place:classroom` still persists. Contradiction-reason free text
  provably cannot persist (outcome enums only).
- No fixture-token blacklist anywhere in Sources (grepped).

## 5. ENTITY CANONICALIZATION — **VERIFIED**
- `EntityGraphV1.observe`: canonical ID comes ONLY from `DurableEntityVocabularyV1`; unmapped labels get
  text-free canonical `entity:unmapped:<kind>#n` with `durableAtomID = nil` (structurally excluded from
  DNA by `compactMap { $0.durableAtomID }`); raw label survives only as `ephemeralLabel` (in-memory lab
  display). Vocabulary lookup is EXACT (`"Classroom"` → nil → ephemeral). A canonical-LOOKING provider
  label (`"entity:place:evil-fake"`) is still just an unmapped ephemeral (probe-proven).
- Identity/sensitive-trait fragments structurally refused; person entities only via non-identifying
  presence signals — no image-person identity path exists (re-verified; AUDIT5 probe 3 unchanged green).

## 6. FULL DNA SCHEMA COVERAGE — **VERIFIED, FAIL-CLOSED**
- Auditor probe proves: the registered schema (14 string-like + 14 numeric/typed fields) covers EXACTLY
  the Mirror children of the live `FinalContentDNAV1` (count equality — a future field cannot hide), any
  unregistered field name classifies UNKNOWN_SCHEMA (fail closed) even for canonical VALUES, and raw text
  smuggled under registered fields is FORBIDDEN. Malformed canonical entity IDs (trailing space, case
  variants, zero-width smuggle, traversal shapes, empty tails, `entity:unmapped:…`, auditor tokens) are
  ALL rejected — membership is exact-string in a closed set.
- Honest note (INFO R1-F): version-metadata fields (`meshModelVersions` etc.) use a shape grammar; they
  are populated exclusively from code-declared constants (expert `modelVersion`), not from any content
  ingress — no content path reaches them (verified by the all-ingress probe).

## 7. F-2 LANGUAGE VERDICT — **CLOSED in the audited scope (probe-proven)**
- `LanguageAwareTokenizerV1` (NFC + locale lowercasing incl. tr_TR dotted/dotless I + Unicode
  letter/number boundaries) and `LexiconMatcherV2` (exact tokens, contiguous phrases, locale
  partitioning, unsupported locale → zero lexical claims) are wired into ALL P009C mesh lexicon paths
  (`ExpertArmsV1`, `ContradictionResolverV1`). `Lexicons.swift` word lists untouched.
- **Auditor collisions the builder did NOT list — all clean:** EN arson/prison/comparison/jettison/
  sonnet/songs/sonata/parson vs TR `son` (EN and UNKNOWN locale); EN-internal substring commonly/
  suddenly vs EN `only`; TR sonbahar/sonra/sonuç vs TR `son` (and `SONUÇ` under tr casing); decomposed
  `s+combining-cedilla imdi` matches after NFC; code-switched EN triggers (`now`, `hurry`) inert in TR
  locale; `#sonbahar @sonmez takip.et/sonuc` clean; phrase law exact (`son, şans!` hits across
  punctuation; reordered/intervening-token forms never match); `de` locale → zero claims. End-to-end: EN
  text built from auditor trap words produces NO urgency/manipulation concepts in the world model.
- Supplement `lexicon-v1-supplement-r1` is ADDITIVE legitimate vocabulary (deadly/kill/kills/ölümcül;
  threaten/threatens/threatened/tehlikeli — all genuine category members that substring matching
  previously covered by accident), not probe-fitting.
- Residual (LOW R1-D, outside audited scope): the LEGACY pre-P009C paths
  (`GuardianIntelligence/SpecialistHeads.swift` → `WholeVideoAnalyzerV1`, and offline
  `TrainingRunner.swift`) still use substring `Lexicons.hits`. They feed the earlier whole-video/score
  pipeline (score/glyph OFF, locked phases), never the world model or durable DNA. Should be migrated or
  explicitly declared when those paths are next touched.

## 8. CACHE PURITY — **CLOSED (write AND read, probe-proven)**
`WorldModelEvidencePurityGateV1` enforced in `WorldModelCacheV1.insert` (reject + counted
`purityRejections`) AND re-checked on `lookup` (evict `evidence-purity-violation`). Auditor variants all
hold: foreign-item evidence rejected on write and never servable; stale generation → `generation-mismatch`
(never silently reused); mixed revision → evict, not resurrectable; strong split/collision purge and
ambiguous-collision forced reanalysis; provisional evidence rejected; provenance scope expressed through
the evidence item/generation subset law. INFO (R1-E): the gate's `staleExcludedResidue` impurity case is
declared but never produced — stale protection actually rests on the builder's stale-evidence exclusion +
the cache's generation law (both independently probe-verified). Dead enum case, no behavioral gap found.

## 9. UNCERTAINTY — **LAW HOLDS WITH ONE BOUNDED, DOC-OVERCLAIMED CORNER (R1-A/R1-B, LOW)**
- Verified closures: episode/epistemic uncertainty now `1 − family-law strength` (per-record MIN gone);
  OOD excluded from trusted coverage (OOD-only evidence ⇒ `missingModality = 1`, probe-proven); overall
  stays MAX over axes; builder's 4-way monotonicity tests green; conflict/identity/unavailable-modality
  perturbations monotone under auditor variants too.
- **FINDING R1-A (LOW, probe-proven, `testProbe6_UncertaintyMonotonicity_AuditorPerturbations`):** a
  HIGH-confidence OOD record still feeds epistemic strength through its 0.4-discounted weight
  (`EvidenceWeigherV1.weight`), so adding an OOD record CAN reduce `overall` (measured 0.84 → 0.70) and
  flip the knowledge state UNKNOWN → AMBIGUOUS. The builder's property test sampled only a
  LOW-confidence OOD record (conf 0.1 → weight 0.032), which cannot reach the effect threshold. Bounds
  that keep this LOW: the OOD axis floor (0.5) makes KNOWN/LIKELY structurally unreachable from OOD
  addition; DNA `readiness` does not consume `overall`; score/glyph are OFF; no allow/hide consumer
  exists. **FINDING R1-B (LOW, doc truth):** `P009C_R1_UNCERTAINTY_REVIEW.md` states "(c) an OOD record
  NEVER reduces `overall`" and the implementation evidence says "F-7 → closed" — both are absolutes the
  probe disproves for the high-confidence corner. Required next-phase action: clamp OOD records out of
  epistemic strength (or floor epistemic at the pre-OOD value), or re-word the doc to the bounded truth.

## 10. LEAKAGE METHODOLOGY — **VERIFIED (one honest vacuity, declared)**
- `P009CLeakageAuditorV2` = V1 rules + Unicode/language-aware token 3-shingles (J>0.5 + template
  fingerprint), authored-template fingerprints, translation-equivalent `templateID` law, structural
  risk/topic sequence fingerprints. 0 violations on the current banks (re-run).
- Auditor detector checks: translated TR/EN twins share template fingerprints; near-template EN rewrites
  exceed the 0.5 shingle threshold; identical content → J=1.
- `templateID` is nil on EVERY current scenario (probe-verified) — the translation-equivalent law is
  authoring metadata and currently fires on nothing. The doc SAYS so explicitly ("independently authored
  ⇒ nil"; semantic near-duplication "detectable only via templateID discipline — stated, not hidden") —
  honest limitation, not an overclaim. INFO only.
- CAL_RESERVED: fingerprint `aa6bd546ae28278f` re-verified by auditor probe; bank unconsumed.

## 11. DOCUMENTATION TRUTH — **VERIFIED except R1-B above**
- Privacy overclaim RETRACTED with evidence-bounded wording (`P009C_PRIVACY.md` strikes "raw leak
  impossibility", scopes the claim to "every tested ingress" + structural law; `P009C_R1_PERSISTENCE_LAW_V2.md`
  explicitly says "not a claim about channels that do not exist yet"). Matches code exactly.
- `P009C_HELDOUT.md` bank list is CODE-EXACT (10 names verified against `P009CCorpusV1`, one-to-one).
- Counts honest: TUNE 21 / HELD_OUT 10 / STRESS 4 / OOD 4 verified in code; "532/532 (520 + 12 R1
  closure tests)" reproduced; schema-coverage claims match `ContentDNAPersistenceAuditorV1`.
- Runtime/device truth: all arms `REAL_IN_PROCESS_LAB_ONLY` (probe-verified across all 10 domains);
  STRONG_RISK via temporal only — declared verbatim in open blockers and implementation evidence;
  `WORLD_MODEL DEVICE-OPERATIONAL = UNVERIFIED` honestly carried.
- Open blockers restated for R1 (C2/C3/C4/C5, child contract-only, device proof user-gated, push
  external). The lone doc defect found is R1-B (§9).

## 12. TESTS — **542/542 GREEN**
- Full suite at the tag: **532/532, 0 failures** (reproduced twice — totals line
  `Executed 532 tests, with 0 failures`). Builder's 532/532 claim: CONFIRMED.
- With auditor probes: **542/542** (532 + 10 AUDIT6 probes), 0 failures, tree churn zero.
- P009C gates re-ran green unmodified: `P009C_TUNE scenarios=21 failures=0`, `P009C_HELDOUT scenarios=10
  failures=0`, STRESS 4 / OOD 4 failures=0; leakage V1+V2 clean; AUDIT3/4/5 regression probes green;
  F-8 dead condition fixed (language-uncertainty gate now live).

## 13. FRESH ADVERSARIAL PROBES (AUDIT6, add-only — 10/10 pass)
| # | Probe | Mandate item | Result |
|---|---|---|---|
| 1 | AlternateTokensAllIngress_FullSerializedDNATokenFree | alternate visual-token leak + nested provenance + full debug DNA | LAW HOLDS |
| 2 | ContradictionReasonAndUnknownReasonsNeverPersist | contradiction-reason ingress | LAW HOLDS |
| 3 | UnknownFutureFieldFailClosed_SchemaRegistryComplete | unknown future DNA field | FAIL-CLOSED + registry complete |
| 4 | MalformedCanonicalEntityIDsRejected | malformed canonical entity ID | ALL REJECTED |
| 5 | UnlistedCrossLanguageCollisions | collisions builder didn't list | CLEAN |
| 6 | CachePurityForeignStaleSplitVariants | cache foreign evidence | LAW HOLDS (write+read) |
| 7 | UncertaintyMonotonicity_AuditorPerturbations | uncertainty monotonicity | **FINDING R1-A (LOW, bounded)** |
| 8 | NoCapabilityOrSourceModeInflation | source-mode/capability inflation | NO INFLATION |
| 9 | CALReservedFingerprintAndLeakageV2 | leakage V2 + CAL_RESERVED | CLEAN / UNCONSUMED |
| 10 | WorldModelStillRealEndToEnd | regression: real runtime | REAL |

## 14. PRIVACY / RESOURCE — **CLEAN**
No networking in GuardianCore (grep: zero URLSession/Network). No raw-text/transcript/label persistence
in any durable field (full-dump probes). Bounded structures re-verified via unchanged AUDIT5 probe 21
(256-episode hard bound, honest overflow note). Emotional load describes content, never the user.
Benchmark artifact writes env-gated; two clean full-suite runs with zero tree churn.

## 15. DEVICE / RUNTIME TRUTH — **HONEST; NO DEVICE PROOF CLAIMED**
Build+install with semantic HUD documented; the physical owned-media HUD run remains USER-GATED and is
declared NOT completed (`P009C_DEVICE_VALIDATION.md` — "nothing fabricated"). All arms remain
`REAL_IN_PROCESS_LAB_ONLY`; score display refused by calibration gate. Judged from the re-audit spec's
own text, device proof is not a lock condition for this phase (consistent with the P009B-R1 precedent);
the user-gated run stays an open limitation, not a blocker.

## 16. OPEN LIMITATIONS (carried, all declared)
C2 App Group · C3 extension shield · C4 score calibration intentionally OFF · C5 H1 visual + child
policy contract-only · Tier-0 burst residual · proof-log beta decision · STRONG_RISK multimodality via
temporal expert only (no production `observe()` caller) · no morphological stemming (conservative) ·
translation-equivalent leakage law = authoring discipline (templateID) · world-model device-operational
UNVERIFIED (user-gated) · push blocked on missing remote (user action) · NEW: R1-A/R1-B OOD-epistemic
corner + doc wording (LOW, §9) · R1-D legacy substring matching in pre-P009C specialist heads (LOW) ·
R1-E dead `staleExcludedResidue` enum case (INFO).

## 17. VERIFIED PROGRESS
F-1 HIGH: CLOSED structurally (closed vocabulary + full-schema fail-closed auditor; 8-token all-ingress
proof). F-2 MEDIUM: CLOSED in scope (exact-token locale-partitioned matching; auditor's unlisted
collision bank clean). F-3 docs: corrected, code-exact. F-5: CLOSED (purity gate write+read). F-6:
CLOSED (full schema, registry-complete). F-7: substantially closed (one bounded corner remains → R1-A).
F-8: CLOSED (no churn, dead condition fixed). F-9: CLOSED with declared metadata-discipline limitation.
AUDIT5 inversion delta = exactly the pre-declared 3-assert manifest. Prior locks byte-intact, ancestry
unbroken. 542/542.

## 18. GO / NO-GO
Findings this re-audit: **R1-A LOW** (bounded OOD-epistemic corner; KNOWN/LIKELY unreachable; no
consumer), **R1-B LOW** (uncertainty-doc absolute wording disproven for that corner), **R1-D LOW**
(legacy out-of-scope substring paths), **R1-E/R1-F INFO**. No HIGH/MEDIUM finding; no privacy leak path;
no capability inflation; no eval-gate tampering; evidence chain intact. The two LOW items must be
addressed (one-line doc re-wording + OOD-epistemic clamp or declared bound) in the next phase's hygiene
pass — they do not endanger any current law consumer.

**VERDICT: `PASS — P009C CONTENT WORLD MODEL LOCKED; GO TO P009D`**
