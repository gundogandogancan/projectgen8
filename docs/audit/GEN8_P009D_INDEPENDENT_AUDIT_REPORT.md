# GEN8 — INDEPENDENT P009D RED-TEAM AUDIT REPORT

**Audited tag:** `gen8-p009d-audit-candidate` = `b50f592f835ed22e0170e05c08b5721817e1d74d` (branch `phase/p009d`)
**Auditor:** independent fresh-context red-team session (no builder context inherited) · **Date:** 2026-10-20
**Mandate:** `docs/audit/prompts/GEN8_INDEPENDENT_P009D_RED_TEAM_AUDIT.md` · implementation prompt
`docs/audit/prompts/PROMPT_P009D_SAFETY_CHILD_SHIELD_POLICY_INTELLIGENCE.md`
**Method:** full code read of all P009D sources + HUD section; builder suite reproduced; 21 fresh
adversarial probes authored add-only in `Tests/GuardianCoreTests/AUDIT7_P009DProbes.swift`; zero
production source/test modifications by the auditor.

---

## 1. AUDITOR SESSION

Fresh session; builder report NOT trusted — every claim below re-derived from code, git, and test
execution. Read set: `PolicyFoundationsV1.swift`, `SafetyPolicyEngineV1.swift`,
`ChildAgePolicyEngineV1.swift`, `PersonalShieldPolicyV2.swift`, `PolicyConflictResolverV1.swift`,
`P009DPolicyCorpusV1.swift`, `P009DPolicyTests.swift`, `Gen8/GuardianIntelligenceHUD.swift` (policy
section), supporting mesh/lexicon/world-model types, all P009D docs. Suite run three times
(baseline ×2, baseline+probes ×1).

## 2. GIT / REPO INTEGRITY

- Working tree CLEAN at audit start (`git status --porcelain` empty). Post-audit churn = exactly the
  two auditor-authored files (probes + this report). Benchmark writers produced ZERO tree churn.
- `gen8-p009d-audit-candidate` resolves to `b50f592` = HEAD of `phase/p009d`. Audited at that SHA.
- Prior locks are unchanged ancestors of HEAD (verified `git merge-base --is-ancestor`):
  `0046925` (gen8-p009c-locked merge) · `b648cb1` · `aaa0cf6` · `42b96a2` · `4ce238f` — ALL OK.
- Frozen audit artifacts: `git diff 0046925..HEAD` touches NO `AUDIT*` probe file and NO
  `*_ORIGINAL_LOCKED*` snapshot ("none"). SHA-256 of `AUDIT3/AUDIT5` originals + live `AUDIT3/5/6`
  probe files recorded; byte-intact relative to the P009C lock.
- P009D delta since the lock = 3 commits (`81bc037`, `8e2fc85`, `b50f592`): new policy sources/tests/
  docs + ONE modification to a P009C-era file (`LanguageAwareLexiconV2.swift`, +2 tokens — see §3/F-1).
- **No git remote configured** — push is an honestly declared EXTERNAL_EXECUTION_DEPENDENCY
  (restated in `GEN8_OPEN_BLOCKERS.md`). Tags are lightweight; no force-push/amend evidence.

## 3. P009C REGRESSION

- All prior-phase tests green inside the 563 baseline: `P009C_TUNE 21 / HELDOUT 10 / STRESS 4 / OOD 4
  failures=0`, P009B/R1 banks green, `CAL_RESERVED fingerprint=aa6bd546ae28278f (never executed)`.
- The single P009C-source change: `LexiconMatcherV2.supplementalMortality` gains exact tokens
  `"deaths"` (EN) and `"ölümler"` (TR). **Finding AUDIT7-F1 (LOW, accepted):** this touches a locked
  P009C file post-lock, but it is inflection completion squarely inside the supplement's declared
  purpose (exact-token matching requires explicit inflections; "death"/"ölüm" were already base
  tokens), it is one of the 5 documented pre-freeze TUNE fixes, and all 542 prior tests stay green.
  Judged honest capability authoring, not tuning-to-fit. VERDICT: P009C lock preserved.

## 4. SAFETY POLICY (checks 2, 8)

- `SafetyDimensionTruthV1`: 11 dimensions, statuses truthful — sensitiveNews/manipulation
  IMPLEMENTED_UNCALIBRATED, fearThreat HEURISTIC_SUPPORT_ONLY, the other **8 UNAVAILABLE**; nothing
  IMPLEMENTED_CALIBRATED (test-asserted; re-asserted in probe P20).
- UNAVAILABLE dimensions **neither clear nor convict**: `evidencePresent` is structurally false and
  severity "none" for all 8 (engine `default:` branch); probes P2/P3/P4/P5/P6 confirm no
  explicit/self-harm/drugs/gambling/violence distinction can be invented from any input.
- Strong protection: `maxRisk ≥ 0.8` or STRONG_RISK_DOMINANT contradiction (≥0.6) escalates even with
  H1 open. Probe P1 (fresh 25× benefit-token flood + severe mortality risk, child 10, preferred-topic
  shield): STRONG_PROTECTION with `BENEFIT_PRESENT_NOT_OVERRIDING` recorded — **benefit can never
  outrank protection** (also builder stress `sd-benefit-flood-vs-strong-risk` reproduced). PASS.

## 5. H1 TRUTH (check 3)

- `HighRiskVisualSafetyRegistryV1`: 4 visual high-risk classes, each with full record fields, provider
  `NONE`, `UNAVAILABLE_EVIDENCE_BACKED`; `visuallySafeConclusionAllowed()` returns `false`
  structurally (constant).
- The `H1_VISUAL_UNAVAILABLE` reason code is appended **unconditionally** in
  `SafetyPolicyEngineV1.evaluate` and flows into every candidate's reasons. Probe P14 drove 5 route
  classes (neutral adult, strong protection, shield match, child review, provisional-identity
  unknown): the code rode EVERY decision. Attempted construction of a decision without it: outside
  `@testable`, `SafetyPolicyResultV1` has **no public initializer** — the only public producer is the
  engine, so an H1-free decision is structurally unreachable through the public pipeline. Confident
  benign visuals (0.95) cannot flip any UNAVAILABLE dimension (P14). H1 never falsely complete. PASS.

## 6. CHILD AGE POLICY (checks 4, 16)

- `GuardianEnteredChildProfileV1` is the ONLY child input: `ageYears: Int` + jurisdiction + mandatory
  attestation flag; `storage = "LOCAL_FIRST"`; no image/face/Data/URL field exists (probe P9 mirror).
  `ChildAgePolicyEngineV1.evaluate` accepts no visual type — **feeding an image/inferred age is
  structurally impossible**; the only spoof route (attestation=false with an injected age) fails
  closed to `AGE_UNKNOWN_REVIEW` + `AGE_SOURCE_MISSING` (P9). Content full of confident
  person-visual labels with no profile yields `childOutcome == nil` (P9). PASS.
- Under-13 H1 law verified: H1 gap coded on every <13 decision; aligned→UNKNOWN_REVIEW (P2, P3, P6).
- Age-band boundaries (probe P7, TR, sensitiveNews strong @ risk 0.65): age 9 → AGE_RESTRICTED
  (admission AGE_RESTRICTED), 10 → AGE_CAUTION, 12 → AGE_CAUTION, 13 → AGE_ALIGNED (content still
  CAUTION) — exact band semantics (`restricted<10`, `caution<13`) honored; builder 12/13 stress pair
  reproduced.
- Parent preference is stricter-only (tighten-only API: extra caution dims + block-news; no loosening
  surface exists); `hd-parent-stricter` reproduced (14yo + parent block-news → AGE_RESTRICTED).
- **Finding AUDIT7-F5 (MEDIUM — teen band + doc truth, see §15/§17):** for guardian-attested ages
  13–17, UNAVAILABLE dimensions have NO fail-closed floor: probe P17 ("explicit adult romance scenes
  compilation uncut", age 14) returns AGE_ALIGNED + NEUTRAL (H1 code is the only honesty marker),
  while age 12 on identical content correctly fails closed. This is a *declared* authored bound
  (`h1RequiredUnderAge = 13`, documented "H1 law applies <13 only") and no §22 gate is violated, but
  it contradicts the sentinel registry's own prose (see §15) and must be addressed in P009E.
- No age-range validation on `ageYears` (Int.min accepted, P16) — fail-closed behavior still holds;
  cosmetic (part of F-5 remediation scope). No numeric child score anywhere.

## 7. SOURCE / JURISDICTION TRUTH (check 5)

- Source classes separated (`AgePolicySourceClassV1` ×5); every `ChildAgeDecisionV1` records its
  source. `legalRatingsIngested == false`, `providerRatingsIngested == false` (honest — no feed
  exists); `presentableAsLegalRating()` is structurally false for every reachable decision — probe
  P21 drove both developmental and parent-preference source paths: **developmental output can never
  present as legal**. HUD labels the age source "DEVELOPMENTAL_SUITABILITY (never legal)" (see §18
  for a caveat). Jurisdiction registry versioned, TR/US/EU; unsupported jurisdiction (probe P8 used
  the adversarial real-code "DE") → AGE_UNKNOWN_REVIEW + `AGE_JURISDICTION_UNSUPPORTED` + REVIEW
  admission. Bands identical across the 3 jurisdictions in v1 — honestly documented. PASS.

## 8. PERSONAL SHIELD (checks 6, 7, 10)

- Canonical-ID law enforced **at the constructor door**: non-`concept:`/`entity:` entries are demoted
  to `freeformGuesses`; matching is exact set-intersection on canonical IDs from the world model —
  no substring path exists. Probe P11: `"concept:mortal"` and `"concept:calm"` (canonical-prefixed
  strict prefixes of real IDs) + raw `"ölüm"` on genuine mortality content → **no hard match, no
  SHIELD_TOPIC_MATCH, advisory code visible**; the full ID `concept:mortality` matches the same
  content (control). Raw-substring and near-match attacks dead. PASS.
- Cross-language both directions (probe P10): ONE config `concept:mortality` matched TR ("vefat ve
  cenaze…") and EN ("funeral and obituary…") surfaces, both EXACT_CANONICAL, same canonical ID;
  builder TR/EN pairs reproduced. PASS.
- Advisory guesses can never hard-block: `hardMatch` is true only for canonical intersections;
  resolver step 3 consumes `hardMatch` only (P11, P16 garbage config incl. bare `"concept:"`). Match
  confidence categorical and separate. Local-first: no cloud/sync field exists on the config. PASS.

## 9. PRECEDENCE / CONFLICT (checks 8, 9)

- Canonical walk implemented as strengthen-only (rank can only go stronger); no vote. Probe P1 +
  builder stress: benefit flood never outranks STRONG_PROTECTION. Age restriction outranks positive
  content character (P7 age-9 → AGE_RESTRICTED admission over caution-class content;
  `hd-parent-stricter` reproduced). Unresolved contradictions surface in `unresolvedConflicts` and
  escalate to caution-rank when nothing stronger holds. Dominant + secondary + confidence class +
  versions emitted per §9. PASS (one provenance-completeness defect on the UNKNOWN branch — F-4, §11).

## 10. ADMISSION STATE (check 12)

- `AdmissionStateV1` is a pure 8-case string enum; `AdmissionStateCandidateV1` mirrored **deeply**
  (probe P18, depth-4 recursive Mirror over candidate + shield outcome + provenances): the ONLY
  numeric reachable is `versions.atMs` — the §17-mandated freshness timestamp. No hidden score.
  `scoreDisplayAllowed() == false`. Categorical only. PASS.

## 11. REASON CODES (check 13)

- Typed `PolicyReasonCodeV1` (22 codes) with `PolicyProvenanceV1` (code+producer+basis) on every
  emission; probe P15: producers/bases non-empty, SHIELD_* codes produced by the shield engine, H1
  basis names the registry truth.
- **Finding AUDIT7-F2 (LOW):** parent-preference extra caution on a NON-news dimension emits
  `CHILD_AGE_CAUTION_SENSITIVE_NEWS` (code class wrong; basis string truthfully says
  "parent-preference extra caution: fear-threat") — `ChildAgePolicyEngineV1.swift:122`. Pinned in P15.
- **Finding AUDIT7-F4 (LOW):** when the world model is OOD/unknown (or identity provisional) AND a
  child decision is simultaneously fail-closed, the resolver's neutral→UNKNOWN branch picks
  identity/knowledge first and the child engine's reasons (e.g. `AGE_JURISDICTION_UNSUPPORTED`) are
  **dropped** from the candidate's reason set (`PolicyConflictResolverV1.swift:79-93` — the
  `child.outcome == .unknownReview` append is unreachable from inside the taken branch). State stays
  correctly fail-closed and `childOutcome` is carried; loss is observability-only. Pinned in P16;
  contrast P8 where knowledge is KNOWN and the code IS present. Fix in P009E.

## 12. UNKNOWN / REVIEW (check 11)

First-class and fail-closed on every probed trigger: provisional identity → UNKNOWN +
IDENTITY_PROVISIONAL (builder test + P14 route 5); empty content + child → UNKNOWN/REVIEW (P16);
unattested age → REVIEW + AGE_SOURCE_MISSING (P9); unsupported jurisdiction → REVIEW (P8); OOD
garbage (NaN edit density, nonsense language, Int.min age, empty jurisdiction, garbage shield) →
non-NEUTRAL, non-blocking, no crash (P16); unsupported language child → UNKNOWN/REVIEW (builder OOD).
PASS.

## 13. CACHE / REUSE (checks 14, 15)

- `PolicyDecisionCacheV1` keyed by (profileID, item, policyFingerprint): probe P12 — cross-user
  lookup returns nil, cross-item nil, `clearProfile` strictly per-profile. **No cross-user
  contamination.** Isolated from ContentDNA/world-model caches (separate class, personal key).
- Changed shield + same world model (ContentDNA stand-in): probe P13 — different decision WITHOUT
  re-running the mesh; state-affecting config change ⇒ new fingerprint ⇒ miss ⇒ recompute. PASS.
- **Finding AUDIT7-F3 (LOW):** the fingerprint omits `freeformGuesses` and `preferredConcepts` —
  configs differing only in those COLLIDE (pinned in P13), so a cached decision could carry stale
  advisory-guess notes / preferred-match lists. Mitigation verified: neither field can ever change
  the categorical state (P13 asserts equal states). Advisory-surface staleness only; fix in P009E.

## 14. PRIVACY (check 17)

Probe P19 planted unique tokens in content OCR (`qx7ContentSecret`), a freeform guess
(`qx7GuessSecret`) and a raw (demoted) shield entry (`qx7RawShieldSecret`), child profile active:
NONE appear anywhere in the candidate's reasons/bases/producers/unresolved/shield-match
lists/advisory notes/version strings. Advisory notes echo only a COUNT. The child's raw age is never
echoed into any basis (bases carry band thresholds, not the age). Child profile and shield config are
in-memory/local-first; no cloud field exists. Builder leak test independently reproduced. INFO: the
jurisdiction code is echoed into the unsupported-jurisdiction basis ("jurisdiction:DE…") — minimal
config data needed for actionability, judged acceptable. PASS.

## 15. SENTINELS / CORPUS (check 18)

- Registry intact: 6 sentinels, all dimensions accounted (probe P20); strong-risk sentinel-class
  input never NEUTRAL (P20 fresh TR scenario → STRONG_PROTECTION; builder test reproduced).
- Corpus: 20 §13 families present across TUNE 21 / HELD_OUT 8 / STRESS 4 / OOD 4; split-authored;
  dual-annotator severity slots with disagreement preserved (test-asserted); scenarios drive the LIVE
  mesh (not mocks).
- 5 pre-freeze TUNE fixes examined one-by-one: (1) under-13 H1-visibility law — honesty fix;
  (2) sensitiveNews strong-restricted band authored at 10 — policy authoring; (3) `deaths/ölümler`
  tokens — lexicon inflection completion (F-1); (4–5) two annotation authoring corrections
  (`sd-age-boundary-12` expectation corrected because the text fires FEAR not sensitiveNews — the
  corrected expectation follows from the declared bands and my independent P7 re-proved the true
  boundary on sensitiveNews content; `pd-humor-explicit` scarcity-token note). All five are
  honesty/policy-authoring, none masks a defect. ACCEPTED.
- **Finding AUDIT7-F5 (MEDIUM):** the registry prose declares "never NEUTRAL" (and "never NEUTRAL for
  child profiles" for age-critical-sexual), and `P009D_POLICY_INTELLIGENCE.md` claims "sentinel input
  never NEUTRAL — tested", but probe P17 shows a guardian-attested **14-year-old** on sentinel-class
  sexual-text content reaching NEUTRAL/AGE_ALIGNED (no lexicon hit; sexualThemes UNAVAILABLE; H1 code
  present as the only marker). The law is enforceable today only via the <13 fail-closed floor +
  strong-risk escalation; for 13–17 it is NOT enforced. No §22 spec gate fails (NEUTRAL is not a
  "visually safe"/positive claim and the §15 no-false-safe gate is calibration-time), but the doc/
  registry wording OVERCLAIMS versus behavior, and the teen band needs an explicit authored decision.
  **Must be addressed at P009E entry (doc-truth correction + teen-band policy), before any score/glyph.**

## 16. TESTS (check 1 baseline + builder claims)

- Builder claim 563/563 **verified**: two independent full runs, `Executed 563 tests, with 0 failures`.
- P009D gates reproduce exactly: `P009D_TUNE scenarios=21 failures=0 · HELDOUT 8/0 · STRESS 4/0 ·
  OOD 4/0`.
- With auditor probes: **584/584, 0 failures** (`Executed 584 tests`), AUDIT7 suite 21/21.
- Prior banks all green (P009C 21/10/4/4, P009B/R1, CAL_RESERVED never executed). Score display OFF
  re-asserted.

## 17. AUDITOR PROBES

`Tests/GuardianCoreTests/AUDIT7_P009DProbes.swift` — 21 fresh probes (add-only; no source or existing
test touched; fresh surface tokens): P1 benefit-flood vs severe risk · P2 humor+explicit child ·
P3 prevention-vs-encouragement self-harm (identical fail-closed — no fake distinction) · P4 drug
education vs promotion · P5 gambling reporting vs promotion · P6 mild cartoon vs severe realistic
violence · P7 age-band boundaries 9/10 + 12/13 (sensitiveNews-strong) · P8 unsupported jurisdiction
"DE" · P9 spoofed age-from-image (3 vectors) · P10 shield canonical cross-language both directions ·
P11 shield near-match/raw-substring attack · P12 cross-user cache contamination · P13 changed shield
same DNA + fingerprint-collision pin · P14 H1 rides every decision (5 routes) · P15 reason-code↔
provenance + parent-overlay mismatch pin · P16 OOD policy inputs + dropped-child-reason pin ·
P17 teen sentinel-class NEUTRAL surface pin · P18 deep no-hidden-numeric mirror · P19 planted-token
privacy · P20 sentinel registry + strong-risk never NEUTRAL · P21 developmental-never-legal.
**Result: 21/21 pass. Real defects found and pinned: F-2, F-3, F-4, F-5 (none critical; all
fail-closed-preserving).** No probe required any source change.

Findings register:
| ID | Severity | Summary |
|----|----------|---------|
| AUDIT7-F1 | LOW (accepted) | P009C-locked lexicon file modified post-lock (+`deaths`/`ölümler`); documented TUNE fix, honest inflection completion, prior suite green |
| AUDIT7-F2 | LOW | Parent-preference overlay on non-news dims emits `CHILD_AGE_CAUTION_SENSITIVE_NEWS` (wrong code class; basis truthful) |
| AUDIT7-F3 | LOW | Policy-cache fingerprint ignores `freeformGuesses`/`preferredConcepts` → advisory-surface staleness on collision (state unaffected — proven) |
| AUDIT7-F4 | LOW | Child fail-closed reason codes dropped when OOD/identity wins the UNKNOWN dominant slot (state + childOutcome still correct) |
| AUDIT7-F5 | MEDIUM | Teen band (13–17) has no fail-closed floor on UNAVAILABLE dims; sentinel-registry/doc "never NEUTRAL (for child profiles)" overclaims vs behavior — doc-truth fix + authored teen decision required at P009E entry |
| AUDIT7-F6 | INFO | HUD "Age source" row hardcodes `DEVELOPMENTAL_SUITABILITY (never legal)` instead of reading a carried source class (truthful under the HUD's current demo config; fragile if parent-preference sources appear) |

## 18. DEVICE / HUD EVIDENCE (check 19)

HUD verified **by code read** (app target, `#if DEBUG`, developer HUD): policy section displays
categorical admission, dominant/secondary codes, child outcome, "never legal" age-source labeling,
shield hard/advisory + categorical confidence, H1 row pinned to "UNAVAILABLE_EVIDENCE_BACKED (open
blocker — visible on every route)", unresolved conflicts, policy versions, and **score display OFF**
("CalibrationRegistrySkeletonV1 refuses"). It consumes `AdmissionPolicyPipelineV1.evaluate` over the
SAME world model (cheap re-derive, read-only display; no write-back into policy state). F-6 caveat
noted. **No device policy-run is claimed by the builder — §20 physical/in-app validation is honestly
user-gated and remains PENDING/NOT_MEASURED.** Judged per the spec's own text: this is a declared
post-freeze, user-gated step, not a lock blocker.

## 19. OPEN BLOCKERS

Honestly restated at phase end (`GEN8_OPEN_BLOCKERS.md`): C2 App Group; C3 extension shield; C4 score
calibration NOT done; C5 H1 visual (now evidence-backed registry, still OPEN); Tier-0 burst residual;
proof-log beta; LAB_ONLY paths; ChildAgePolicy device proof PENDING (user-gated); 8/11 dimensions
UNAVAILABLE (capability truth); jurisdiction bands v1 identical TR/US/EU; **push blocked on missing
remote (external dependency)**. New from this audit, to carry into the P009E entry gate:
**F-5 (MEDIUM)** teen-band fail-closed decision + sentinel/doc truth correction; F-2/F-3/F-4 LOW
hygiene; F-6 INFO. None blocks the P009D categorical-policy lock.

## 20. GO / NO-GO

All 20 mandated verifications executed; every predeclared §22 gate holds under fresh adversarial
probing; builder numbers reproduced exactly (563/563; TUNE 21 / HELD_OUT 8 / STRESS 4 / OOD 4,
failures=0); with auditor probes 584/584. The five pre-freeze TUNE fixes are honesty/policy-authoring,
not tuning-to-fit. Prior locks byte-intact. Findings F-1..F-6 are non-critical, fail-closed-preserving,
and logged for the P009E entry gate (F-5 MEDIUM must be resolved there — doc truth + authored teen-band
policy — before any calibration/score work ships).

**FINAL VERDICT:**

`PASS — P009D POLICY INTELLIGENCE LOCKED; GO TO P009E CALIBRATION`
