# CANONICAL SECTION COVERAGE MATRIX

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** PROMPT 000A §6. Maps **every** Build Bible canonical section (§0–§656 + Appendices A–H) to a disposition so the reviewer can answer *"where did this exact decision go?"* **No canonical section silently disappears.**

**Disposition codes:** `REQ` (requirement id) · `ADR` · `DOC` (canonical doc) · `SUP` (superseded — by) · `INFO` (informational/non-normative, captured in Master Spec) · `DEFER` (post-P0 backlog, still tracked). Section titles per `BIBLE_SECTION_INDEX.md`.

## Coverage summary
- Sections accounted for: **§0–§656 (657) + Appendices A–H (8) = 665 / 665.**
- **Unmapped: 0.**
- Superseded decisions explicitly flagged: §63 (OCTOPUS 12→20), §113 (repo shape), §458–§462/§579–§595 (persistent Star → Pure Bar).
- Requirements expanded this pass: 30 → **35** (added OPS-002, OPS-003, UX-002, AI-002, VAL-002 — only where a binding gate lacked a stable ID; see REQUIREMENTS_REGISTRY meta).

---

## Core v1.0 — §0–§135 + Appendices
| § | Disposition | Where |
|---|---|---|
| §0 | INFO | Master Spec §1 (file mission) |
| §1 | DOC | Constitution Art I (Claude role) |
| §2 | DOC | DECISION_LEDGER (precedence) |
| §3 | DOC | Constitution Art XII (USER AGENCY) |
| §4 | DOC | CLAUDE §1 + Constitution (25 rules) |
| §5–§6 | DOC | Master Spec §0 (identity, 3 surfaces) |
| §7 | DOC+REQ+DEFER | Master Spec §10; SCREEN_STATE_INVENTORY; SOC reqs P1 |
| §8 | DOC+DEFER | Master Spec §10 (inbox) P1 |
| §9 | REQ | PUB-001; Master Spec §10 (publishing) |
| §10 | DOC+DEFER | Master Spec §10 (quick editor) P1 |
| §11 | DOC+DEFER | Master Spec §10 (network) P1 (NET) |
| §12 | DOC+DEFER | Master Spec §10 (platform algo) P2 |
| §13 | INFO | EVALUATION_MASTER_PLAN (no fake viral) |
| §14 | INFO | Master Spec (10 impact modules) |
| §15 | REQ | PER-001; Master Spec §2 |
| §16 | ADR+DOC | ADR-0004; PLATFORM_CAPABILITY_MATRIX (RCOV) |
| §17 | REQ+DOC | PER-001; CORE_DOMAIN_BOUNDARIES |
| §18 | DOC | DEVICE_NATIVE_RUNTIME_CONSTITUTION (adaptive sensing) |
| §19 | REQ | BND-001 |
| §20 | REQ | IDR-001 |
| §21 | REQ | COG-001 |
| §22–§36 | DOC+REQ | Master Spec §3 (cognition/energy/symbolic engines); COG-001 |
| §37 | REQ | EVD-001 |
| §38 | DOC | Master Spec §4 (source lineage) |
| §39 | REQ | EVD-001 (high-risk domain) |
| §40 | REQ | TWIN-001 |
| §41 | DOC | Master Spec §6 (behavior≠intent) |
| §42–§45 | DOC+REQ | Master Spec §6 (skill/dev-delta/curriculum/decay); TWIN-001 |
| §46–§47 | REQ | PAI-001 (Personal Algorithm + threshold) |
| §48 | DOC | Master Spec §6 (exploration) |
| §49 | REQ+DOC | SCO-001; SCORE_CONTRACT_FRAMEWORK |
| §50 | REQ | SCO-001 (ScoreContract) |
| §51 | REQ | SCO-001 (PBS); PBS_v0.1.yaml |
| §52 | REQ | SCO-001 (confidence separate) |
| §53 | DOC | SCORE_CONTRACT_FRAMEWORK (pre/post-view) |
| §54 | REQ | VAL-001 (learning verification) |
| §55–§59 | DOC | Master Spec §9 (knowledge-to-action/outcome/metacog/opp-cost/repetition) |
| §60 | REQ | SCO-002 (nutrition label / why-this-score) |
| §61 | DOC | FAILURE_TAXONOMY + EVALUATION (warning taxonomy) |
| §62 | INFO | Constitution (positive development) |
| §63 | SUP | → OCTOPUS 20 arms (D-0007); Master Spec §8 |
| §64 | DOC | AGENT_REGISTRY (multi-model council) |
| §65 | DOC | CLAUDE §2 (epistemic states) |
| §66 | REQ+DOC | VAL-001; LEARNING_AND_DRIFT_PLAN (failure memory) |
| §67 | REQ+DOC | SEC-001; THREAT_MODEL (adversarial immune) |
| §68 | DOC | LEARNING_AND_DRIFT_PLAN (controlled evolution) |
| §69 | REQ | VAL-001; CALIBRATION_PLAN |
| §70 | INFO | Master Spec §9 (human impact graph) |
| §71 | REQ | PRI-001 |
| §72 | REQ | PRI-001 (sensitive surface guard) |
| §73–§77 | REQ+DOC | FAM-001/CHD-001; PRIVACY_MODEL (family) |
| §78–§79 | DOC+DEFER | Master Spec §10 (creator bridge) P2 |
| §80 | DEFER | SCREEN_STATE_INVENTORY (coach) P1 |
| §81 | INFO | Constitution Art XII (stop when enough) |
| §82 | REQ | VAL-001 (feedback) |
| §83 | REQ | TWIN-001 (inspect/reset/export) |
| §84 | REQ+DOC | ADM-001; DEVICE_NATIVE_RUNTIME (fast/deep pipeline) |
| §85 | REQ | CDNA-001 (intelligence cache) |
| §86 | REQ+DOC | AI-001; MODEL_REGISTRY (cost/energy governor) |
| §87–§89 | DOC | AGENT_REGISTRY (Agent OS, score dims, specialists) |
| §90 | DOC | SKILL_REGISTRY |
| §91 | DOC | PRIVACY_MODEL + OBSERVABILITY (no CoT storage) |
| §92 | DOC | CORE_DOMAIN_BOUNDARIES (data models) |
| §93 | DOC | EVENT_CONTRACTS |
| §94 | DOC | SYSTEM_CONTEXT + Master Spec (planes) |
| §95–§97 | DOC | CONTAINER_ARCHITECTURE (monolith/local-cloud/storage) |
| §98 | DOC | API_CONTRACTS |
| §99 | REQ+DOC | SEC-001; THREAT_MODEL |
| §100 | DOC | THREAT_MODEL (crypto-agility) |
| §101 | REQ+DOC | REL-001; FAILURE_TAXONOMY |
| §102 | DOC | OBSERVABILITY_SPEC |
| §103 | REQ | ACC-001 |
| §104–§106 | DOC+DEFER | SCREEN_STATE_INVENTORY (UX surfaces) |
| §107 | DOC | DESIGN_SYSTEM_CONSTITUTION (screen states) |
| §108 | DOC+DEFER | COST_MODEL (business model) |
| §109–§110 | DOC+DEFER | Master Spec (Growth OS + safety) P1 |
| §111 | REQ+DOC | VAL-001; EVALUATION_MASTER_PLAN |
| §112 | INFO | Master Spec (cold start) |
| §113 | SUP | → repo shape §46 / D-0003; CONTAINER_ARCHITECTURE |
| §114 | DOC | CLAUDE §3 (coding discipline) |
| §115 | DOC | REQUIREMENTS_REGISTRY (ID families) |
| §116 | REQ | 30+ P0 requirements; REQUIREMENTS_REGISTRY |
| §117 | DOC | P0_EXECUTION_DAG (first vertical slice) |
| §118–§119 | DOC | P0_EXECUTION_DAG (phases + DAG rules) |
| §120 | DOC | CLAUDE §4 (DoD) |
| §121–§122 | DOC | EVALUATION_MASTER_PLAN (test/adversarial matrix) |
| §123 | DOC | DEVICE_TEST_MATRIX + PRE_EXPOSURE_SLO (SLO process) |
| §124–§125 | DOC | FAILURE_TAXONOMY (disaster + safe-stop) |
| §126 | DOC | Constitution Art IX (change control) |
| §127 | DOC | PROJECT_REALITY_REPORT + this matrix (required artefacts A–Z) |
| §128 | DOC | REQUIREMENTS_TRACEABILITY_MATRIX |
| §129 | DOC | PROJECT_REALITY_REPORT §5 (modules) + D-0002 |
| §130 | DOC | CLAUDE (build mode) |
| §131 | DOC | Constitution Art XII |
| §132–§135 | INFO | Master Spec §0 (final loop/moat/success/build command) |
| App A | DOC | SCORE_CONTRACT_FRAMEWORK (template) |
| App B | DOC | AGENT_REGISTRY (manifest template) |
| App C | DOC | SKILL_REGISTRY (contract template) |
| App D | DOC | ADR files (template) |
| App E | DOC | REQUIREMENTS_TRACEABILITY_MATRIX (evidence template) |
| App F | DOC | PROJECT_REALITY_REPORT (go/no-go) + §13 report |
| App G | DOC | P0_EXECUTION_DAG (canonical P0 demo) |
| App H | INFO/SUP-subordinate | Inherited generic protocol; subordinate to constitution (Bible 3467–3469); THIRD_PARTY/CLAUDE discipline |

## Appendix H proper — §BÖLÜM 1–22 (lines 3465–4689)
| Block | Disposition | Where |
|---|---|---|
| BÖLÜM 1–22 (generic work discipline) | INFO | Constitution (doctrine) + CLAUDE (work discipline); no product-specific binding content (verified by full read) |

## v1.1 Whole-Person Protection — §136–§160
| § | Disposition | Where |
|---|---|---|
| §136 | REQ | PROT-001 (WPP constitution) |
| §137 | DOC | Master Spec §5 (harmful exposure ontology) |
| §138–§139 | DOC | CORE_DOMAIN_BOUNDARIES (WholePersonImpactVector, PersonalProtectionProfile) |
| §140–§141 | DOC | Master Spec §5 + Constitution (spiritual firewall) |
| §142–§147 | DOC+REQ | PROT-001 (priming/visual/distress/doom/budgets/decision engine) |
| §148 | REQ | PROT-001 (GREEN/AMBER/RED/GREY) |
| §149 | REQ | CHD-001 (age/family sensitive policy) |
| §150–§153 | DOC | Master Spec §5 (physical/psych/social/human-impact priority) |
| §154 | SUP | → OCTOPUS 20 (D-0007) |
| §155 | DOC | Master Spec §5/§7 (updated pipeline) |
| §156 | DOC | Master Spec §2 (ContentDNA 17 types); CDNA-001 |
| §157 | DOC | SCREEN_STATE_INVENTORY (MY ALGORITHM/PROTECTION UX) |
| §158 | REQ | PROT-001/PROT-002 (updated P0) |
| §159 | DOC | EVALUATION_MASTER_PLAN (updated eval sets) |
| §160 | DOC | Constitution Art II (acceptance) |

## v1.2 Semantic Shield / Live Surface — §161–§182
| § | Disposition | Where |
|---|---|---|
| §161 | REQ | PROT-002 (two authorities) |
| §162 | DOC | CORE_DOMAIN_BOUNDARIES (SemanticShieldRule) |
| §163–§164 | REQ | PROT-002 (entity resolution, multimodal match) |
| §165 | REQ | PROT-002 (false-positive constitution) |
| §166 | REQ | PROT-002 (exclusion memory) |
| §167–§171 | DOC | GUARDIAN_VISUAL_CONSTITUTION (live surface, Score Orb, Quick Insight) |
| §172–§173 | DOC | PRE_EXPOSURE_SLO + DEVICE_NATIVE_RUNTIME (latency, match cache) |
| §174–§175 | DOC | PLATFORM_CAPABILITY_MATRIX (capability registry + watcher) |
| §176 | ADR | ADR-0007 (4-layer model) |
| §177 | SUP→DOC | OCTOPUS 20 (D-0007); AGENT_REGISTRY |
| §178–§179 | DOC | LEARNING_AND_DRIFT_PLAN (loops; self-renewing not self-governing) |
| §180 | REQ | updated P0/P1 acceptance |
| §181 | DOC | FAILURE_TAXONOMY (release-blocking truths) + capability matrix global rules |
| §182 | INFO | Master Spec (v1.2 architecture) |

## v1.3 Guardian Control Center / Always-On — §183–§218
| § | Disposition | Where |
|---|---|---|
| §183–§186 | DOC | DEVICE_NATIVE_RUNTIME (control center, modes, runtime state machine) |
| §187–§188 | DOC+REQ | DEVICE_NATIVE_RUNTIME + MODEL_REGISTRY (4-tier stack, router); AI-001 |
| §189–§193 | REQ+DOC | OPS-002 + DEVICE_RESOURCE_BUDGETS (resource/battery/thermal/memory/network) |
| §194–§195 | DOC | LEARNING_AND_DRIFT_PLAN (on-device brain, personal adaptation) |
| §196–§203 | DOC | PLATFORM_CAPABILITY_MATRIX (multi-OS A–D + per-OS) |
| §204–§208 | DOC | GUARDIAN_VISUAL_CONSTITUTION + DEVICE_NATIVE_RUNTIME (UX/trust/status/background/contract) |
| §209 | DOC | PLATFORM_CAPABILITY_MATRIX (continuous capability intelligence) |
| §210 | REQ | OPS-002/UX-001 (False-Protected=0 SLO) |
| §211 | DOC | DEVICE_TEST_MATRIX (test lab) |
| §212–§213 | DOC | MODEL_REGISTRY (packaging, update) |
| §214–§215 | DOC | DEVICE_RESOURCE_BUDGETS + LEARNING_AND_DRIFT_PLAN |
| §216 | DEFER | DESIGN_SYSTEM (premium/elite) |
| §217–§218 | INFO | Master Spec (v1.3 architecture/principle) |

## v1.4 Anticipatory Guardian / Pre-View Gate — §219–§243
| § | Disposition | Where |
|---|---|---|
| §219–§222 | REQ | ADM-001 (pre-view gate, truth classes, candidate queue, fan-out) |
| §223–§224 | REQ+ADR | ADM-002; ADR-0007 (admission controller + precedence) |
| §225 | DOC | DEVICE_NATIVE_RUNTIME (three guard modes) |
| §226 | REQ | ADM-001 (zero-to-first-frame shield) |
| §227–§229 | DOC | PRE_EXPOSURE_SLO (buffer, latency budgets, deadline) |
| §230–§232 | DOC | GUARDIAN_VISUAL_CONSTITUTION (status signal, do-not-watch ⦸, override) |
| §233–§234 | REQ+DOC | ADM-001 + capability matrix (controlled prefilter; native reality) |
| §235 | DOC | DEVICE_NATIVE_RUNTIME (EarlyExitGovernor) |
| §236–§237 | REQ | SCO-001 (dual-phase score, stability) |
| §238–§239 | DOC | Master Spec §8 (attention firewall, session prediction) |
| §240 | DOC | LEARNING_AND_DRIFT_PLAN (pre-flight failure memory) |
| §241 | REQ | ADM-001 (new P0 tests) |
| §242–§243 | INFO | Master Spec (flow/principle) |

## v1.5 Collective Intelligence Flywheel — §244–§279
| § | Disposition | Where |
|---|---|---|
| §244–§247 | DOC | LEARNING_AND_DRIFT_PLAN (Main Brain, contribution contract, 3-tier) |
| §248 | DOC | INTELLIGENCE_TRAINING (observation≠truth ladder) |
| §249–§254 | DOC | LEARNING_AND_DRIFT + INTELLIGENCE_TRAINING (self-validating, residual, federated, cache, distillation, teacher-student) |
| §255–§256 | DOC | MODEL_REGISTRY (marketplace, council policy) |
| §257 | DOC | DEVICE_NATIVE_RUNTIME (early exit) |
| §258–§260 | DOC | DESIGN_SYSTEM + DEVICE_RESOURCE_BUDGETS (zero-friction, governance, idle battery) |
| §261–§263 | DOC+REQ | DEVICE_RESOURCE_BUDGETS (ComputeBudget, hw routing, maintenance); OPS-002 |
| §264–§267 | DOC | LEARNING_AND_DRIFT_PLAN (freshness, revalidation, failure-driven) |
| §268–§272 | DOC | LEARNING_AND_DRIFT_PLAN (governor, poisoning, isolation, online calibration, drift sentinel) |
| §273–§275 | DOC | LEARNING_AND_DRIFT_PLAN (shadow, champion/challenger, scorecard) |
| §276–§277 | DOC | LEARNING_AND_DRIFT_PLAN (user-level, continuous synthesis) |
| §278–§279 | INFO | Master Spec (loop/principle) |

## v1.6 Universal Target / Sub-Second SLO / Commercial — §280–§318
| § | Disposition | Where |
|---|---|---|
| §280 | INFO | Master Spec §0 |
| §281–§285 | REQ+DOC | ADM-001 + PRE_EXPOSURE_SLO (sub-second, latency classes, budget, parallelization); D-0008 |
| §286–§288 | DOC | COST_MODEL + CDNA-001 (shared network, reuse key, popularity economy) |
| §289 | DOC | ENTITLEMENT_AND_HOUSEHOLD (account/policy sync) |
| §290–§300 | DOC | PLATFORM_CAPABILITY_MATRIX (device universe + TV + companion + presentation + TV badge) |
| §301–§307 | REQ+DOC | ENT-001 + ENTITLEMENT_AND_HOUSEHOLD (commercial, StoreKit/Play/other, SubscriptionEntitlement, trial UX, pricing) |
| §308–§310 | REQ+DOC | COST-001 + COST_MODEL (unit/ reuse economics, pricing gate) |
| §311–§312 | DOC | ENTITLEMENT_AND_HOUSEHOLD (trial risk, subscription UX) |
| §313–§316 | DOC | DEVICE_CERTIFICATION_MATRIX + DEVICE_TEST_MATRIX (promise, program, lab, waves) |
| §317 | REQ | release gates (P0 DAG gate set) |
| §318 | INFO | Master Spec §0 (product definition) |

## v1.7 Full-System Audit / Social Command OS — §319–§375
| § | Disposition | Where |
|---|---|---|
| §319 | INFO | PROJECT_REALITY_REPORT (audit lineage) |
| §320–§321 | DOC | Master Spec §0/§10 (product kernel, control plane) |
| §322–§339 | REQ+DOC | PUB-001 + API_CONTRACTS + EVENT_CONTRACTS (composer, CanonicalSocialPost, publish manifest, account firewall, variant compiler, media, policy preflight, orchestrator, upload, reconcile, scheduler, §334 evidence[RCOV], adapter lifecycle, rate-limit, inbox transport, analytics) |
| §340–§344 | REQ | PRI-001 (observation topology, surfaces, firewall, redaction, ephemerality) |
| §345 | DOC | PRE_EXPOSURE_SLO (sub-second truth split); D-0008 |
| §346–§347 | DOC | GUARDIAN_VISUAL_CONSTITUTION + CDNA-001 (orb protocol, verified cache state) |
| §348–§349 | REQ+DOC | DVT-001 + DATA_CLASSIFICATION (rights/provenance registry, deletion/takedown) |
| §350 | DOC | DATA_CLASSIFICATION (global learning firewall) |
| §351–§352 | DOC | MODEL_REGISTRY (orchestration, disagreement) |
| §353–§354 | INFO | Master Spec §13 (world-uniqueness, moat proofs) |
| §355–§357 | REQ | PROT-002 (default protection vs choice, exclusion absolute/constrained) |
| §358 | DOC | OBSERVABILITY_SPEC (reliability/observability) |
| §359 | REQ+DOC | SEC-001 + THREAT_MODEL (security expansion) |
| §360–§362 | REQ+DOC | REL-001 + ENTITLEMENT_AND_HOUSEHOLD (outage, sync conflicts, entitlement resilience) |
| §363 | DOC | COST_MODEL (social publishing cost) |
| §364–§366 | DOC | THREAT_MODEL + API_CONTRACTS (legal/policy registries, abuse audit) |
| §367 | DOC | DESIGN_SYSTEM + SCREEN_STATE_INVENTORY (complexity firewall) |
| §368 | DEFER | SCREEN_STATE_INVENTORY (one-tap publish) P1 |
| §369 | DOC | Master Spec §9/§10 (creator-guardian flywheel) |
| §370 | DOC | DECISION_LEDGER (architecture lock scope) |
| §371 | REQ | P0_EXECUTION_DAG gate set (P1–P15 build-stopping proofs) |
| §372 | DOC | DEVICE_CERTIFICATION_MATRIX (release waves) |
| §373 | DOC | Constitution Art III + EVALUATION (competitive claim constitution) |
| §374–§375 | INFO | Master Spec (audit verdict/formula) |

## v1.8 Temporal Guardian — §376–§412
| § | Disposition | Where |
|---|---|---|
| §376–§377 | REQ+DOC | TMP-001; CORE_DOMAIN_BOUNDARIES (TemporalContentGraph/Segment) |
| §378–§379 | REQ | ADM-001/SCO-001 (short-form next-content guard; true-score rule) |
| §380–§385 | REQ | TMP-001 (pipeline, hierarchical, risk map, skip policy, permission, pre-roll) |
| §386–§390 | REQ+ADR | TMP-002 + ADR-0006 (controlled player skip, IFrame seekTo, browser adapter, native limitation, DRM) |
| §391–§394 | REQ | TMP-001/TMP-002 (shared intelligence, versioning, alignment, ad resilience) |
| §395–§398 | DOC | CONTAINER_ARCHITECTURE + DEVICE_NATIVE_RUNTIME ("millions of agents", distributed, dedup, edge) |
| §399–§402 | DOC | PRE_EXPOSURE_SLO (short-form path, precompute SLO, analysis-ahead window, safety deadline) |
| §403–§406 | REQ | TMP-001 (audio/visual-only negatives, cross-modal disagreement, energy interpretation) |
| §407 | REQ | TMP-002 (skip≠delete) |
| §408 | REQ | CHD-001 (family/child temporal) |
| §409 | DEFER | Master Spec §10 (creator temporal) P2 |
| §410 | DOC | LEARNING_AND_DRIFT_PLAN (temporal failure memory) |
| §411–§412 | REQ+INFO | TMP-001 P0 proof; Master Spec (formula) |

## v1.9 Competitive Intel / Family Guardian — §413–§449
| § | Disposition | Where |
|---|---|---|
| §413–§415 | INFO | EVALUATION_MASTER_PLAN (competitive map/lessons — research, non-normative) |
| §416–§420 | REQ | FAM-001/CHD-001 (roles, child-mode, Apple/non-Apple authority, default protection) |
| §421–§424 | REQ+DOC | PROT-001 + Constitution Art VII-C (Positive Exposure, informational rule, safety & user-initiated exceptions) |
| §425–§426 | DOC | Constitution + Master Spec §4 (Spiritual Wellbeing Lens; energy scientific/symbolic split) |
| §427–§428 | DEFER | SCREEN_STATE_INVENTORY (positive replacement, child positive feed) P1 |
| §429–§431 | REQ | CHD-001 (approval matrix, request flow, guardian dashboard) |
| §432–§434 | REQ | CHD-001 (child privacy, anti-tamper, device universe) |
| §435–§437 | REQ | CHD-001 (TV family mode, movie/series guard, short-form pre-admission) |
| §438–§441 | REQ+DOC | PROT-001 (adult positive default, low-valence label, taxonomy, balance) |
| §442–§444 | DEFER | SCREEN_STATE_INVENTORY (child development/wellbeing/family loop) P1 |
| §445 | REQ | CHD-001 (family emergency override) |
| §446–§447 | INFO | EVALUATION (differentiation thesis, benchmark tests) |
| §448 | REQ | CHD-001 (red-team child/positive) |
| §449 | INFO | Master Spec §11 (architecture) |

## v2.0 Family Pairing / Star / Household — §450–§490
| § | Disposition | Where |
|---|---|---|
| §450–§453 | REQ | FAM-001 (pairing, security, FamilyRelationship) |
| §454–§457 | REQ | CHD-001 (Apple authority, child security wall, change authority, recovery) |
| §458–§463 | SUP | → Pure Bar default (D-0006); Star optional in GUARDIAN_VISUAL_CONSTITUTION (states/adapters/accessibility retained as mode) |
| §464–§465 | REQ | ENT-001 (universal entitlement, TrustedDevice) |
| §466–§467 | DOC | ENTITLEMENT_AND_HOUSEHOLD (plans) |
| §468–§477 | REQ | HSH-001 (household trust, anchor, anomaly, 100km-safe, travel/away, re-verify, concurrent, risk states, challenge) |
| §478–§484 | DOC | ENTITLEMENT_AND_HOUSEHOLD (device mgmt, sync, plan separation, trial→paid, abuse engine, privacy-preserving, edge cases) |
| §485 | REQ | CHD-001/FAM-001 (profile visibility) |
| §486 | DOC | ENTITLEMENT_AND_HOUSEHOLD (household vs guardian authority) |
| §487 | DOC | GUARDIAN_VISUAL_CONSTITUTION (star+subscription failure states) |
| §488–§490 | INFO | Master Spec §11/§12 (formulas/UX/principles) |

## v2.1 Build Execution Constitution — §491–§525
| § | Disposition | Where |
|---|---|---|
| §491–§493 | DOC | P0_EXECUTION_DAG + D-0011 (build constitution, P0 claim, platform order → iOS-first) |
| §494 | DOC | PROJECT_REALITY_REPORT §5 + D-0002 (repo audit; 000–059) |
| §495 | DOC | this matrix + §7 report (required artefacts — now all created) |
| §496 | DOC | CONTAINER_ARCHITECTURE (monorepo packages) |
| §497 | DOC | GUARDIAN_VISUAL_CONSTITUTION (LiveGuardianSurface) |
| §498 | REQ | IDR-001 (content identity service) |
| §499 | REQ+DOC | CDNA-001 + DEVICE_NATIVE_RUNTIME (cache L1/L2/L3) |
| §500 | REQ | ADM-001 (fast pre-flight) |
| §501 | REQ | SCO-001 (score contract release rule) |
| §502–§503 | REQ | TMP-001/TMP-002 (temporal engine, controlled player first) |
| §504–§506 | REQ | FAM-001/ENT-001/HSH-001 (pairing, entitlement, household P0) |
| §507 | REQ | PUB-001 (14-step publishing vertical) |
| §508 | REQ | AI-001 (model router P0) |
| §509 | REQ | OPS-001 (energy/battery harness) |
| §510–§511 | DOC | PRE_EXPOSURE_SLO + EVALUATION (benchmark gates, quality metrics) |
| §512–§514 | DOC | DATASET_GOVERNANCE + EVALUATION (golden/adversarial/human-review) |
| §515–§518 | REQ | PRI-001/SEC-001/OPS-003/COST-001 (privacy/security/observability/cost gates) |
| §519 | DOC | DEVICE_CERTIFICATION_MATRIX (release program) |
| §520 | DOC | FAILURE_TAXONOMY (stop conditions) |
| §521 | DOC | AGENT_REGISTRY (execution ownership A–O) |
| §522–§523 | DOC | P0_EXECUTION_DAG (30/90-day mission) |
| §524 | DOC | Constitution Art IX (architecture freeze) |
| §525 | INFO | Master Spec §17 (build mission) |

## v2.2 Universal Gap-Closure / Portability — §526–§578
| § | Disposition | Where |
|---|---|---|
| §526 | INFO | Master Spec §13 |
| §527–§529 | DOC | PLATFORM_CAPABILITY_MATRIX (taxonomy, C5–C0, handshake) |
| §530–§532 | DOC | CONTAINER_ARCHITECTURE (SocimePlatformAdapter, extension SDK + firewall) |
| §533–§543 | DOC | PLATFORM_CAPABILITY_MATRIX (per-OS/TV/console strategies) |
| §544–§545 | DOC | OEM_QUIRK_REGISTRY |
| §546–§547 | DOC | Constitution (reality-integrity + spiritual-lens firewalls) |
| §548–§549 | REQ | CHD-001 (anti-coercion, guardian assurance G0–G4) |
| §550 | REQ | IDR-001 (content identity gate I0–I4) |
| §551 | REQ | TMP-002 (temporal skip safety gate) |
| §552 | DOC | PRE_EXPOSURE_SLO (adaptive look-ahead) |
| §553–§555 | REQ+DOC | REL-001 + FAILURE_TAXONOMY + runbooks (offline, outage, disaster) |
| §556 | REQ | OPS-001/OPS-002 (battery/thermal closure) |
| §557–§558 | DOC | EVALUATION_MASTER_PLAN (multilingual + cultural safety) |
| §559 | REQ | ACC-001 (accessibility closure) |
| §560 | DOC | DESIGN_SYSTEM (UX complexity) |
| §561–§563 | DOC | THREAT_MODEL + MODEL_REGISTRY (poisoning, disagreement, supply chain) |
| §564–§565 | REQ | DVT-001/CHD-001 (data rights, child privacy closure) |
| §566–§567 | DOC | ENTITLEMENT_AND_HOUSEHOLD (household/subscription, billing portability) |
| §568–§570 | DOC | CONTAINER_ARCHITECTURE (SocimeExtensionManifest, permissions, sandbox) |
| §571–§572 | DOC | DEVICE_CERTIFICATION_MATRIX + DEVICE_TEST_MATRIX (certification program/coverage) |
| §573 | DOC | Constitution Art III (compatibility claim) |
| §574–§575 | REQ+DOC | gate set + FAILURE_TAXONOMY (gap-closure suite, blocker closure matrix) |
| §576 | DOC | DEVICE_CERTIFICATION_MATRIX (release waves W0–W3) |
| §577–§578 | INFO | Master Spec (formula/lock) |

## v2.3 Ambient Guardian Surface — §579–§595
| § | Disposition | Where |
|---|---|---|
| §579–§595 | SUP→DOC | Star doctrine → demoted by Pure Bar (D-0006); retained as optional STARLINE mode + per-platform adapters/animation/haptic/role-adaptive/long-form/background/brand in GUARDIAN_VISUAL_CONSTITUTION |

## v2.4 Pure Bar & Progressive Disclosure — §596–§612 (GOVERNS presentation)
| § | Disposition | Where |
|---|---|---|
| §596–§612 | REQ+DOC | UX-001/UX-002 + GUARDIAN_VISUAL_CONSTITUTION + DESIGN_SYSTEM (Pure Bar default, 5 modes, L0–L3 disclosure, color-never-only-signal, morphology, Dynamic Island, heatmap morph, motion, settings, hierarchy); D-0006 |

## v2.5 Pre-Exposure Intelligence Constitution — §613–§656 (Priority Zero / P0-A)
| § | Disposition | Where |
|---|---|---|
| §613–§616 | REQ | ADM-001 (constitution, core problem, truth classes P0–P7, Content-Ahead Orchestrator) |
| §617–§620 | REQ | ADM-001/CDNA-001 (candidate queue, preload, zero-wait cache, global precompute) |
| §621–§622 | REQ | CDNA-001 (ContentDNA non-personal; personal admission over DNA) |
| §623 | REQ | SCO-001 (two-speed intelligence); D-0008 |
| §624 | DOC | Master Spec §8 (layer stack L0–L24) |
| §625 | DOC | AGENT_REGISTRY (OCTOPUS pre-exposure council, 20 arms) |
| §626–§628 | DOC | DEVICE_NATIVE_RUNTIME + PRE_EXPOSURE_SLO (deadline-aware, early exit, guard modes) |
| §629–§630 | REQ | SCO-001 (real score 6 states; fast≠full verification); D-0008 |
| §631–§635 | REQ | TMP-001/TMP-002 (long-form precompute, analysis-ahead controller, deadlines, heatmap, auto-skip authority) |
| §636–§637 | REQ | ADM-001 (brand-new content, live content protocols) |
| §638–§640 | DOC | MODEL_REGISTRY + LEARNING_AND_DRIFT (routing, disagreement, distillation) |
| §641 | DOC | DATA_CLASSIFICATION (shared intelligence network) |
| §642–§643 | DOC | DEVICE_RESOURCE_BUDGETS + COST_MODEL (compute budget, popularity) |
| §644–§645 | REQ | PRI-001/DVT-001 (pre-analysis privacy firewall, rights-aware precompute) |
| §646–§648 | DOC | PRE_EXPOSURE_SLO (latency budget, coverage + core metrics) |
| §649 | DOC | EVALUATION_MASTER_PLAN (quality floor before release) |
| §650–§651 | REQ | ADM-001/TMP-001 (short-form + long-form P0 proofs) |
| §652–§653 | DOC | GUARDIAN_VISUAL_CONSTITUTION + FAILURE_TAXONOMY (user-perceived + failure experience) |
| §654–§656 | REQ+INFO | ADM-001 (Priority Zero lock); Master Spec §0 (formula/moat) |

---

**Result:** every §0–§656 and Appendices A–H are accounted for; superseded sections are explicitly flagged with their superseding decision; no section is silently dropped. New stable requirement IDs were added only where a binding behavior/gate/rule lacked one: **OPS-002** (P0-B device health), **OPS-003** (observability), **UX-002** (P0-Q), **AI-002** (model governance), **VAL-002** (dataset/calibration/drift governance). See REQUIREMENTS_REGISTRY.
