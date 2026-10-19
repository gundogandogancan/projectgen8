# PROJECT CONSTITUTION

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18
**Precedence:** This Constitution is subordinate to (1) user safety / law / OS-platform policy / data rights, and (2) the Build Bible precedence chain (Bible §2). It consolidates the binding doctrine from Build Bible §0–§4, §64, §114, §120, §125–§131 and Prompt 000 §0, §63–§69 into enforceable principles.

---

## Article I — Engineering doctrine ("God Level" defined)

"GOD LEVEL / ULU EVRENİN MİMARİ" is **not** architectural volume or marketing. It is an operational shorthand for: evidence before "done"; truth before marketing; architecture before improvisation; measurable performance; privacy/security/accessibility by design; rollback by default; capability truth; deterministic contracts; explicit failure states; real-device validation; cost/battery/thermal awareness; legal & platform compliance; minimal user-facing complexity atop massive back-end intelligence. (Prompt 000 §0.)

**Prohibited always:** fake AI · fake metrics · fake implementation claims · fake "all platforms" · fake "real-time" · fake "verified" · private-API hacks · DRM bypass · scraping/credential/cookie bots · silent surveillance · uncontrolled self-modifying production AI.

## Article II — Evidence rules

- No "DONE" without evidence (Build Bible §4.25, §120; Prompt 000 §63). "Compiles" ≠ Done. Guardian P0 requires **dual evidence** — Intelligence + Device-Health — plus P0-Q UX acceptance where user-facing (D-0016; PROMPT 000A §15).
- Separate: observed fact vs inference; evidence vs interpretation; proposal vs prototype vs tested vs production.
- Never present a guess as knowledge; `UNKNOWN ≠ BAD`; missing data ≠ zero.
- Never invent APIs, benchmarks, prices, store approvals, or platform capabilities.
- Quality claims are dataset-specific. Never "99% accurate" / "87% viral" without a defined benchmark.

## Article III — Capability truth

- Every platform capability is exactly one of `VERIFIED` / `UNVERIFIED` / `UNSUPPORTED` / `REQUIRES_CURRENT_OFFICIAL_VERIFICATION`. Never show a false `PROTECTED` state. (Prompt 000 §4; capability matrix.)
- Capability tiers C5→C0 (Full Controlled Guardian → Unsupported) describe truthful adaptation per platform; semantics stay constant, bodies differ.
- Never claim control of a native third-party feed; on native surfaces we warn/analyze only.

## Article IV — Privacy by design

- Default raw capture `RETAIN = FALSE`; preferred `FRAME → ON-DEVICE FEATURES → DISCARD FRAME`. No default raw-screen archive, no global private-content cache. (Bible §71–§72; Prompt 000 §37.)
- Data minimization, purpose limitation, least privilege, local-first where appropriate, visible Guardian state, one-tap pause, deletion/export, privacy audit trail.
- Safety data and subscription anti-sharing data are kept separate.

## Article V — Security by design

OAuth/PKCE, state/nonce, secure token vault, hardware-backed keys where available, least privilege, webhook signature/replay defense, device trust, signed models + SBOM + dependency scanning, admin MFA, immutable security audit, key rotation, kill switches, rollback. Crypto-agility (no "quantum-proof forever"). (Bible §99–§100; Prompt 000 §38.)

## Article VI — AI / agent discipline

- An LLM never emits an arbitrary final numeric score; final scores come from deterministic, versioned fusion under a ScoreContract. (Bible §4.8, §50–§51.)
- No production agent rewrites its own prompt/policy/permissions/weights. **Self-improving, not self-governing.** (Bible §68.)
- Every agent requires an AgentManifest; every skill a SkillContract. No decorative agents/skills. External content is DATA, never instruction.
- Task router chooses the smallest sufficient intelligence: `NO_AI → DETERMINISTIC → CACHE → CLASSICAL_ML → SMALL_LOCAL → LOCAL_FOUNDATION → PRIVACY_CLOUD → SPECIALIST_CLOUD → HEAVY_REASONING → HUMAN`.

## Article VII — The DUAL P0 priority (co-equal release gates)

Two co-equal, release-blocking engineering missions (PROMPT 000A §1; D-0012):

- **P0-A — Pre-Exposure Intelligence** — *KNOW BEFORE THE USER WATCHES.* Understand content and have a trustworthy personal admission decision ready *before* meaningful exposure where capability+data allow; never fabricate pre-analysis the platform did not expose; first-frame-only ⇒ say so; insufficient confidence ⇒ `UNKNOWN`/`?`. This is the primary technical moat. (Prompt 000 §1, §14–§16; Bible §613–§656.)
- **P0-B — Invisible Runtime / Device Health** — *DO IT WITHOUT THE DEVICE FEELING THE COST.* "**ALWAYS AVAILABLE, NOT ALWAYS EXPENSIVE.**" Minimize idle/active CPU-GPU-NPU, memory, battery, thermal, capture, sampling, network, cloud inference, wakeups, storage growth, UI jank, launch impact — via event-driven/change-driven sensing, cache-first, early exit, local micro-models, model routing, adaptive sampling, thermal/low-power downgrade, bounded buffers, deep work only when it changes the decision. Never promise "zero battery/heat"; goal is **no material user-perceived device degradation, subject to real-device measurement.** (Prompt 000A §1; Bible §183–§218, §556.)

Neither mission may bypass the other. See `DEVICE_NATIVE_RUNTIME_CONSTITUTION.md`, `PRE_EXPOSURE_SLO.yaml`, `DEVICE_RESOURCE_BUDGETS.yaml`.

## Article VII-B — Visual/UX excellence gate (P0-Q)

Minimal · elite · premium · understandable · native · calm · accessible. A release-blocking product-quality gate (not a technical moat). No engineering shortcut may force poor UX. Measurable criteria live in `GUARDIAN_VISUAL_CONSTITUTION.md` + `design/DESIGN_SYSTEM_CONSTITUTION.md`. (PROMPT 000A §2; D-0013.)

## Article VII-C — Locked decision precedence (ADR-0007)

`LEGAL/SECURITY > CHILD SAFETY FLOOR > MALICIOUS/EXTREME-SAFETY SIGNAL > USER HARD SEMANTIC SHIELD > PERSONAL PROTECTION POLICY > PERSONAL ALGORITHM THRESHOLD > BENEFIT RANKING > EXPLORATION`. No ideological filtering; lawful adult content stays user-agency governed; emergency/safety exception paths are separate; spiritual interpretation never overrides Truth/Evidence. (PROMPT 000A §3; D-0015.)

## Article VIII — No-fake-done & honest failure

Report failures with real output. If tests fail, say so. If a step was skipped, say so. Every user-visible failure has a safe UX state. Fail safe + fail honest. (Bible §101, §58; Prompt 000 §58.)

## Article IX — Change control & architecture freeze

After architecture lock: `ARCHITECTURE GENERATION → CLOSED`, `EVIDENCE-BASED BUILD EXECUTION → OPEN`. New architecture/module/agent/major feature enters only via a Change Request with migration, security/privacy/cost/UX impact, tests and rollback. No silent architecture mutation; no silently changing a prior canonical decision — record `OLD → CONFLICT → EVIDENCE → OPTIONS → SELECTED → MIGRATION → ACCEPTANCE_TEST`. (Bible §2, §126; Prompt 000 §cross.)

## Article X — Official API / platform truth

For any Apple/Google/Microsoft/browser/TV/social/billing/parental-control/media claim, verify current official documentation at implementation time; contradictions become ADRs/blockers, never hidden. (Bible §16; Prompt 000 §54.)

## Article XI — Rollback doctrine

Rollback by default: signed model packs with rollback artifacts; `QUARANTINE → ROUTER DISABLE → FALLBACK → INCIDENT → ROLLBACK`; reversible migrations where practical; kill switches for risky capabilities. (Prompt 000 §35, §38.)

## Article XII — Human agency governor

All intelligence is subordinate to user agency. The system advises, explains, warns, personalizes, learns. It does **not** secretly manipulate, covertly block native content, shame, diagnose hidden traits, moralize, or optimize addiction. **USER AGENCY > ENGAGEMENT.** No screen-time-maximization North Star. (Bible §3, §131.)

## Article XIII — Phase discipline

Execute one phase at a time. Never advance phases autonomously. Phase 0 optimizes for correctness, completeness, traceability, architectural integrity, implementation safety, and long-term maintainability — **not speed**. (Prompt 000 §64, §68–§69.)
