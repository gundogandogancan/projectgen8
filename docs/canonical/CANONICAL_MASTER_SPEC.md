# CANONICAL MASTER SPECIFICATION v1.0

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18
**Purpose:** Consolidate the entire product into one coherent hierarchy. Per Prompt 000 §D, this **references Build Bible section IDs** (`§n`) rather than rewriting rules, so the Bible remains the single source of truth and drift is avoided. "Bible" = `SOCIME_ALGORITHM_FINAL_GOD_LEVEL_CLAUDE_BUILD_BIBLE_v2.5.md`.

Reading rule: where a later version (v1.1→v2.5) revises an earlier one, **the later governs** (Bible §2; see `DECISION_LEDGER.md`).

---

## 0. Product kernel

> **Gen8 = Social Command OS + Personal Attention & Human-Impact Guardian OS**, one account, many native bodies, delivered as a **paid cross-device subscription with a 7-day trial**. (Bible §320, §301, §9238.)

Core loop (Bible §132, §179):
`PERCEIVE → UNDERSTAND → VERIFY → INTERPRET → PERSONALIZE → SCORE → EXPLAIN → LEARN → APPLY → OBSERVE OUTCOME → CALIBRATE → CONTROLLED EVOLUTION`

**Two co-equal P0 missions** (release-blocking, D-0012; PROMPT 000A §1):
- **P0-A — Pre-Exposure Personal Content Intelligence** (*Priority Zero*): understand content and have a trustworthy admission decision ready before meaningful exposure where capability+data allow. (Bible §613–656; Prompt 000 §1.) Contracts: `PRE_EXPOSURE_SLO.yaml`.
- **P0-B — Invisible Runtime / Device Health**: *ALWAYS AVAILABLE, NOT ALWAYS EXPENSIVE.* (Bible §183–218.) Contracts: `DEVICE_NATIVE_RUNTIME_CONSTITUTION.md`, `DEVICE_RESOURCE_BUDGETS.yaml`.

Plus **P0-Q — Visual/UX excellence** gate (D-0013; `DESIGN_SYSTEM_CONSTITUTION.md`). **Platform order LOCKED iOS-first + GuardianLab** (D-0011). Decision precedence LOCKED (ADR-0007/D-0015).

Three surfaces (Bible §6): **Individual/ALGORITHM**, **Family**, **Creator/SOCIME**.

Experience doctrine (Bible §596–612; Prompt 000 §3): **NASA behind, one signal in front.** Default visible state = **PURE ADAPTIVE COLOR BAR**; the Star is brand, not a mandatory HUD.

---

## 1. Governance & doctrine (non-negotiable)

| Topic | Bible refs |
|---|---|
| Claude role constitution; cannot self-certify | §1 |
| Source-of-truth precedence; conflict-record format | §2 |
| Highest philosophy — USER AGENCY > ENGAGEMENT | §3, §131 |
| 25 immutable production rules | §4 |
| Epistemic states (KNOWN…UNKNOWN); truth states | §65; Prompt 000 §0 |
| Evidence before done; DoD; "compiles ≠ done" | §120, §63(P000) |
| Change control / architecture freeze | §126, §524 |
| Human Agency Governor | §131 |
| Reality-integrity & spiritual-lens firewalls | §546, §547 |
| Anti-coercion guardian; guardian assurance G0–G4 | §548, §549 |
| Generic engineering master protocol (inherited) | Appendix H (§3465–4689) |

Full enforcement text: `PROJECT_CONSTITUTION.md`.

---

## 2. Perception & identity plane

| Subsystem | Bible refs |
|---|---|
| Universal Perception Bus + sensor adapters | §15, §496, §530 |
| Universal Digital Observation model (`DigitalObservation`, provenance types) | §17 |
| Adaptive Sensing Engine (change→boundary→keyframe→identity→fast→deep) | §18, §84 |
| Content Boundary Detector (`ObservedContentSession`) | §19 |
| Content Identity Resolver; identity states; **I0–I4 safety gate** | §20, §498, §550 |
| Screen observation topology; all-supported-surfaces mode | §340, §341 |
| Private & sensitive surface firewall; pre-inference redaction; raw-frame ephemerality | §72, §342, §343, §344 |
| Current platform reality baseline (needs reverification) | §16, §334 |

Identity integrity: wrong shared-identity reuse = release-blocking defect (Prompt 000 §11; Bible §550). "Same content ≠ same watch event" (§20).

---

## 3. Cognition plane

Content understood before scored (Bible §21). Components: Topic Intelligence §22; Message §23; Intent §24; Claim Engine §25; Knowledge Extraction §26; Contribution Ontology §27; Multimodal Perception §28; Measurable Energy/Frequency §29; Emotional Dynamics §30; Narrative §31; Persuasion/Influence §32; Subliminal/Hidden Pattern §33; Contradiction §34; Symbolic & Semiotic (epistemic-labeled) §35; Cross-Cultural Semantics §36, §557, §558. Canonical output: `ContentCognition` (§21).

## 4. Truth / evidence plane

Truth & Evidence Core (`EvidenceNode`) §37; Source Lineage Graph §38 (no syndicated copies as independent evidence); High-Risk Domain Policy §39 (health/finance/law/safety/science/breaking-news → stricter thresholds). Truth/Policy Firewall keeps separate: Truth/Evidence · Personal Benefit · Positive-Exposure Policy · Spiritual Wellbeing Lens · Age/Family Policy (Prompt 000 §8; Bible §141, §426, §547).

## 5. Protection plane (Whole-Person Protection — v1.1/v1.2)

| Subsystem | Bible refs |
|---|---|
| Whole-Person Protection Constitution (5 epistemic classes) | §136 |
| Harmful Exposure Ontology | §137 |
| `WholePersonImpactVector`, `PersonalProtectionProfile` (schemas) | §138, §139 |
| Values/Belief/Spiritual Profile; Spiritual Safety Firewall | §140, §141 |
| Subconscious/Priming Safety; Sensitive Visual Classifier; Distress Context; Negative-Flow/Doom | §142, §143, §144, §145 |
| Exposure Budgets; Protection Decision Engine | §146, §147 |
| **Personal Protection Status: GREEN / AMBER / RED / GREY** (separate from PBS) | §148 |
| Positive Exposure categories (user-selectable low-valence) | §9, §421, §439, §440 |
| Semantic Shield: System Baseline + User Semantic Shield; `SemanticShieldRule`; entity resolution; multimodal match; false-positive constitution; personal exclusion memory | §161–§166, §356 |
| Core Protection Engine (4 layers + precedence) | §176 |
| Decision precedence `LEGAL/SECURITY > CHILD_SAFETY > USER_HARD_EXCLUSION > PERSONAL_PROTECTION > PERSONAL_BENEFIT` | §176 / §224 (ADR-0007) |

## 6. Personalization plane

Personal Growth Twin (components + user rights VIEW/CORRECT/EXPORT/RESET/DELETE) §40; Behavior ≠ Intent signal hierarchy §41; Skill Graph §42; Development Delta §43; Personal Curriculum §44; Knowledge Decay §45; Personal Algorithm Engine (modes + `PersonalAlgorithmProfile`) §46; User Threshold §47; Exploration/Serendipity §48. Spiritual Wellbeing Lens affects personal recommendation only, never factual score §425–§426.

## 7. Score plane

Score architecture (intrinsic/personal/human-value/risk/trust components) §49; **ScoreContract** (no contract → no production numeric score) §50, §501; Personal Benefit Score (PBS 0–10) §51; Confidence separate from score §52; Pre-view Expected Benefit vs Post-view Verified Impact §53; dual-phase / two-speed score §236, §623, §630; **Real Score states** VERIFIED_FAST / PROVISIONAL_FAST / DEEP_VERIFIED / INSUFFICIENT_EVIDENCE / STALE / CONFLICTING §629 (insufficient ⇒ `?`). Score cannot be bought §4.21. See `score-contracts/`.

## 8. Admission & temporal plane (Anticipatory + Temporal Guardian — v1.4/v1.8/v2.5)

| Subsystem | Bible refs |
|---|---|
| Content-Ahead Orchestrator; Pre-Exposure truth classes **P0–P7** | §616, §615 |
| Next-candidate queue (short form) only when platform preloads | §15(P000), §617, §378 |
| `ContentAdmissionController` central approval gate + precedence | §223, §224 |
| Three guard modes (Strict / Normal / Guidance) | §225, §628 |
| Zero-to-first-frame shield; do-not-watch signal (⦸) | §226, §231 |
| Early-Exit / deadline-aware inference governor | §235, §626, §627 |
| `TemporalContentGraph` / `TemporalSegment`; hierarchical analysis | §377, §380, §381 |
| Analysis-ahead-of-playback controller; temporal deadlines; look-ahead | §401, §632, §552 |
| Temporal alignment engine; ad/insertion resilience; versioning | §393, §394, §392 |
| Controlled-player skip engine (YouTube IFrame `seekTo`); native limitation; DRM constitution | §386, §387, §389, §390 |
| Temporal skip safety gate; "skip ≠ delete"; auto-skip authority | §551, §407, §635 |
| Intelligence layer stack **L0–L24** | §624; Prompt 000 §6 |
| OCTOPUS pre-exposure council (20 arms) | §625, §177; Prompt 000 §7 |

## 9. Learning / outcome / evolution plane

Learning Verification states §54; Knowledge-to-Action §55; Outcome Brain (no auto-causality) §56; Metacognition §57; Opportunity Cost §58; Semantic Repetition §59; User Feedback Loop §82; Failure Memory (`FailureCase` + regression) §66, §240, §410; Adversarial Immune System §67; Controlled Evolution (OBSERVE→…→ROLLBACK) §68; Score Calibration Lab §69; three learning loops + **self-renewing, not self-governing** §178, §179; Collective Intelligence Flywheel / Main Brain, 3-tier learning, federated learning, teacher-student, champion/challenger, drift sentinel, shadow §244–§279; global learning firewall & data-poisoning defense §269, §350.

## 10. Social Command OS plane (SOCIME — v1.7)

Navigation HOME|INBOX|CREATE|CALENDAR|INSIGHTS §7; internal centers (20) §7; Unified Inbox Constitution §8, §337, §338; Publishing Constitution + state machine §9, §330–§333; Universal Composer + `CanonicalSocialPost` §322, §323; Platform Publish Capability Manifest §324, §334 (dated API evidence — reverify); Account Authority & Token Vault + **Account Identity Firewall** (wrong-account = catastrophic) §325, §326; Platform Variant Compiler §327; Media Compatibility §328; Policy Pre-Flight §329; Delivery Orchestrator / Upload / Reconciliation §330–§332; Rate-Limit & API Economics Governor §336; Network Relationship Center §11; Platform Algorithm Intelligence §12; Viral Content Observatory §13; Creation/Quick Editor §10, §27(P000); Creator Intelligence Bridge + Inspiration Firewall §78, §79, §369. Rules: no scraping/private APIs/cookie bots; duplicate-publish & wrong-account are blockers.

## 11. Family plane (v1.9/v2.0)

Family Guardian OS roles OWNER/GUARDIAN/ADULT/TEEN/CHILD §73, §416; Visibility levels & "share result not raw history" §74; Consent Ledger §75; Teen Autonomy / Anti-Abuse §76; Goals & Rewards (never reward scrolling) §77; Child Mode activation + Apple/Non-Apple guardian authority §417–§419, §454; Child default protection, privacy, anti-tamper §420, §432, §433; Parental Approval Matrix & request flow §429, §430; Two-device pairing + security + `FamilyRelationship` §451–§453; Child security wall / change authority / recovery §455–§457; Family emergency override §445; TV Family Mode §435; temporal child guard §436, §437, §408. Anti-coercion (§548) applies throughout; billing ownership ≠ guardian authority (Prompt 000 §19).

## 12. Entitlement / device-trust / commercial plane (v1.6/v2.0)

Commercial constitution + 7-day trial §301, §305, §306; StoreKit / Play / other-store `BillingAdapter` §302–§304, §567; `SubscriptionEntitlement` (account-level) §305, §464; Device Trust Registry (`TrustedDevice`) §465; Personal/Family plans §466, §467; **Household Trust Model** — 100 km is a risk bucket, never an auto-ban §468–§471; Travel/Away modes §472, §473; concurrent-use & sharing-risk states §475, §476; entitlement challenge flow §477; cross-device policy sync §479; subscription abuse engine §482; privacy-preserving household enforcement §483; unit economics + content-reuse economics + pricing gate (price only after measured economics) §308–§310.

## 13. Universal device & presentation plane (v1.3/v2.2/v2.3/v2.4)

Universal device taxonomy §527; **Capability levels C5–C0** §528; Runtime Capability Handshake §529; `SocimePlatformAdapter` SDK §530; Universal Extension SDK + safety firewall + sandbox §531, §532, §568–§570; per-OS strategies (Apple §198/§534, Android §199/§535, Windows §200/§536, macOS §201/§537, Linux §202/§538, ChromeOS §533, Fire OS vs Vega OS §539, Tizen §540, webOS §541, Roku §542, consoles §543); OEM/Brand abstraction + **OEM Quirk Registry** §544, §545; Four-tier on-device intelligence stack + Model Router §187, §188; resource/battery/thermal/memory/network governors §189–§193, §556; Device Health. **Presentation:** Pure Bar default + 5 display modes (PURE_BAR/BAR_SCORE/STARLINE/HIDDEN_BACKGROUND/AUTO) + progressive disclosure L0–L3 §596–§612; adaptive color-bar language; color never the only signal §602, §603; Dynamic Island / Live Activities preference §581, §605; bar→heatmap morph for long-form §606; the Star symbol + states + per-platform adapters + accessibility §458–§463, §580–§595. See `design/GUARDIAN_VISUAL_CONSTITUTION.md`.

## 14. Intelligence operations plane (Agent OS, models, cost)

Agent Operating System + AgentManifest §87, Appendix B; Agent Score Dimensions §88; Specialist Agents (use smallest sufficient) §89; Skill Engineering + SkillContract §90, Appendix C; no private chain-of-thought storage §91; Multi-Model Council + disagreement policy §64, §256, §351, §352; Model Router (hardware/privacy/cost aware) §33(P000), §188, §638; Model supply chain / packaging / update / rollback §35(P000), §212, §213, §563; Cost & Energy Governor + routing order §86, §261, §642; Cost model §61(P000), §363, §518. See `architecture/AGENT_REGISTRY.yaml`, `SKILL_REGISTRY.yaml`, `cost/COST_MODEL.md`.

## 15. Cross-cutting governance planes

Privacy Core §71, §37(P000) → `privacy/PRIVACY_MODEL.md`. Security Threat Model §99, §38(P000), §359 → `security/THREAT_MODEL.md`. Data Rights / classification §44(P000), §348, §564 → `data-rights/DATA_CLASSIFICATION_AND_RIGHTS.md`. Reliability (fail-safe + fail-honest) §101, §360. Observability §102, §39(P000), §358. Accessibility §103, §42(P000), §559, §463. Offline/Outage §43(P000), §553, §554. Evaluation §40(P000), §111, §512–§514 → `evals/EVALUATION_MASTER_PLAN.md`. Failure taxonomy §58(P000) → `architecture/FAILURE_TAXONOMY.md`.

## 16. Data, events, API contracts

Core data models §92 (Identity/Personal/Perception/Cognition/Truth/Score/Learning/Privacy/Family/Creator) + v1.1+ schemas (`WholePersonImpactVector` §138, `PersonalProtectionProfile` §139, `SemanticShieldRule` §162, `TemporalContentGraph`/`TemporalSegment` §377, `SubscriptionEntitlement` §305, `TrustedDevice` §465, `FamilyRelationship` §453, `CanonicalSocialPost` §323). Canonical events §93 + §57(P000). API contract principles §98. Data-model principle: domain ownership first, no giant schema up front §56(P000), §97.

## 17. Build program & proofs

Build phases 0→12 §118; Claude execution DAG rules §119, §28(P000) → `architecture/P0_EXECUTION_DAG.md`; P0 minimum proof §116, §59(P000); first vertical slice §117; **P0 platform order** P0-A browser → P0-B Android → P0-C iOS → P0-D one publisher §493; monorepo layout §496, §46(P000) → `architecture/CONTAINER_ARCHITECTURE.md`; benchmark/quality/privacy/security/observability/cost gates §510–§518; **build-stopping proofs P1–P15** §371; **stop conditions** §520; release waves §372, §576; 30-/90-day missions §522, §523; architecture freeze §524. North-star metrics §60(P000), §648.

---

## Appendix — full section index

The complete line-numbered section index of the Bible (§0–656 across v1.0–v2.5 + Appendices A–H) is retained in `docs/reference/BIBLE_SECTION_INDEX.md` as the navigation map used to build this spec.
