# GEN8 — ULU EVREN CONTROL PLANE — INDEPENDENT RED-TEAM AUDIT (AUDIT12)

**Auditor:** clean-session independent red-team auditor (no builder context trusted; every number recomputed from the repository).
**Date:** 2026-10-20.
**Verdict (three-verdict rule): FIX REQUIRED — ULU EVREN CONTROL PLANE.**
**Probe family:** `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT12_UluEvrenControlPlaneProbes.swift` (36 probes, add-only, deterministic, green against the candidate AS-IS with defects pinned).
**Suite:** 749/749 — run twice (713 baseline = 704 + 9 ControlPlaneValidationTests, reproduced independently, + 36 AUDIT12 probes).

---

## 0. Custody

| Fact | Expected | Observed | Status |
|---|---|---|---|
| Branch | phase/ulu-evren-control-plane | phase/ulu-evren-control-plane (clean tree, up to date with origin) | MATCH |
| HEAD / candidate | 4d6649c7a67a22c0b5eed5f1fd94bd3f3d25e8f8 | 4d6649c7a67a22c0b5eed5f1fd94bd3f3d25e8f8 == origin | MATCH |
| Candidate tag | gen8-ulu-evren-control-plane-audit-candidate → 1c2c9f93… → 4d6649c | 1c2c9f9339c5b5659300459391c8ed200811952e → 4d6649c7… | MATCH |
| Predecessor tag | gen8-rwc-entry-gate-r1-locked-engineering → 447daad4… → e983b36 | 447daad47436d7f10fa8c4b2e9b1ffec3241b96b → e983b360711d96f0af51b853ab05d889aaedb0e8 | MATCH |
| AUDIT11 | e5b5d612c06a30288028f2943bbf822f59b6f819 | resolves | MATCH |
| Range e983b36..4d6649c | 4 commits, docs+tests only | 11e673b, ed13d2c, 9c77910, 4d6649c; diff = 13 docs files + 1 test file, **1045 insertions, 0 deletions, zero production-source changes** | MATCH |
| Baseline | 713/713 (704 + 9) | 713/713 reproduced; with AUDIT12: 749/749 ×2 | MATCH |
| Frozen audit originals | a349a487 (AUDIT9), a1ffb855 (AUDIT10) | SHA-256 recomputed byte-identical (probe A12_35) | MATCH |

No custody mismatch. The audit proceeded on the candidate.

## 1. Independent recount (§2) — methodology: JSONSerialization parse of the three canonical strict-JSON files; every count recomputed in probe A12_01

| Quantity | Builder summary | Meta pre-scan | **Auditor recount** |
|---|---|---|---|
| Nodes | "41+" | 60 | **60** |
| depends_on edges | 74 | 75 | **75** |
| blocks edges | — | — | **49** (declared convenience inverse, not a bijection) |
| Programs | 9 | 10 | **10** (CONTROL_PLANE, TRUSTED_BRAIN, RWC_PREREGISTRATION, REALITY, GUARDIAN_BODY, HUMAN_SYSTEM, SOCIAL_COMMAND_OS, LIVING_INTELLIGENCE, UNIVERSALIZATION, PRODUCTION_CIVILIZATION) |
| Epochs | 8 | 8+META | **8 + META = 9 distinct values** |
| Blockers | 22 | 22 | **22** |
| Negative truths | 9 | 9 | **9** |
| Sources | 22 | — | **22** |
| FM records | 14 | — | **14** |
| Status census | — | — | **ACTIVE 9 · LOCKED 6 · READY 1 · BLOCKED 20 · PLANNED 24** |
| READY set | {CP-INDEPENDENT-AUDIT} | same | **exactly [CP-INDEPENDENT-AUDIT]** |
| Refs | "~95" | — | **253 total** (see §3) |

**Builder-summary discrepancies (§27):** programs 9→10, edges 74→75, refs ~95→253. All three are summary-prose errors only; the canonical files are internally consistent on these counts → **A12-F1, LOW**. One canonical-internal count inconsistency exists separately (A12-F6, §4).

## 2. Source authority audit (§3, §17)

All 22 `sources[]` classes are from the allowed taxonomy and domain-correct: both ledgers (`GEN8_OPEN_BLOCKERS.md`, `GEN8_CLAIM_EVIDENCE_LEDGER.csv`) are AUDIT_EVIDENCE (immutable, never DERIVED); all `docs/audit/` entries are AUDIT_EVIDENCE (no audit report is miscalled authoritative architecture); views are GENERATED_VIEW and every view self-declares it loses to the twin; DECISION_LEDGER / capability matrix / registries are AUTHORITATIVE; certification/test matrices DERIVED. No "newest file wins" rule exists anywhere; schema §6 states domain-aware precedence and "Newer ≠ more authoritative" explicitly (probe A12_14). The BLK-H1 case proves the conflict behavior empirically: the ledger's "git anchoring absent" claim is contradicted by current pushed history, and the twin **flags STALE_LEDGER with an explicit resolution-record obligation instead of silently closing or rewriting** — correct. Authority conflict resolution remains **prose-law, not machine-enforced** (a mutated audit verdict "FAIL" on a LOCKED node passes all 9 builder checks — probe A12_26); folded into A12-F4. Two source "paths" are prose-hybrids (`docs/audit/ (AUDIT2..AUDIT11 …)`, `CURRENT_STATE.md and sibling views`) → **A12-F9, INFO**.

## 3. Evidence reference integrity (§4) — complete census (probe A12_08)

Every reference field inventoried: implementation.refs/commits, tests.refs, audit.refs, all six evidence arrays, node blockers, rollback commit/tag, sources.path, blocker.source, negative_truth.evidence, FM evidence + regression_tests.

| Class | Count | Resolution rule | Result |
|---|---|---|---|
| FILE_PATH | 71 | FileManager existence | 70 ok, **1 BROKEN** |
| DIRECTORY_SCOPE | 7 | directory existence | all ok |
| LEDGER_ANCHOR (csv:Pxxx) | 8 | row-prefix match in CSV | all ok |
| COMMIT_SHA | 22 | `git rev-parse` (out-of-band; all 14 distinct prefixes resolve, incl. e2d008d/905eab5 ordering-proof pair) | all ok |
| TAG | 8 | refs/tags + packed-refs | 6 ok, **2 BROKEN** |
| TEST_SYMBOL | 29 | test-file existence | all ok |
| SOURCE_SYMBOL | 2 | named .swift source | ok |
| AUDIT_ALIAS | 16 | convention table (unique per phase) | all resolve; mapping is NOT machine-encoded |
| SEMANTIC / HUMAN_DESCRIPTION | 90 | deterministically non-resolvable prose | declared as such |
| **TOTAL** | **253** | | **MACHINE-RESOLVABLE 163 · SEMANTIC 90 · BROKEN 3 · AMBIGUOUS 0 · ORPHAN 0** |

**“broken refs = 0” is FALSE** → **A12-F3, MEDIUM**:
1. `P009A-IDENTITY-FOUNDATION.rollback.tag = gen8-p009a-identity-foundation-locked-phase-c-ok` — tag exists nowhere in git and in no other repo document (earliest real tag is gen8-p009c-locked). Fabricated anchor.
2. `P009B-EXPERT-MESH.rollback.tag = gen8-p009b-expert-mesh-r1-reaudit-pass` — same class.
3. `P009D-POLICY.implementation.refs = docs/implementation/P009D_IMPLEMENTATION_EVIDENCE.md` — file does not exist; the real artifact is `docs/intelligence/P009D_POLICY_INTELLIGENCE.md`. Wrong path on a LOCKED node.
Rollback-by-commit still works for all three nodes (4ce238f, 42b96a2, 9c049f3 all resolve), so execution impact is contained — but a canonical state machine that invents two tag names and mis-paths one evidence file violates its own claim→evidence law (and FM-003/FM-014 spirit). The builder's CP07 hard-checks only 5 hardcoded paths and missed all three. The twin does **not** textually overclaim 100% machine-resolvability, but 90/253 refs are human prose; the census is now pinned so drift is visible.

## 4. Requirement graph (§5)

All requirement IDs used by nodes resolve in `REQUIREMENTS_REGISTRY.yaml` (probe A12_04). All D-xxxx decisions cited anywhere in the three canonical files resolve as DECISION_LEDGER headings (A12_07). The harder test fails: **12 of 36 registry requirements map to NO twin node** → **A12-F2, MEDIUM**: ADM-002, BND-001, COST-001, DVT-001, EVD-001, HSH-001, PRI-001, PROT-001, REL-001, SCO-002, SEC-001, TWIN-001. All are P0/release-blocking in the registry. Several are *nominally* inside node/epoch scopes (EP4-FAMILY-AUTHORITY names device trust + household; EP8 names security/privacy) but the control plane cannot schedule, track, or close them **by requirement ID** — exactly the traceability chain CLAUDE.md §7 declares release-blocking. No wrong-epoch mappings, no requirement satisfied only by a superseded node, were found among the 24 mapped IDs. Secondary: registry `meta.count: 35` vs 36 actual entries, and the twin's source note repeats "35 P0 requirements" → **A12-F6, LOW** (canonical-internal count inconsistency).

## 5. Build Bible coverage (§6) — independent validation (probe A12_30)

The 665/665 claim was recomputed from scratch: all `| §N |` / `| §N–§M |` rows parsed, ranges expanded, appendix rows collected. Result: **§0–§656 covered completely (657 sections), zero gaps, zero duplicate/overlapping rows (no count inflation), Appendices A–H all present → 657 + 8 = 665 exactly.** Superseded sections are explicit (`SUP`) and tied to decisions (§63 OCTOPUS 12→20 / D-0007; Star→Pure Bar / D-0006; §113 repo shape). Deep theme sampling (repository/reality, contracts, perception §15–§21, identity §20/§550, cognition §22–§36, personal algorithm §46–§47, score §49–§53/§60, calibration §69, outcome §55–§59, browser/share, digital impact, creator §78–§79, family §73–§77/§416–§457, advanced intelligence §638–§640, production hardening §553–§556, guardian runtime §18/§626–§628, pre-exposure §613–§656, ContentAhead §617–§620, social command §7–§12/§319–§375, entitlement §464–§465, device trust §564–§565, controlled learning §66/§68, release W0–W3 §576) all resolve to REQ/DOC/ADR/SUP/DEFER dispositions. SOC depth is explicitly **DEFER/P1**, not silently lost. Meaningful coverage: **preserved**.

## 6. Old phase ↔ P00x ↔ epoch mapping (§7)

`phase_mapping` resolves 100% to twin node IDs (builder CP09 + reverified). No historical phase is missing: P001–P008 remain ACTIVE historical nodes with their evidence anchors; P0_EXECUTION_DAG is explicitly indexed, NOT superseded. **P008 failed pilot remains negative evidence**: node calibration axis CONTRADICTED, NT-P008-PILOT-FAILED present, ledger "false-safe 0.50" text intact, and P009A still depends on P008 in-chain (probe A12_28). **P009E stays ENGINEERING_CALIBRATION_ONLY** — no engineering calibration anywhere upgraded to real-world. No incompatible duplicate systems active; superseded segmenter/shield generations are declared in `limitations`.

## 7. Truth axis audit (§8) — NODE×AXIS

480 axis values swept. **Plain VERIFIED exists on exactly two axes in the whole twin: RWC-ENTRY-GATE.functional and RWC-ENTRY-GATE.privacy** — both covered by AUDIT11 §13 ("Privacy / security — VERIFIED", diff + error payloads) and the R1 engineering lock; evidence class matches axis. No calibration axis is verified-class anywhere; no device axis is VERIFIED; no human_product axis is verified-class (probe A12_15 pins the exact inventory). No generic-ref reuse inflating unrelated axes was found. One self-grade defect: **CP-CONTROL-PLANE.privacy/security = VERIFIED_WITH_LIMITATIONS while its own audit.status = PENDING**, violating the twin's transition law §5 (LAB_ONLY→VWL requires an independent-audit ref). overall stays UNVERIFIED so nothing unlocks, but the axes are builder-self-graded → **A12-F10, LOW** (probe A12_16).

## 8. Claim inflation (§9)

Swept all control-plane artifacts. Verified present and correct: Tier-0 grouping **CONTRADICTED** (NT + D-0020 + P009A availability "shot+provisional ONLY"); **ECE .250 UNMET/UNRELAXED** (twin + AUDIT9/AUDIT11 recomputation anchors); **F1 violence detection NOT VALIDATED** (NT-F1-COVERAGE, CLAIM_TRUTH_MATRIX row); **device RWC OPEN** (BLK-DEVICE-RWC-OPEN; real_device=OPEN on the gate); **production score BLOCKED** in graph AND in code (`ProductionScoreReleaseGateV1` CLOSED, `productionDisplayAllowed()==false`, `calibrationClass==.engineeringOnly`, `supportsRealWorldClaims==false` — probe A12_17); **Presentation BLOCKED**; "real-world/production calibrated" is a **FORBIDDEN CLAIM — FALSE** row in the view. No VERIFIED inherited from unrelated lab evidence. INFO: the immutable ledger's P009E restatement says "ECE 0.220" while the audits recomputed 0.250 — the twin correctly carries the **audit** figure (authority order respected); the stale builder figure stays readable in the immutable ledger → **A12-F11, INFO** (probe A12_18).

## 9. Negative truth completeness (§10)

All 9 recorded NTs present with non-empty evidence (A12_19). Independent sweep of AUDIT2..AUDIT11 reports, closeout locks, errata and the blocker ledger found **no unresolved release-relevant negative finding missing from the twin**: A8-F1..F8 and A9-R1-F1..F6 are closed in P009E_R1_CLOSEOUT_LOCK (A9-R1-F3 ECE-domain INFO is absorbed by RWC-PRE-11 metric preregistration scope); A10-F2-MULTISET/WIRING/VACUOUS and A10-F3-SIBLINGS/FPEDGE closed-or-erratum'd per the R1 lock; all carried A10/A11 items are twin blockers. The honest device under-performance record (Tier-0 economy 1.4% vs lab 43–48%) remains in the immutable ledger and is decision-covered by NT-TIER0-GROUPING. Validator gap: CP06 pins only 8 of 9 NT IDs — **NT-PREVDWELL is deletable undetected** (mutation-proven) → part of **A12-F12, INFO**.

## 10. Blocker currency (§11)

22/22 blockers verified against the ledger, AUDIT8–11, the RWC lock and the decision ledger: all 13 original B/C/H rows carried verbatim-by-ID; GATE/LIMITATION/OPS additions each anchored to a real audit/session source; owner nodes correct (IDCHARSET+ALIAS→RWC-PRE-02, LEGACY-P008→RWC-PRE-03, APIBYPASS→RWC-PRE-04 as release-blocking-at-prereg, ECE→PRE-09/11, DEVICE→PRE-13/DEVICE-E2E); C4 OPEN_BY_DESIGN and C6 OPEN_CONTAINED are honest status refinements, not closures. **BLK-H1 = STALE_LEDGER verified from git history** (origin history + 12 tags through the candidate exist; the original one-commit claim is genuinely stale); the twin demands an explicit ledger resolution record and the view repeats it — **not silently closed**. No blocker is CLOSED/RESOLVED anywhere; no duplicates; downstream relations coherent. Validator gap: only 9/22 blocker IDs are vanish-pinned by CP03 (e.g. BLK-GH-CREDENTIALS deletable undetected — mutation-proven) → part of **A12-F12/F4**.

## 11. Failure memory (§18)

FM-001..014: every record's historical anchors verified to exist (inversion locks, erratum file, AUDIT10/11 finding IDs greppable in the immutable reports, claim-ledger P007A correction row, D-0020/D-0024); `first_seen` values match the actual audit history; invariants follow from root causes; **every machine-checkable regression_tests symbol exists as a test file** (incl. AUDIT_ArtifactIntegrityTests for FM-002); `applies_to` targets resolve to twin nodes (or ALL/EP-globs); statuses restricted to ACTIVE_INVARIANT / MITIGATED_GUARDED / OPEN_SCOPE_LIMITATION — FM-013 correctly NOT claimed mitigated. **No invented history found in the FM registry** (probe A12_21). (The invented-tag finding A12-F3 lives in the twin, not in FM.)

## 12. Graph semantics (§12, §24) and READY law (§13)

Acyclicity, dangling refs, blocks-symmetry: recomputed independently — clean (A12_02). Critical-path edges are semantically required and complete: CP audit → PRE lanes; handbook→isolation→adjudication→IRR→feasibility→slices→**gate freeze (PRE-11 requires PRE-09+10: feasibility BEFORE thresholds; "no gate tuning after data visibility" binding)**→seal; PRE-14 requires ALL thirteen; corpus forbidden until PRE-14; corpus→annotation→fit→held-out; device E2E requires held-out + PRE-13 protocol; **Presentation requires held-out AND device E2E** (A12_28). No missing/unnecessary/inverted dependency found on the critical path; no hidden semantic cycles.

**A12-F4 (MEDIUM) — the enforcement gap.** The machine READY law (CP04) is "every dependency LOCKED-or-ACTIVE and blocked_by empty", plus a **hardcoded** equality `ready == [CP-INDEPENDENT-AUDIT]` and hardcoded forbidden-state pins (CP05). Mutation probes (A12_22/23/24/26) prove, against deep copies:
- dep **ACTIVE-incomplete** (RWC-PRE-14 ACTIVE, corpus READY): generic law **accepts**; only the hardcoded pins catch it;
- dep carrying **open blockers** or stripped of **entry evidence**: generic law AND full CP04 accept (not checked at all);
- **CONTRADICTED→VERIFIED_WITH_LIMITATIONS** without resolution record: passes all 9 builder checks;
- **device VERIFIED without device_refs**: passes (CP07 counts ANY evidence array — axis-blind);
- nonexistent REQ ID, broken evidence path, audit verdict flipped to FAIL on a LOCKED node, W2 node reassigned to W0: all pass.
Caught correctly: cycles, dangling refs, calibration=VERIFIED anywhere, Presentation/corpus READY (via pins), zero-evidence verified-class, FM/NT census for pinned IDs. Conclusion: today's canonical data cannot drift without failing the suite, **but the generic law becomes the only guard at the first legitimate post-audit state update**, at which point it would permit ACTIVE-incomplete unlocks (e.g. corpus while PRE-14 is merely running). The documented ready_law (evidence classes, findings closed, no contradictory higher-authority evidence) is prose-only. The CP-CONTROL-PLANE(ACTIVE)→CP-INDEPENDENT-AUDIT edge is a legitimate special case; a GLOBAL ACTIVE==satisfied law is not justified anywhere.

**State-machine behavior (§14):** all 8 future-state simulations behave correctly under pass/locked semantics (probe A12_27), including PRE-14 requiring all 13, corpus gated on PRE-14 PASS, fit gated on annotation, and Presentation unlocking only after held-out + device E2E. The graph works as a state machine **when transitions are applied honestly**; the gap above is about who enforces honesty.

**blocked_by overload (§15):** the field carries node IDs 18× and blocker IDs 2×, against schema §2's own declaration ("blocker IDs / finding IDs"); CP02/CP03 explicitly accept both → **A12-F5, LOW** (dependency vs blocker vs gate not structurally distinct; recommend `gated_by` vs `blocked_by` split).

**State transitions (§16):** machine-enforced = NO. Classified honestly as prose-law + pinned-snapshot validation (folded into A12-F4).

## 13. Release waves (§19) and platform capability (§20)

W0 census exact: EP3-PRESENTATION, EP3-CONTENT-AHEAD, EP3-CONTROLLED-BROWSER (Chromium-first), EP3-LONGFORM-TEMPORAL (ContentDNA/TemporalGraph), EP3-ANDROID-GUARDIAN, EP4-FAMILY-AUTHORITY (family pairing), EP5-ADAPTERS-RECONCILIATION (one real publisher), EP8-RELEASE-WAVES. The controlled player appears in the W0 wave scope (and EP8 availability) rather than as its own node — program-granularity, acceptable, track at the wave gate. No iOS-polish (W1) or TV (W2) inside W0. Wave array order W0→W1→W2→W3 asserted. **A12-F7, LOW:** EP8-RELEASE-WAVES — the certification gate — `blocks: []` and no node depends on it: wave certification is a graph **sink**; "wave order may never invert" is prose + array order only (acceptable if waves gate RELEASES not work, but then the release-gating itself has no structural representation). Platform truth: capability matrix is all-RCOV at baseline with explicit VERIFIED-requires-device-artifact legend; twin platform scopes match; iOS honesty held ("never claim native feed control" on EP3-IOS-GUARDIAN; EXTENSION_TIER1_LITE EMPTY; H1 visual UNAVAILABLE; FM-011 binds EP3-*/EP7-*). architecture-supports vs capability-exists vs device-proven vs certified remain distinct (D-0022 tiers + RCOV).

## 14. Social / Family / Controlled Learning (§21–§23)

EPOCH V scope names all ten required surfaces; the deep requirements (OAuth/PKCE, wrong-account = catastrophic-zero-tolerance, idempotent publish, duplicate prevention, reconcile-before-retry, rate-limit governance, no private APIs) live verbatim in PUB-001; richer SOC sections are explicit DEFER/P1 in the coverage matrix — preserved, deferred, not lost. EPOCH IV scope names guardian authority, anti-tamper, device trust, household, entitlement, sync; FAM-001/CHD-001 carry pairing-security, anti-coercion, no-covert-surveillance, disable-resistance; travel/revocation live in HSH-001/ENT-001 — **but DVT-001/HSH-001 are among the orphan requirements (A12-F2)**, so "Family pairing" node coverage is currently thinner than the registry's architecture at the ID level. EPOCH VI: three-tier shape present (bounded personal / consented privacy-safe shared / controlled global evolution with shadow→canary→rollback); EP6-BOUNDED-LEARNING gate = privacy audit; EP6-MODEL-EVOLUTION gate = signed manifests + rollback artifacts; immutable rule 16 bound on-node; governance limits forbid self-granted authority/auto-deploy — the twin cannot authorize uncontrolled self-modification (probe A12_33).

## 15. Progress model (§25) — recomputation (probe A12_31)

Weights sum to 100. **A. Overall: Σ(weightᵢ×completionᵢ) = 13.34 → "≈13%" REPRODUCIBLE** from documented inputs. **B. Core brain ≈55%: NOT independently reproducible** — documented inputs (functional .85×.40 + device .15×.20 + calibration .10×.20) give 0.39; reaching 0.55 requires an UNDOCUMENTED privacy/security ≈0.80 input, and B is not reconciled with the Epoch-I ≈60% figure used in A. **C (≈5%) and D (≈40%): narrative estimates, no formula.** All four are honestly bracketed "PLANNING ESTIMATE — not a scientific measurement", evidence-weighted methodology stated, no double counting or W2/W3 dilution detected, no giant program missing from the weights → **A12-F8, LOW** (honestly bounded; B's hidden input should be documented or B dropped).

## 16. Generated views (§26)

CURRENT_STATE / CRITICAL_PATH / NEXT_ALLOWED_WORK / EPOCH_STATUS / CLAIM_TRUTH_MATRIX / OPEN_BLOCKERS_VIEW / DAG.md: all self-declare GENERATED and subordinate; READY node identical everywhere; forbidden list identical; all 22 blocker IDs in the view; percentages consistent across views; **no view stronger than the twin** (no "calibration VERIFIED", no real-world claim); human labels ("CONTRADICTED → scope limitation", "FORBIDDEN CLAIM — FALSE", "NOT VALIDATED") map to unambiguous canonical taxonomy (probe A12_32). No drift found.

## 17. Agentic constitution (§31) and phase packet (§32)

All nine roles with hard limits present: builder cannot self-PASS; auditor fresh-context add-only three-verdict; evidence keeper cannot create evidence nor resolve CONTRADICTED without resolution record; meta-review can only flag INCOHERENT, never override; specialists cannot expand scope; model routing is development-orchestration-only (model tier ≠ epistemic truth); external content = DATA. Phase packet template carries every mandated field; an RWC-PRE-02 packet was instantiated in-memory from the twin with owner blockers, FM bindings, dependency, stop condition and next node all representable (probe A12_34) — **sufficient**.

## 18. Control-plane security (§30)

Diff e983b36..4d6649c is additive docs + one test file; zero production sources touched; no secrets/user data/raw media in canonical files; no network side effects, no auto-merge/deploy paths, no gate weakened (code gates re-asserted CLOSED by probes); the twin grants itself no authority (schema §7 + views repeat the limits). **PASS.**

## 19. Validator adequacy (§28) — what the 9 builder tests do NOT cover

Exhaustive ref resolution (3 broken refs shipped undetected) · requirement-ID validation (none) · orphan-requirement detection · axis-specific evidence adequacy (device/calibration refs not matched to axes) · state-transition legality (prose-only) · authority-conflict coherence (verdict↔status unchecked) · generic ACTIVE-satisfaction justification · blocker/NT full-census vanish-pins (9/22, 8/9) · wave-gate semantics · Bible-matrix completeness · progress reproducibility · view-text consistency. All characterized with fresh probes; AUDIT12 now pins the census numbers so silent drift fails the suite.

## 20. Fresh findings

| ID | Severity | Finding | Pin |
|---|---|---|---|
| A12-F1 | LOW | Builder-summary recount errors: programs 9→**10**, depends_on 74→**75**, refs ~95→**253**. Canonical files internally consistent. | A12_01/08 |
| A12-F2 | **MEDIUM** | **12/36 registry P0 requirements orphaned** (ADM-002, BND-001, COST-001, DVT-001, EVD-001, HSH-001, PRI-001, PROT-001, REL-001, SCO-002, SEC-001, TWIN-001) — unschedulable/untrackable by the governing index. | A12_05 |
| A12-F3 | **MEDIUM** | **3 broken machine-resolvable refs in canonical state**: fabricated rollback tags on P009A + P009B (never existed in git) and wrong P009D implementation-evidence path. "broken refs = 0" is FALSE. | A12_08/09 |
| A12-F4 | **MEDIUM** | READY/transition/authority laws are prose-first: generic "LOCKED-or-ACTIVE == satisfied", no transition engine, axis-blind evidence counting, verdict↔status coherence unchecked; current safety rests on hardcoded pin lists that must be hand-edited exactly when they become load-bearing. | A12_22–26 |
| A12-F5 | LOW | blocked_by overloaded (18 node-ID vs 2 blocker-ID uses) against schema §2's own declaration. | A12_03 |
| A12-F6 | LOW | REQUIREMENTS_REGISTRY meta.count=35 vs 36 entries; twin repeats "35". | A12_06 |
| A12-F7 | LOW | Wave-certification gate (EP8-RELEASE-WAVES) is a graph sink — wave order enforcement is prose + array order only. | A12_29 |
| A12-F8 | LOW | Progress model partially reproducible (A yes; B needs undocumented ~80% priv/sec and conflicts with A's Epoch-I 60%; C/D narrative). Honestly bounded. | A12_31 |
| A12-F9 | INFO | 2/22 sources[].path entries are prose-hybrids (not machine paths). | A12_13 |
| A12-F10 | LOW | CP-CONTROL-PLANE privacy/security self-graded VWL while its own audit is PENDING (violates schema §5 on its own node). | A12_16 |
| A12-F11 | INFO | Stale "ECE 0.220" builder figure in immutable ledger vs audit-verified 0.250; twin follows the audit figure (correct authority). | A12_18 |
| A12-F12 | INFO | Census vanish-pins incomplete in builder validator: 9/22 blockers, 8/9 NTs (NT-PREVDWELL, BLK-GH-CREDENTIALS deletable undetected). | A12_25 |

## 21. Truth matrix (canonical taxonomy; gate result separate)

| Row | Truth |
|---|---|
| Custody | VERIFIED |
| Schema | VERIFIED_WITH_LIMITATIONS (A12-F5) |
| Graph syntax (acyclicity/refs/symmetry) | VERIFIED |
| Graph semantics (critical-path edges) | VERIFIED_WITH_LIMITATIONS (A12-F7) |
| Requirement coverage | CONTRADICTED (A12-F2: 12 P0 orphans vs "full remaining program") |
| Evidence reference integrity | CONTRADICTED (A12-F3: broken-refs=0 is false; 3 broken) |
| Evidence quality (axis-matched, where claimed) | VERIFIED_WITH_LIMITATIONS (A12-F10) |
| Source authority | VERIFIED_WITH_LIMITATIONS (prose-enforced; classes correct) |
| Negative truth | VERIFIED (9/9, nothing missing found) |
| Blocker currency | VERIFIED (22 carried; H1 STALE flagged, not closed) |
| Failure memory | VERIFIED (14/14 historically evidenced) |
| State transitions | UNVERIFIED (prose-only; illegal transitions pass) |
| Next-action engine | VERIFIED_WITH_LIMITATIONS (deterministic via pins; generic law unsafe — A12-F4) |
| RWC preregistration gates | VERIFIED (freeze-order correct; corpus locked on PRE-14) |
| Guardian critical path | VERIFIED |
| Human/Family coverage | VERIFIED_WITH_LIMITATIONS (DVT/HSH orphans) |
| Social Command coverage | VERIFIED_WITH_LIMITATIONS (depth in PUB-001 + explicit DEFER) |
| Controlled Learning | VERIFIED_WITH_LIMITATIONS (three-tier present; gates named) |
| Release waves | VERIFIED_WITH_LIMITATIONS (W0 exact; cert gate terminal) |
| Platform capability | VERIFIED (RCOV honesty, iOS honesty) |
| Generated views | VERIFIED (no drift) |
| Progress model | VERIFIED_WITH_LIMITATIONS (A reproducible; B/C/D bounded estimates) |
| Agentic constitution | VERIFIED |
| Phase packet | VERIFIED (instantiable) |
| Validator adequacy | VERIFIED_WITH_LIMITATIONS (real but materially incomplete — A12-F4/F12) |
| Control-plane security | VERIFIED |

## 22. Verdict

**FIX REQUIRED — ULU EVREN CONTROL PLANE.** Three MEDIUM findings (A12-F2 orphan P0 requirements, A12-F3 broken/fabricated canonical refs, A12-F4 prose-first enforcement of READY/transition/authority laws) block the PASS standard (§36: no unresolved MEDIUM; twin may not overclaim ref integrity). Everything else about the candidate is sound — custody clean, graph semantics correct, negative truth and blockers fully preserved, claim ceilings honest, views drift-free, Bible coverage genuinely 665/665, security clean. The control plane **remains NON-GOVERNING** until a fixed candidate passes re-audit.

## 23. Next allowed action (exactly one)

**Builder remediation phase on a new audit-candidate tag, scoped to A12-F2/F3/F4 (+ LOW set where cheap), followed by CP-INDEPENDENT-AUDIT R1 re-audit.** Concretely: map or explicitly DEFER-with-ID the 12 orphan requirements; correct the two rollback tags (honest correction — point at the real commits/tags, or create nothing retroactively without a resolution record) and the P009D evidence path; extend the validator to full ref resolution, requirement-ID validation, full blocker/NT census pins, and either justify-and-scope or replace the generic ACTIVE-satisfaction rule before the twin's first state update. **Corpus acquisition, annotator recruitment, fitting, held-out sealing, production score display and Presentation/Glyph/Motion all remain FORBIDDEN/BLOCKED throughout.**

---
*AUDIT12 probes: 36/36 green (defects pinned as current truth). Full suite 749/749 ×2 (713 baseline reproduced + 36). Written artifacts: this report + the probe file only. No existing file modified.*
