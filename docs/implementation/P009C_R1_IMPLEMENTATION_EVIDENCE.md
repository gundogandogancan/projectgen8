# P009C-R1 — Implementation Evidence

**Branch:** `phase/p009c-r1` (off locked `b648cb1`) · **Suite:** 532/532 (520 + 12 R1 closure tests) ·
**Entry verdict:** `FIX CRITICAL P009C FINDINGS`

## Atomic commits (GitHub workflow §1; push = EXTERNAL dependency, no remote configured)
| SHA | Content |
|---|---|
| `464c79d` | evidence lock: AUDIT5 originals SHA-frozen + pre-declared 3-assert inversion manifest |
| `adbc698` | F-1: typed durable semantics (DurableSemanticAtomV1/Vocabulary/PersistenceLawValidatorV2/ContentDNAPersistenceAuditorV1); entity closed-vocab canonicalization; AUDIT5 F-1 inversion |
| `7f5c78c` | F-1: vocabulary kind authoritative; 520/520 |
| `fa2049e` | F-2: LanguageAwareTokenizerV1 + LexiconMatcherV2 (locale partitioning, exact tokens/phrases, TR casing, NFC) + lexicon-v1-supplement-r1 + AUDIT5 F-2 inversion |
| `efaa05a` | F-5 cache purity gate + F-7 uncertainty monotonicity + leakage V2 + F-8 hygiene (dead condition, benchmark gating) + R1 closure tests |
| (this) | 9 R1 docs + §12 corrections + registries + audit-candidate tag |

## Finding → closure map
F-1 HIGH → closed (structural vocabulary law + full-schema fail-closed auditor; all-ingress token tests).
F-2 MEDIUM → closed (exact-token locale-partitioned matching; adversarial matrix; no-stemming limitation declared).
F-3 docs → corrected (privacy wording retracted/bounded; HELDOUT list now code-exact).
F-4 → honest status kept: STRONG_RISK multimodality reachable via temporal expert only; all arms remain
REAL_IN_PROCESS_LAB_ONLY (capability-truth test); no production observe() caller claimed.
F-5 → closed (WorldModelEvidencePurityGateV1 write+read; probe inverted).
F-6 → closed (auditor covers EVERY FinalContentDNAV1 field; unknown fields fail closed).
F-7 → closed (strength-derived episode/epistemic uncertainty; OOD excluded from trusted coverage; 4-way monotonicity property tests).
F-8 → closed (dead condition fixed; benchmark writers gated behind GEN8_WRITE_BENCHMARKS=1).
F-9 → leakage V2 (shingles/templates/translation-equivalent IDs/structural fingerprints; semantic-translation limitation declared).

## Eval flow (§15)
Fixes were defect closures (no threshold tuning); P009C gates re-ran green unmodified:
TUNE 21 / HELD_OUT 10 / STRESS 4 / OOD 4 failures=0; leakage V1+V2 0 violations; CAL_RESERVED untouched
(fingerprint probe green). AUDIT5 delta vs frozen original = exactly the 3 pre-declared inversions.

## Epistemic status
`F-1..F-9 CLOSED (lab) · WORLD_MODEL DEVICE-OPERATIONAL: UNVERIFIED (user-gated §16) · SCORE/GLYPH OFF ·
H1/CHILD OPEN · PUSH: blocked on missing remote (user action)`
