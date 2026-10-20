# GEN8 CONTROL PLANE — R1 REMEDIATION REPORT (2026-10-20)

Builder round closing AUDIT12's MEDIUM findings with their real root causes. Start HEAD `b0039eb`
(AUDIT12 verdict commit; target `4d6649c`). Baseline remeasured before any change: **749/749**.
Scope law obeyed: no product feature, no corpus, no annotation, no fitting, no held-out, no score
unlock, no Presentation. The control plane remains **NON-GOVERNING** until independent R1 re-audit PASS.
Discipline: AUDIT12 frozen original SHA `4671898b…` + pre-declared inversion manifest
(`docs/audit/AUDIT12_INVERSION_LOCK.md`, committed BEFORE any inverting change; exactly 5 declared
inversions I-1…I-5; the characterization probes of the old law's blindness are NOT inverted).

## Finding matrix

| Finding | Root cause | Exact change | Fresh evidence | Status | Residual risk |
|---|---|---|---|---|---|
| **A12-F2** (MEDIUM, 12 orphan P0 requirements) | twin was built from node-first mapping; registry never diffed against the graph | `GEN8_REQUIREMENT_NODE_MAP.yaml` — 36/36 explicit dispositions (all MAP_EXISTING_NODE; semantic reasons read from registry TEXT — notably DVT-001 = data-rights→EP6-BOUNDED-LEARNING, not "device trust"); primary-owner bindings added to twin nodes (depends_on untouched); completeness LAW machine-enforced (CP11: registry IDs == mapped IDs, generic node-requirement validation, DEFER rules incl. release-blocking-never-silently-deferred) | CP11 + `testR1_RequirementMapComplete` + `testR1_M8` (fake ID generically refused) + inverted A12_05 (orphans == []) | **CLOSED** | ownership quality is semantic judgment — re-auditor should spot-check dispositions against registry text |
| **A12-F3** (MEDIUM, 3 broken refs; "broken=0" false) | I hand-typed plausible tag names/paths without verifying against git/filesystem; CP07 validated only 5 hardcoded paths | fabricated P009A/P009B tags removed via typed `rollback.tag_status: NEVER_CREATED` (+ verified commit anchors 4ce238f/42b96a2; **no retroactive tag creation**); P009D ref → independently-verified real artifact `docs/intelligence/P009D_POLICY_INTELLIGENCE.md`; `CONTROL_PLANE_R1_REFERENCE_CORRECTIONS.md` (honest record); `GEN8_AUDIT_ALIAS_REGISTRY.yaml` (deterministic AUDIT2..12 resolvers); `GEN8_RESOLUTION_LEDGER.yaml` (RES-001..005); CP10 full machine-ref resolution (files/dirs/tags/anchors/aliases — no shortcut) | CP10 broken==[] + `testR1_ReferenceCorrectionsHonest` (fabricated tags still absent from git) + inverted A12_08 (census re-derived 257/167/90/0) + inverted A12_09 (typed rollback truth) | **CLOSED** | commit resolvability uses a verified prefix set (git exec per-commit avoided for suite speed); semantic refs (90) remain honestly non-machine |
| **A12-F4** (MEDIUM, prose-first enforcement) | READY/transition/authority laws existed as prose; validator used generic `LOCKED-or-ACTIVE==satisfied` + hardcoded equality pins | `ControlPlaneStateEvaluatorV1` (test-target tooling): typed `dependency_contracts` (LOCKED/GATE_PASS/CANDIDATE_READY; **global ACTIVE rule abolished**; CANDIDATE_READY = single declared edge requiring candidate evidence + blocker-free ACTIVE candidate); canonical `gates[]` registry — building it immediately caught a REAL gap: EP3-CONTENT-AHEAD's CP-audit gate was prose-only at 4d6649c, now structural; computed readiness == declared (CP12); machine transition laws (CONTRADICTED-needs-resolution-record, axis-specific evidence `axisEvidenceLaw`, human_product never-upgradable, verdict↔status coherence); domain-aware `GEN8_EVIDENCE_AUTHORITY.yaml` (CP15); complete vanish-pins with resolution-ledger escape (CP14); evaluator forbidden-state law (CP16) | 9 mutation proofs in `ControlPlaneR1RemediationTests` (M1: PRE-14 ACTIVE never unlocks corpus + hostile snapshot flip recomputed away; M2 blocker-laden candidate; M3 evidence-stripped candidate; M4 contradiction upgrade; M5 device-VERIFIED-without-device-ref; M6 human axis; M7 verdict coherence; M8 fake REQ; M9 full vanish coverage incl. BLK-GH-CREDENTIALS/NT-PREVDWELL) + typed future-state ladder S1-S8b | **CLOSED** | wave-order certification gate remains a structural sink (A12-F7, carried LOW — the state engine does NOT claim wave order is structurally enforced); `blocked_by` kept as deprecated byte-stable legacy mirror for frozen probes (removal scheduled post-audit via resolution ledger) |
| A12-F1 (LOW, summary counts) | hand-typed counts in builder summary/views | `CURRENT_STATE.md` R1 correction section — counts now computed (60/75/10/22/9; census 257/167/90/0) | inverted A12_08 census; view section | **CLOSED** (living) — historical summary text immutable | counts must be re-derived per candidate |
| A12-F6 (LOW, registry 35 vs 36) | ACC-001 uncounted at authoring | living metadata corrected to 36 (+explanation); twin source note corrected; RES-004 | inverted A12_06 | **CLOSED** | none |
| A12-F10 (LOW, self-grade) | I graded CP privacy/security VWL pre-audit | honest LAB_ONLY on both axes (RES-005) | inverted A12_16 + CP13 live law | **CLOSED** | — |
| A12-F12 (INFO, partial vanish-pins) | hardcoded famous-blocker lists | CP14: COMPLETE 22-blocker + 9-NT pins with resolution-ledger escape | `testR1_M9` | **CLOSED** | pin lists update with registries via ledger |
| A12-F5 (LOW, blocked_by overload) | one field, two semantics | canonical `gates[]` + blockers[] split; `blocked_by` = deprecated byte-stable legacy mirror (frozen AUDIT12 probes depend on it); every mirror entry must exist in canonical registries (CP12) | CP12 | **CLOSED_WITH_LIMITATION** | mirror removal pending post-audit resolution |
| A12-F7 (LOW, wave sink) | — | carried; state engine documents (not claims) wave enforcement | A12_29 unchanged | **CARRIED** | future structural wave gate |
| A12-F8 (LOW, progress B/C/D) | narrative estimates | relabeled **NARRATIVE PLANNING ESTIMATE**, "never governs phase authorization" | view diff | **CLOSED_AS_LABELED** | B/C/D reproducibility is future work |
| A12-F9/F11 (INFO) | — | carried unchanged (prose-hybrid source paths typed semantic; stale ECE 0.220 ledger row immutable, twin uses audit value) | A12_13/A12_18 unchanged | **CARRIED** | — |

## Verification

Baseline 749/749 (remeasured pre-change) · per-commit focused greens · full suite ×2 at candidate
(see return report) · production runtime sources: **zero changes** (allowed surface only:
docs/control-plane + docs/requirements metadata + docs/audit discipline artifacts + test tooling) ·
all code locks re-asserted (score gate CLOSED, display OFF, engineeringOnly, supportsRealWorldClaims
false, guard v2, 59 pairs).

## Locks

Control plane **NON-GOVERNING** · RWC preregistration NOT started · corpus/annotation/fitting/held-out
FORBIDDEN · production score BLOCKED · Presentation/Glyph/Motion BLOCKED.

## Next

Single permitted next step: **INDEPENDENT CONTROL-PLANE R1 RE-AUDIT** of the new candidate tag.
