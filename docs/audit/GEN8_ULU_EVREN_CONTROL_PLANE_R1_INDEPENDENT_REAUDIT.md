# GEN8 — ULU EVREN CONTROL PLANE R1 — INDEPENDENT RE-AUDIT (AUDIT13)

**Auditor:** independent, clean-session red team (no builder context trusted; every claim recomputed
from the repository). **Date:** 2026-10-20.
**Probe family:** `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT13_ControlPlaneR1ReauditProbes.swift`
(44 fresh probes, add-only; own readiness engine `A13Engine`, own census classifier `A13Census`, own
completeness/vanish laws — NOT copies of the builder's R1 tests; mutations run on in-memory deep copies only).
**Suite:** full suite **814/814 ×2** (770 baseline + 44 AUDIT13). A green suite carried **zero** verdict
weight on its own; every closure below is backed by a fresh probe, an independent recomputation, or
git-derived evidence.

## 1. Custody (§0)

| Fact | Value | Verified |
|---|---|---|
| Branch | `phase/ulu-evren-control-plane` == origin | `git status/branch/rev-parse` |
| Candidate HEAD | `12300e66723d92cbfcafc6368cb1372ba3e1604f` | == origin == tag deref |
| Tag | `gen8-ulu-evren-control-plane-r1-audit-candidate` (object `fef8f54c…`) → `12300e6` | probe A13_01 |
| Round | exactly 6 commits over AUDIT12 verdict `b0039eb`: `3a94990` (pre-declaration, docs-only) → `bb8f76f` (A12-F2) → `43b82d2` (A12-F3) → `e9dc446` (A12-F4) → `3ced810` (R1 tests/views) → `12300e6` (blocker-law refinement) | `git log b0039eb..12300e6` |
| Surface | 16 files; `docs/audit` + `docs/control-plane` + `docs/requirements` + test target ONLY; **zero** production-source changes | diffstat + probe A13_02 |
| Working tree | clean | `git status` |

## 2. AUDIT12 closure matrix (§1 — no finding disappears)

| Finding | AUDIT12 severity | R1 claim | Independent re-audit result |
|---|---|---|---|
| A12-F2 orphan requirements | MEDIUM | CLOSED | **CLOSED — CONFIRMED.** Registry recomputed from source text: 36 unique IDs; map 36 unique records; REGISTRY SET == MAP SET; 0 orphans / 0 fakes / 0 duplicates / 0 DEFER / 0 SUPERSEDED; all owners exist; no RETIRED node exists at all; primary-owner bindings present on twin nodes; epochs consistent. Semantic ownership of all 12 former orphans verified against registry descriptions (§3 below). Probes A13_07–A13_14. Two **new LOW/INFO nuances**: A13-F2 (release_blocking field), A13-F9 (CP11 set-equality blind to duplicate records — caught only by my multiset law, probe A13_12). |
| A12-F3 broken/fabricated refs | MEDIUM | CLOSED | **CLOSED — CONFIRMED.** Independent recensus with my OWN classifier: 257 refs, **broken = 0**, ambiguous = 0; all 22 commit refs verified individually via `git rev-parse` (no prefix whitelist), all 6 tag refs exist, both fabricated tags still absent from git, P009D ref points at the genuine artifact. Semantic refs are never counted machine (partition law asserted). Probes A13_15–A13_19. One **new LOW finding in the closure artifact itself**: A13-F1 (alias-registry verdict inflation for AUDIT3/AUDIT5). |
| A12-F4 prose-first state enforcement | MEDIUM | CLOSED | **CLOSED AS WORK-READINESS ENGINE, with explicitly-pinned non-governing limitations.** No generic ACTIVE==satisfied rule anywhere in the evaluator (functional mutation proofs); typed contracts cover all 75 edges; single CANDIDATE_READY edge; computed==declared; hostile snapshots recomputed away; vanish laws complete; PRE-14-ACTIVE can never unlock corpus. Residuals (none can authorize wrong work): A13-F3 (no machine RELEASE-READY axis), A13-F4 (axis-evidence outcome-blindness), A13-F7 (CP04 residual generic text), lifecycle LOCK transition partly prose (§16 below). Probes A13_22–A13_32, A13_38. |
| A12-F1 counts | LOW | CLOSED (living) | CONFIRMED: view counts recomputed independently — 60 nodes / 75 edges / 10 programs / 22 blockers / 9 NTs match (A13_41). |
| A12-F5 blocked_by overload | LOW | CLOSED_WITH_LIMITATION | CONFIRMED carried: deprecated mirror still present, byte-stable; new structural gate lives only in `gates[]`; removal scheduled via ledger. A13-F6 (INFO) pins a schema-wording overstatement ("exactly"). |
| A12-F6 registry 35 vs 36 | LOW | CLOSED | CONFIRMED: single-line meta correction in the R1 commit only; entries untouched; RES-004 (A13_06, §28). |
| A12-F7 wave sink | LOW | CARRIED | CONFIRMED visible (remediation report; not claimed enforced) (A13_43). |
| A12-F8 progress B/C/D | LOW | CLOSED_AS_LABELED | CONFIRMED: all three labeled NARRATIVE PLANNING ESTIMATE, "never governs phase authorization"; overall 13.34 reproduced from documented weights (A13_42). |
| A12-F9 prose-hybrid refs | INFO | CARRIED | CONFIRMED: exactly 2 prose-hybrid source paths, honestly SEMANTIC in census (A13_43). |
| A12-F10 self-grade | LOW | CLOSED | CONFIRMED: CP privacy/security LAB_ONLY, audit PENDING, overall UNVERIFIED; RES-005 (A13_36). |
| A12-F11 stale ECE ledger row | INFO | CARRIED | CONFIRMED: CSV row keeps the historical `.220`; twin carries audited `.250` (A13_43). |
| A12-F12 partial vanish pins | INFO | CLOSED | CONFIRMED: complete 22+9 pins with ledger escape; full-census vanish attack: all 31 deletions unlawful (A13_34/35). |

## 3. Requirement semantic audit (§3)

Registry descriptions were read from `docs/requirements/REQUIREMENTS_REGISTRY.yaml` directly. All 12
former orphans have semantically legitimate primary owners; secondaries add real coverage; no cosmetic
attachment found: ADM-002→P009D-POLICY (deterministic precedence implemented lab-side,
PolicyConflictResolverV1/D-0024; production wiring secondary EP3-CONTENT-AHEAD) · BND-001→P003 (+P009A
hardening) · COST-001/PRI-001/REL-001/SEC-001→EP8 (production cost/deletion-export/DR-SLO/security
scope; PRI-001's perception-layer no-raw-retention law carried by P001/EP3-IOS secondaries) ·
**DVT-001→EP6-BOUNDED-LEARNING — registry text confirmed as DATA-RIGHTS ("Data rights before
cross-user reuse; private => GLOBAL_REUSE=DENY", owner family `data-rights`), NOT device trust** ·
EVD-001→P009C (EvidenceWeigherV1 provenance) · HSH-001→EP4-FAMILY-AUTHORITY (+ENTITLEMENT-SYNC
anti-sharing) · PROT-001→P006-SHIELD-GLYPH · SCO-002→EP3-PRESENTATION (+P009E) · TWIN-001→EP4-GROWTH-TWIN.
All 12 are release_blocking:true, epochs sensible, r1_note traceable (probe A13_09).

## 4. Full reference recensus (§5)

Own classifier (adds DECISION_ID and REQUIREMENT_ID machine classes; verifies every commit by
`git rev-parse`, every tag, every alias, every ledger anchor, every file/dir):
**total 257 · machine-resolvable 175 · semantic 82 · broken 0 · ambiguous 0** —
partition [FILE 77 · DIR 7 · ANCHOR 8 · COMMIT 22 · TAG 6 · ALIAS 16 · DECISION 8 · REQ-ID 0 ·
TEST-SYM 29 · SRC-SYM 2 · SEMANTIC 82]. The builder's 257/167/90/0 reproduces exactly under his
partition (the 8-machine-ref delta is my resolving of `D-xxxx` decision IDs, which he honestly classes
semantic). Reference mutations (fake file/tag/commit/anchor/alias/decision/requirement/test symbol) all
fail deterministically; a fake test symbol is demoted to SEMANTIC, never machine-resolved (A13_15/16).

## 5. Fabricated history & P009D (§6/§7)

`gen8-p009a-identity-foundation-locked-phase-c-ok` and `gen8-p009b-expert-mesh-r1-reaudit-pass` exist
in **no** git ref (full tag list enumerated) and were never retroactively created; twin carries typed
`NEVER_CREATED` + real commit anchors `4ce238f`/`42b96a2` (both verified full-SHA); fabricated strings
preserved only in frozen evidence; RES-001/002 + corrections record exist. Rollback truth machine-checked
on all 60 nodes: every EXISTS tag resolves AND its deref equals the node's rollback commit; NEVER_CREATED
⇒ empty tag + real commit; NOT_APPLICABLE ⇒ no anchors pretended (A13_17/18).
P009D: `docs/intelligence/P009D_POLICY_INTELLIGENCE.md` is genuinely the canonical artifact — title and
content match P009D scope; git shows it authored in the P009D era (first added `b50f592`, ancestor of the
lock merge `9c049f3`), not invented at R1; the dead path exists in NO living control-plane file
(correction records excepted); twin cites the real artifact (A13_19).

## 6. Alias registry (§8)

All 11 aliases AUDIT2..AUDIT12 resolve: unique report/probe paths, all files exist, all target/audit
SHAs real, no collision, no wrong-generation pointer (AUDIT12 → target 4d6649c / audit b0039eb).
Verdict fields: AUDIT2/4/6/7/9/10/12 match the report verdict lines verbatim; AUDIT8/11 are
class-preserving abbreviations. **A13-F1 (LOW, fresh):** AUDIT3 and AUDIT5 records carry PASS-class
paraphrases ("PASS WITH LIMITATION — ENGINEERING MESH LOCKED", "PASS WITH FINDING — …") while the
immutable reports' recorded verdicts are **`FIX CRITICAL P009B FINDINGS`** and **`FIX CRITICAL P009C
FINDINGS`** — a verdict-class upgrade by builder summary inside the canonical resolver (the same
inflation phrasing also sits in CURRENT_STATE's locked-chain table rows "AUDIT3/4 PASS", "AUDIT5/6
PASS", wording that predates R1). No authorization effect: no engine consumes the field; the lock
lineage rests on AUDIT4/AUDIT6 PASS, which are recorded exactly; CP10 validates only non-emptiness.
Required correction (post-audit, via resolution ledger): record the real first-round verdicts with an
explicit "superseded by AUDIT4/6 PASS" generation note. Pinned by probe A13_21.

## 7. State-engine audit (§10–§17)

- **No ACTIVE shortcut:** ACTIVE never satisfies LOCKED or GATE_PASS; unknown contract types fail
  closed (both engines); the evaluator contains no generic rule. Residual: CP04's *declared-set sanity
  check* still contains `LOCKED || ACTIVE` text — harmless (CP12 equality against the typed engine
  governs; a declared-READY node with an unlawful ACTIVE dep fails CP12) — **A13-F7 INFO** (A13_22).
- **Contracts:** 75 edges, one contract per edge exactly: 60 LOCKED / 14 GATE_PASS / 1 CANDIDATE_READY (A13_23).
- **CANDIDATE_READY census:** exactly one edge (CP-INDEPENDENT-AUDIT ← CP-CONTROL-PLANE). It demands
  ACTIVE/LOCKED candidate + implementation evidence + test evidence + no blocking blocker on the
  candidate + no standing FAIL verdict on the consumer. Blocker-laden, evidence-stripped, and
  random-ACTIVE-node (P001 w/ open BLK-H4) candidates all refused (A13_24).
- **Own-blocker/closer law (§12):** PRE-02/PRE-04/PRE-13 are work-startable at S1 while owning their
  open target blockers — correct closer semantics; unknown blocker IDs fail closed. The semantic
  danger (own blocker should still bind RELEASE) is contained: blocking RELATIONS live in
  contracts/gates, release stays bound by release.gate + CODE gates; EP3-PRESENTATION's BLK-C4 cannot
  be bypassed by its work-readiness (A13_25, A13_26).
- **Computed vs declared (§14):** live computed == declared == {CP-INDEPENDENT-AUDIT} (my engine and
  the builder's agree). Hostile snapshot flips (corpus READY, presentation READY, PRE-14 READY, W2
  EP6-BOUNDED-LEARNING READY, blocked_by emptied) are all recomputed away; emptied mirror also trips
  the blocked-without-reason law; snapshot status is never authority (A13_27/28).
- **Prose-gap scan (§15):** S1 unlock census is EXACTLY {RWC-PRE-01..05, PRE-13, EP3-CONTENT-AHEAD};
  no node whose prose prohibits until PRE-14/RWC-program/EP3-PRESENTATION can engine-READY before its
  structural gate; EP3-CONTENT-AHEAD's once-prose CP gate is structural in `gates[]`; corpus/annotation/
  fit/heldout all carry the structural PRE-14 gate; EP4+ stays closed even at S10. Remaining prose-only
  gates are RELEASE-time gates by design (see A13-F3). **A13-F6 INFO:** schema addendum says mirror ==
  gates[] "exactly" while the law (deliberately) lets gates exceed the mirror (A13_29).
- **Transitions (§16):** PLANNED→READY machine-computed; READY→BLOCKED/ACTIVE→BLOCKED expressible via
  recompute; ACTIVE→LOCKED under a standing FAIL/FIX verdict machine-refused with the resolution-ledger
  escape as only door; **honest classification: a hostile LOCK with no verdict at all is NOT refused by
  a generic machine law** — today it is caught by the suite's status pins (CP04/CP05/CP12 equalities),
  i.e., NODE LIFECYCLE enforcement is machine-pinned for the dangerous instances but still partly prose
  as a general law. The builder does not overclaim this (schema addendum scopes the transition law to
  axes + verdict coherence). Carried as explicit non-governing limitation (A13_30).
- **Verdict coherence (§17):** LOCKED + "FIX REQUIRED"/"FAIL" without resolution fails; live twin: all
  LOCKED nodes carry PASS-class audit status; a standing FAIL on a node also vetoes its readiness (A13_24/30).
- **Contradiction laws (§18):** CONTRADICTED→VWL without resolution illegal; with resolution but
  without axis-compatible evidence still illegal (P008 calibration case); the ledger carries no P008
  subject, so a "fake resolution" context is unconstructible from canonical data (A13_31).
- **Axis evidence depth (§19):** device-VERIFIED-without-device-refs and calibration claims refused;
  calibration VERIFIED is additionally impossible anywhere (CP05 pin + live scan). **A13-F4 (LOW):**
  the law is EXISTENCE-only — a verified-class privacy/security claim backed by an audit ref whose
  VERDICT is failing would pass (`axisEvidenceLaw` never reads outcomes). Not exploitable on the live
  twin (all LOCKED nodes PASS-class; no verified axis rests on a failing-audit-only ref); it is a
  forward-hardening requirement for RWC phases (A13_32).
- **human_product (§20):** never upgradable today (empty evidence-class list + live scan); forward
  path is versioned, not a dead end — authority matrix names the owning class
  REAL_WORLD_HUMAN_CALIBRATION with explicit unavailability note; no ad-hoc weakening door (A13_33).
- **Authority matrix (§23):** all three mandated conflicts resolve correctly in the declared law
  (builder-device-VERIFIED cannot stand on BUILDER_CLAIM/lab classes; view never beats twin; device may
  improve while privacy may not; audit FAIL survives newer builder PASS prose); no one-dimensional
  global ranking. **Honest classification: the matrix is DECLARATIVE with partial machine anchors** —
  the evaluator hard-codes the device/calibration/CONTRADICTED anchors and CP15 checks matrix presence,
  but no engine consumes the matrix file itself (pinned, A13_37).

## 8. Work-vs-release readiness (§12/§13 — the S10 hard case)

At S10 (held-out PASS + device-E2E PASS simulated, production score code gate CLOSED), four answers:

1. **May Presentation implementation begin?** YES — EP3-PRESENTATION is work-ready (graph: both
   GATE_PASS deps satisfied; `next.allowed_when` met). This matches the builder's S8b expectation and is
   *intended*: READY in this engine is WORK-START readiness.
2. **May Presentation release?** NO — `release.gate` = "ProductionScoreReleaseGateV1 + RWC audits";
   the CODE gate evaluates false and no graph state can open it.
3. **May a numeric score be displayed?** NO — `productionDisplayAllowed()` false; display structurally OFF.
4. **May production admission proceed?** NO — EP8-PRODUCTION-CIVILIZATION / EP8-RELEASE-WAVES are not
   even work-ready at S10 (deps unpassed); exact S10 ready set = {EP3-PRESENTATION, EP3-CONTENT-AHEAD}.

**A13-F3 (LOW, fresh):** the status machine carries a SINGLE generic READY — WORK-READY ≠ LOCK-READY ≠
RELEASE-READY ≠ CAPABILITY-AVAILABLE are not machine-representable states (`node_statuses` has no
release-readiness axis). The collapse **authorizes nothing forbidden** (answers 2–4 are independently
refused by code gates + THREE_VERDICT audit law + graph deps), and the twin's data model does separate
entry (`next.allowed_when`) from release (`release.gate`) in prose. Required hardening before the
control plane ever *governs* release decisions: a typed release-readiness representation (or an explicit
machine law that READY may never be read as release authority). Pinned by A13_26.

## 9. Independent RWC future-state ladder (§24/§25 — own simulation, own engine)

S0 live → ready == {CP-INDEPENDENT-AUDIT} ✔ · S1 CP PASS → exactly {PRE-01..05, PRE-13,
EP3-CONTENT-AHEAD}; PRE-06 waits for PRE-05 ✔ · S2 PRE-07 missing (different hole than the builder's
test) → PRE-14 refused ✔ · S3 all 13 → PRE-14 ready ✔ · S4 PRE-14 merely ACTIVE → corpus refused by
BOTH engines, hostile corpus-READY flip recomputed away ✔ · S5 PRE-14 PASS → corpus ready ✔ · S6 corpus
done, annotation absent → fit refused ✔ · S7 annotation done → fit ready ONLY via the canonical door
(node law "MUST enter via CalibrationRunPreparationV1", RWC-PRE-04 invariant) ✔ · S8 fit done, held-out
absent → presentation AND device-E2E refused ✔ · S9 held-out done, device absent → presentation refused,
device-E2E itself becomes work-ready (it is the closer of BLK-DEVICE-RWC-OPEN) ✔ · S10 → §8 above ✔.
**PRE-04 canonical door:** BLK-A11-APIBYPASS still OPEN, owned by RWC-PRE-04, NT-APIBYPASS present;
PRE-14 carries a LOCKED contract on PRE-04; with everything passed EXCEPT PRE-04, PRE-14/corpus/fit all
stay refused; RWC-FIT's gate is PRE-14. No fitting occurred in this audit: dataset 59 pairs, guard v2
(A13_38/39).

## 10. AUDIT12 inversion discipline (§27)

Frozen original SHA-256 == `4671898b…24a20` byte-exact ✔. Manifest commit `3a94990` (15:01:33) is a
strict git ancestor of the first inverting commit `bb8f76f` (15:06:28) ✔. Frozen-vs-active diff
recomputed independently: 45 added / 40 removed lines (multiset), ALL inside the five declared probes
(A12_05/06/08/09/16); characterization probes A12_22–26/36 byte-untouched; historical 4d6649c census
preserved in the frozen original only ✔. Historical AUDIT12 report touched by exactly one commit (its
own) ✔. **Double re-pin judgment:** the census was re-pinned twice inside the round (251/161 at
43b82d2 → 257/167 at e9dc446, after six chain-audit refs were added at the A12-F4 commit). The manifest
binds the census "re-derived against the R1 candidate" — the candidate is the final tagged state, so the
final 257 pin is the binding one and the intra-round intermediate is lawful; **however** the intermediate
251/161 figure remains printed in the LIVING correction record (`CONTROL_PLANE_R1_REFERENCE_CORRECTIONS.md`),
now disagreeing with the final census — **A13-F5 INFO** (A13_05/41).

## 11. Requirement count & history (§28), rollback truth (§29), views (§30), progress (§31)

Registry: 36 entries; R1 diff = exactly the one meta-count line (entries unchanged); file history =
authoring commit + R1 commit only; RES-004 explicit ✔ (A13_06). Rollback truth: §5 above, all 60 nodes
machine-tested ✔. Views: CURRENT_STATE R1 correction section matches my independent recount
(60/75/10/22/9; census agrees under the AUDIT12 classifier); no view implies the control plane governs;
no view says any RWC-PRE started ("Zero corpus, zero human annotation, zero real fitting"); no view
calls the score production-calibrated ("real-world calibrated" stays a FORBIDDEN CLAIM row); the
NEXT_ALLOWED_WORK forbidden list is intact ✔ (A13_41). Progress: overall 13.34 reproduced from the
documented weights (view rounds to ≈13%); B/C/D all carry NARRATIVE PLANNING ESTIMATE and the
never-governs clause; no numeric validation demanded of narrative estimates ✔ (A13_42).

## 12. Mutation results summary (§4/§9/§14/§18/§21/§22)

31/31 vanish deletions (22 blockers incl. BLK-GH-CREDENTIALS/BLK-H3/BLK-C4/BLK-ECE-UNMET/
BLK-DEVICE-RWC-OPEN/BLK-A11-APIBYPASS + 9 NTs incl. NT-PREVDWELL/NT-THERMAL-EVIDENCE-BUILD/
NT-P008-PILOT-FAILED/NT-F1-COVERAGE/NT-APIBYPASS) unlawful without ledger records — no famous-subset
shortcut. Requirement mutations: delete/fake/ghost-owner/retired-owner/bad-defer all caught; duplicate
record caught **only by my multiset law** (CP11's Set equality is duplicate-blind — A13-F9 INFO).
Reference mutations: 6/6 machine-shaped fakes individually flagged; fake symbols never machine-counted.
State mutations: PRE-14-ACTIVE, blocker-laden candidate, evidence-stripped candidate, FAIL-verdict
consumer, 5 hostile snapshots, contradiction upgrades, device/human/privacy/security axis attacks —
all refused or (where the law is existence-blind) pinned as A13-F4.

## 13. Fresh findings (all pinned by green probes; none blocks the verdict)

| ID | Severity | Finding | Why not higher |
|---|---|---|---|
| **A13-F1** | **LOW** | Alias-registry verdict-class inflation: AUDIT3/AUDIT5 recorded as PASS-class while the immutable reports end `FIX CRITICAL P009B/P009C FINDINGS` (same phrasing echoed in CURRENT_STATE's "AUDIT3/4 PASS" rows). FM-003/history-domain discipline violated in the resolver's convenience field. | Zero authorization effect (no consumer; locks rest on AUDIT4/6 PASS recorded exactly; report/probe/SHA resolvers all correct). MUST be corrected via resolution ledger with a generation note before the registry is ever consumed programmatically. Probe A13_21. |
| **A13-F2** | **LOW** | Map `release_blocking:false` on 14 requirements that the registry declares P0 (= release-blocking): ADM-001, CDNA-001, COG-001, IDR-001, OPS-001, OPS-002, PAI-001, PROT-002, PUB-001, SCO-001, TMP-001, TMP-002, UX-001, VAL-001. Voids CP11's never-silently-defer brake for exactly those 14; field semantics undefined in the schema. | No live effect (0 DEFER dispositions; readiness never reads the field; any future defer is a canonical edit requiring a new audited candidate). Probe A13_10. |
| **A13-F3** | **LOW** | Single generic READY: WORK/LOCK/RELEASE/CAPABILITY readiness not machine-distinguishable; release gates remain prose + code. | Collapse authorizes nothing (S10 four-answer proof; code gates + THREE_VERDICT independently bind release/display/admission). Hardening precondition for any future release-governing role. Probe A13_26. |
| **A13-F4** | **LOW** | `axisEvidenceLaw` is outcome/relevance-blind (evidence-class EXISTENCE only): privacy/security VERIFIED backed by a failing-verdict audit ref would pass. | Not exploitable on the live twin (verified by scan; CP05 pins calibration; verdict-coherence pins LOCKED nodes). Forward-hardening for RWC. Probe A13_32. |
| A13-F5 | INFO | Living corrections record still prints the superseded intra-round census 251/161 (final: 257/167). | Count drift in a correction doc; canonical census pinned in suite + CURRENT_STATE. Probe A13_41. |
| A13-F6 | INFO | Schema addendum says mirror == gates[]+blockers "exactly"; enforced law is one-directional by design (EP3-CONTENT-AHEAD's new gate lives only in gates[]). | Doc wording vs law; fail-closed either way. Probe A13_29. |
| A13-F7 | INFO | CP04 declared-set sanity check retains a generic `LOCKED || ACTIVE` acceptance. | Redundant weaker check; CP12 typed equality governs. Probe A13_22. |
| A13-F8 | INFO | Resolution-ledger `effective_commit: "CP-R1"` is a symbolic, non-machine-resolvable placeholder. | Honest-at-authoring (the candidate SHA cannot predate its own commit); re-anchor to `12300e6` at lock time. Probe A13_36. |
| A13-F9 | INFO | CP11's Set-based completeness equality is blind to duplicate map records. | Duplicates caught by my multiset law; none exist; add multiset check post-audit. Probe A13_12. |

## 14. Production-code truth (§26) & locks

`ProductionScoreReleaseGateV1.evaluate().0 == false` · `productionDisplayAllowed() == false` ·
`calibrationClass == .engineeringOnly` · `supportsRealWorldClaims == false` · `pairs.count == 59` ·
guard `calibration-run-guard-v2` — all freshly asserted (A13_40). Graph agrees with code everywhere;
the control plane cannot override code gates. CP-CONTROL-PLANE itself: ACTIVE, overall UNVERIFIED,
audit PENDING — **non-governing** until this verdict is recorded and locked (A13_44).

## 15. Final truth matrix

| Claim | Verdict |
|---|---|
| A12-F2 genuinely closed | **YES** (recomputed; semantic spot-check of all 12) |
| A12-F3 genuinely closed | **YES** (independent census broken=0; fabricated tags absent; P009D genuine) |
| A12-F4 closed / reduced to non-authorizing limitations | **YES** (typed engine real; residuals pinned, none can authorize wrong work) |
| New CRITICAL/HIGH/MEDIUM | **NONE** (4 LOW + 5 INFO, all pinned by green probes) |
| Engine can authorize corpus early | **NO** (S2/S4/PRE-04-hole attacks refused by both engines) |
| Fake rollback/evidence; orphans; axis inflation; historical rewrite | **NONE found** |
| WORK-vs-RELEASE ambiguity permits forbidden release/admission | **NO** (four-answer proof) |
| Production score blocked; display off; dataset frozen | **YES** (code-level fresh asserts) |
| Control plane governing today | **NO** (and may become governing only via this PASS being recorded/locked) |

## 16. Verdict

**PASS — ULU EVREN CONTROL PLANE R1 LOCKABLE; CONTROL PLANE MAY BECOME GOVERNING EXECUTION INDEX;
RWC PREREGISTRATION PREPARATION NEXT; CORPUS / ANNOTATION / FITTING / HELD-OUT / PRODUCTION SCORE /
PRESENTATION RELEASE REMAIN BLOCKED**

Conditions attached to the lock (non-blocking, ledger-tracked): correct A13-F1 (alias verdicts, with
generation notes) and A13-F2 (release_blocking semantics vs registry P0) via resolution-ledger records
in the closeout round; A13-F3/F4 are hardening preconditions before the control plane ever *governs
release decisions* (it governs work scheduling only). Next authorized phase after closeout:
**RWC PREREGISTRATION PREPARATION** (the control plane may then issue its first phase packets).
