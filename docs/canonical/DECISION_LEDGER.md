# DECISION LEDGER

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18
Each entry: ID · title · status · rationale · affected domains · source · supersedes/superseded-by · implications. Conflict-resolution format (Bible §2): `OLD → CONFLICT → EVIDENCE → OPTIONS → SELECTED → MIGRATION → ACCEPTANCE`.
Statuses: `ACCEPTED` · `PROPOSED` · `OPEN` (needs ADR) · `RECORDED` (fact log).

---

### D-0001 — Codebase codename = `Gen8`
- **Status:** ACCEPTED
- **Rationale:** User instruction. Build Bible brand is "SOCIME × ALGORITHM"; Prompt 000 names lineage "SOCIME / AIVEL" and says don't rename the codebase unless instructed — user instructed `Gen8`.
- **Affected:** repo naming, bundle id, product/marketing.
- **Source:** user; Prompt 000 §2; Bible §2.
- **Implications:** Codename/identifiers = `Gen8`. Brand lineage (SOCIME/ALGORITHM/AIVEL) recorded as heritage, not used as identifiers. Final public brand is a later product decision; do not hard-code a public brand yet.

### D-0002 — Historical Modules 000–059: none exist; none invented
- **Status:** RECORDED
- **Rationale:** Bible §129/§494 instruct discovery+classification of a SOCIME 000–059 module registry and forbid creating "Module 060." Full read confirms the Bible **references** this registry but **never defines** individual modules, and none exist in the repo/working tree.
- **Affected:** lineage, traceability.
- **Source:** Bible §129, §494; reality inspection.
- **Implications:** No modules fabricated; no Module 060. If the user supplies the 000–059 registry later, ingest and classify (CANONICAL/SUPERSEDED/PROPOSAL/IMPLEMENTED/TESTED/UNKNOWN) then. Non-blocking (see Reality Report §9).

### D-0003 — Monorepo repository shape = Prompt 000 §46 (superset of Bible §113)
- **Status:** ACCEPTED
- **Rationale:** Bible §113 and Prompt 000 §46 both specify a monorepo; §46 is the newer, broader layout and is a compatible superset. No empty dirs created for appearance (§46).
- **Affected:** repo structure, build tooling.
- **Source:** Bible §113, §496; Prompt 000 §46.
- **Implications:** Only Phase-0-required dirs (`docs/…`) materialized now; `apps/packages/services/evals/infra` documented in `CONTAINER_ARCHITECTURE.md`, created when first needed.

### D-0004 — Capability truth via tiers C5–C0 + matrix; never a false PROTECTED
- **Status:** ACCEPTED
- **Rationale:** "All platforms" ambition (Bible §15/§527) must not produce false capability claims. Prompt 000 §4 + Bible §528 define tiers C5 (full controlled guardian) → C0 (unsupported); Bible §210 mandates False-Protected = 0.
- **Affected:** every platform adapter, presentation, marketing claims.
- **Source:** Prompt 000 §4; Bible §197, §208, §210, §528, §573.
- **Implications:** Each capability is `VERIFIED`/`UNVERIFIED`/`UNSUPPORTED`/`REQUIRES_CURRENT_OFFICIAL_VERIFICATION`; no UI shows PROTECTED without a verified controlled path. Governs `PLATFORM_CAPABILITY_MATRIX.yaml`.

### D-0005 — Final numeric scores are deterministic; LLMs never emit them directly
- **Status:** ACCEPTED
- **Rationale:** User wants "god-level" intelligence, but Bible §4.8/§51 forbid an LLM emitting an arbitrary final numeric score. Resolution: LLMs/models produce **evidence, components, labels, confidence**; a deterministic, versioned fusion under a ScoreContract produces the final PBS.
- **Affected:** score kernel, agents, reproducibility.
- **Source:** Bible §4.8, §49–§51, §501, §629.
- **Implications:** Same input + versions ⇒ same final score (reproducibility is a P0 demo criterion, Bible App G.15). "God level" = correctness/evidence, not LLM free-form scoring.

### D-0006 — Default Guardian surface = Pure Bar (v2.4 supersedes persistent Star)
- **Status:** ACCEPTED
- **CONFLICT:** v2.0/v2.3 (§458–462, §580–581) present an always-visible Star as canonical. **EVIDENCE:** v2.4 §596 explicitly "supersedes the assumption that the Star and numeric score must remain persistently visible." **OPTIONS:** persistent star / pure bar default / hidden. **SELECTED:** Pure Bar default + modes PURE_BAR/BAR_SCORE/STARLINE/HIDDEN_BACKGROUND/AUTO, progressive disclosure L0–L3; Star = brand symbol, non-mandatory HUD.
- **Affected:** all presentation/UX, Guardian Visual Constitution.
- **Source:** Bible §596–612 (governs) vs §458–462/§580–595 (superseded for default visibility).
- **MIGRATION/ACCEPTANCE:** `GUARDIAN_VISUAL_CONSTITUTION.md` encodes Pure Bar default; Star adapters retained as optional mode. Any artifact citing "always-visible star" is stale.

### D-0007 — OCTOPUS canonical arm count = 20
- **Status:** ACCEPTED
- **Rationale:** §63 (v1.0) lists 12 arms; §154 adds arms 13–17; §177/§625 enumerate 20; Prompt 000 §7 lists 20. Latest governs.
- **Affected:** cognition/council architecture, agent registry.
- **Source:** Bible §177, §625; Prompt 000 §7 (governs) vs §63 (superseded).
- **Implications:** Council/agent design targets 20 responsibility arms; "12-arm" references are v1.0 baseline only. No arm has unilateral production authority (Prompt 000 §7).

### D-0008 — "Sub-second" = admission-decision latency, not full fact-verification
- **Status:** ACCEPTED
- **CONFLICT:** §281 "<1.0s" vs §345/§630 "fast ≠ fully verified." **SELECTED:** the <1s SLO applies to the *first trustworthy admission decision* (fast path); deep truth/claim verification is asynchronous. UI must never render a fast "approved" state as "all factual claims verified" (§630, §10076).
- **Affected:** score plane, latency budgets, UI copy, observability.
- **Source:** Bible §281, §282, §345, §623, §629, §630.
- **Implications:** Fast vs deep score states are distinct and labeled; latency metrics measured separately (cache p95 ≤ 300ms target, preloaded p95 < 1000ms — *targets to benchmark*, not guarantees, Bible §123).

### D-0009 — Reference repos adopted as patterns only (MIT, attributed)
- **Status:** ACCEPTED
- **Rationale:** ECC / superpowers / agency-agents are MIT; we adopt structural patterns (skill/agent manifest formats, divisions governance, prompt-defense baseline, model routing), not code.
- **Affected:** AGENT_REGISTRY, SKILL_REGISTRY, agent discipline.
- **Source:** `docs/reference/REFERENCE_REPO_STUDY.md`; Bible §87, §90.
- **Implications:** Attribution retained; our manifests follow Bible App B/C schemas, enriched with the adopted patterns.

### D-0010 — visionOS/macOS already in target set; keep, don't expand platform scope in Phase 0
- **Status:** RECORDED
- **Rationale:** Existing pbxproj targets `iphoneos iphonesimulator macosx xros xrsimulator`. Bible targets many platforms, but Prompt 000 §66 forbids product work in Phase 0.
- **Affected:** build settings, capability matrix.
- **Source:** pbxproj; Bible §527.
- **Implications:** Platform build-out sequenced by P0 order (D-0011) in later phases; capability matrix records full target families as `UNVERIFIED`/`REQUIRES_CURRENT_OFFICIAL_VERIFICATION`.

### D-0011 — P0 platform order = iOS-FIRST + GuardianLab (LOCKED)
- **Status:** ACCEPTED (locked by PROMPT 000A §4)
- **CONFLICT:** Bible §493 proposes browser-first (controlled surface for pre-exposure); user + reviewer want iOS-first. **EVIDENCE:** iOS-first must NOT weaken the Pre-Exposure proof, so it is split into a product lane + an internal controlled harness. **SELECTED canonical order:**
  ```
  P0-A1  iOS Product Foundation
  P0-A2  iOS GuardianLab Intelligence Proof  (internal controlled harness, NOT final consumer feed)
  P0-B   Browser Extension / Controlled Web Proof
  P0-C   Android Guardian Cross-App Proof
  P0-D   One Real Social Publishing Adapter
  P0-E   Desktop / TV Expansion after core proof
  ```
- **GuardianLab** = internal, non-production iOS target providing a controlled short-form feed + long-form player with preloaded NEXT+1/+2/+3 candidates, deterministic deadlines, known ground-truth media — to prove the intelligence engine on the real device **without pretending third-party iOS surfaces offer capabilities they do not** (§234, §581).
- **Affected:** first vertical slice, P0 DAG, capability matrix.
- **Source:** PROMPT 000A §4; Bible §493, §234.
- **Implications:** Browser-controlled proof is a later/parallel adapter, not the first lane. Capability truth remains mandatory; no false feed-control claim on native iOS.

### D-0012 — Two co-equal P0 engineering missions (dual-P0 release gate)
- **Status:** ACCEPTED (PROMPT 000A §1)
- **Decision:** **P0-A Pre-Exposure Intelligence** and **P0-B Invisible Runtime / Device Health** are co-equal, both release-blocking. Doctrine: *KNOW BEFORE THE USER WATCHES* **and** *DO IT WITHOUT THE DEVICE FEELING THE COST* — "ALWAYS AVAILABLE, NOT ALWAYS EXPENSIVE."
- **Affected:** DAG, DoD, requirements (ADM/OPS), SLO + resource-budget contracts.
- **Source:** PROMPT 000A §1, §15; Bible §183–§218, §613–§656.
- **Implications:** Definition of Done requires **dual evidence** (intelligence + device-health) for every Guardian P0 requirement (D-0016). Neither mission may bypass the other.

### D-0013 — Visual/UX excellence is a release gate (P0-Q)
- **Status:** ACCEPTED (PROMPT 000A §2)
- **Decision:** **P0-Q** — minimal/elite/premium/understandable/native/calm/accessible — is a release-blocking product-quality gate (not a technical moat). Measurable criteria: frame stability, animation smoothness, state clarity, accessibility, reduced motion, Dynamic Type, safe areas, Dynamic Island behavior, loading/error/offline/degraded states, no score jitter, no stale Protected state.
- **Affected:** Guardian Visual Constitution, Design System Constitution, UX requirements.
- **Source:** PROMPT 000A §2.
- **Implications:** No engineering shortcut may force poor UX; UX-002 requirement added.

### D-0014 — Apple Team / bundle id reclassified as EXTERNAL_EXECUTION_DEPENDENCY
- **Status:** ACCEPTED (PROMPT 000A §5)
- **Decision:** A missing Apple Developer Team / final bundle id blocks real-device signing/certification + some entitlement work, but **does NOT block architecture lock, documentation, simulator architecture work, or Prompt 001 planning**. Reclassified from "P0 blocker" to `EXTERNAL_EXECUTION_DEPENDENCY`.
- **Affected:** Reality Report blockers, capability matrix (affected claims stay UNVERIFIED), ADR-0003.
- **Source:** PROMPT 000A §5.
- **Implications:** Architecture can be BUILD READY while this remains pending, provided affected capability claims remain UNVERIFIED/RCOV.

### D-0015 — Decision-precedence chain LOCKED (ADR-0007 ACCEPTED)
- **Status:** ACCEPTED (PROMPT 000A §3) — resolves C-9.
- **Decision:** §176 keeps the conceptual 4-layer protection model; **§224 ordering supersedes** for precedence. Canonical chain: `LEGAL/SECURITY > CHILD SAFETY FLOOR > MALICIOUS/EXTREME-SAFETY SIGNAL > USER HARD SEMANTIC SHIELD > PERSONAL PROTECTION POLICY > PERSONAL ALGORITHM THRESHOLD > BENEFIT RANKING > EXPLORATION`. No ideological filtering; lawful adult content stays user-agency governed; emergency exceptions separate; spiritual lens never overrides Truth/Evidence.
- **Affected:** Admission Controller (ADM-002), Protection plane, UX copy, Semantic Shield absoluteness.
- **Source:** PROMPT 000A §3; ADR-0007.

### D-0016 — Dual-evidence Definition of Done for Guardian P0
- **Status:** ACCEPTED (PROMPT 000A §15)
- **Decision:** A Guardian P0 requirement is DONE only with BOTH **Intelligence Evidence** (correctness, confidence, latency, pre-exposure coverage, false allow/hide, identity, temporal) AND **Device-Health Evidence** (CPU/GPU/NPU, memory, battery, thermal, wakeups, network, UI smoothness, background stability).
- **Affected:** CLAUDE.md DoD, Constitution Art. II, traceability evidence columns.
- **Source:** PROMPT 000A §15.

---

## D-0017 — P009A: Hierarchical content identity canon (ACCEPTED, 2026-10-19)
Permanent hierarchy: `OBSERVATION → FRAME → SHOT → SCENE → CONTENT ITEM → TOPIC/NARRATIVE → CONTENT DNA →
PERSONAL POLICY → GUARDIAN ADMISSION`. A cut may create a new SHOT without a new ITEM; a swipe may create a new
ITEM even if visually similar — the levels are never collapsed. The frozen V5 sensor (`boundary-policy-v5`) is
reclassified as SHOT detection (contract `ShotSegmenterV5`); feed-item grouping lives in the intelligence layer
(`item-grouping-policy-v1`). Safety-first merge canon: uncertain SAME_ITEM never inherits a safe Guardian admission
(false split = compute waste; false merge = safety error). Thin-app canon: app size must not scale linearly with
intelligence capability; intelligence ships as signed/versioned/checksum-verified/rollbackable ASSET packs (never
executable code). Flywheel canon: local learning by default; global learning privacy-gated; no raw private media
centralization; no uncontrolled self-modifying production model.

---
## D-0018 — P009A-R1: Profile-aware identity evidence canon (ACCEPTED, 2026-10-19)
Every runnable capability profile MUST pass its own predeclared lab gate (TUNE/HELD-OUT/STRESS/DEVICE-LIKE) before a
policy freeze — "Tier-1 passed therefore Tier-0 is good enough" is forbidden. A single global decision threshold
across materially different evidence profiles is forbidden; same-evidence scores are normalized by the profile's
declared evidence ceiling. Missing evidence is never negative evidence. Style/cadence continuity can never be the
sole merge basis (content or cross-modal anchor required); the strong-new veto is absolute; deferred coalescing is
content-anchored and never forced to hit count targets.

---
## D-0019 — GOD-LEVEL MASTER EXECUTION PACKAGE v1.0 adopted (ACCEPTED, 2026-10-19)
`docs/canonical/GEN8_MASTER_CONSTITUTION_REAL_SCORE_OCTOPUS_INTELLIGENCE.md` (SHA a8ce721b…) is the BINDING
architecture/execution constitution for all subsequent P009/P008B/score/calibration work. Execution DAG (§35):
A independent red-team audit → B measured Tier-0 evidence (02) → C identity closeout by measured outcome A/B/C →
D expert mesh → E world model → F safety/child/shield → G calibration/real score → H glyph/motion → I network
learning → J cross-platform. Gates are never skipped; every milestone ends BUILD → SELF TEST → REAL DEVICE →
INDEPENDENT AUDIT → FIX → RE-AUDIT → LOCK. Core doctrine: Gen8 is not a morality meter; the score is calibrated
policy-conditioned Personal Suitability/Admission; score ≠ confidence ≠ coverage; UNKNOWN over false certainty;
real device outranks synthetic lab; measure before tuning; audit before lock. Audit/measure prompts preserved at
`docs/audit/prompts/` (SHA manifest included).

---
## Open items requiring ADRs
- ~~**ADR-0007**~~ — **RESOLVED/ACCEPTED** (D-0015).
- **ADR-0002** — relocate existing Xcode app to `apps/ios/`; Swift 6 language-mode adoption (Prompt 001).
- **ADR-0003** — new Apple ID / Team ID / final bundle id (EXTERNAL_EXECUTION_DEPENDENCY, D-0014).
- **ADR-0004/0005/0006/0009/0010/0011** — platform-verification-gated (stay PROPOSED until current official docs checked).
- See `docs/adr/ADR_BACKLOG.md` for the full list.
