# P0 EXECUTION DAG

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §118–§119, §492–§525; Prompt 000 §N, §59. This is a **dependency-aware DAG**, not a calendar or feature checklist. Parallelize only non-conflicting work; schema/API/security decisions precede distributed implementation.

> This DAG describes the *order of proof* for Prompt 001+. It is NOT executed in Phase 0 (no product code). **Platform order is now LOCKED (D-0011): iOS-first + GuardianLab.**

## PROMPT 000A — dual-mission critical path (governs)
Two co-equal P0 missions (D-0012): **P0-A Pre-Exposure Intelligence** + **P0-B Invisible Runtime/Device Health**. Visual work (P0-Q) may not bypass intelligence proof; intelligence work may not bypass device-health proof (dual-evidence DoD, D-0016).
```
ARCHITECTURE LOCK
 → iOS FOUNDATION (P0-A1: design system, app shell, account, Guardian Pure Bar, Personal Algorithm, local intelligence, subscription/family foundations)
 → GUARDIANLAB (P0-A2: internal controlled harness — vertical feed + long-form player, preloaded NEXT+1/+2/+3, deterministic deadlines, ground-truth media)
 → CONTENT IDENTITY (IDR-001)
 → CACHE / CONTENTDNA (CDNA-001)
 → FAST MULTIMODAL PREFLIGHT (COG-001, ADM-001)
 → PERSONAL POLICY FUSION (TWIN-001, PAI-001, PROT-001/002, SCO-001)
 → ADMISSION CONTROLLER (ADM-002, precedence ADR-0007)
 → PURE BAR / SCORE (UX-001, UX-002, ACC-001)
 → PRE-EXPOSURE BENCHMARK (PRE_EXPOSURE_SLO)        ◄ P0-A evidence
 → TEMPORALGRAPH (TMP-001) → ANALYSIS-AHEAD → WARN/ASK/SAFE SKIP (TMP-002)
 → DEVICE RESOURCE BENCHMARK (OPS-001, OPS-002; DEVICE_RESOURCE_BUDGETS)   ◄ P0-B evidence
 → TRAINING / CALIBRATION / EVAL GATES (VAL-001, VAL-002, AI-002)
 → FAMILY / CHILD (FAM-001, CHD-001)
 → ENTITLEMENT (ENT-001, HSH-001)
 → REAL SOCIAL PUBLISH VERTICAL (PUB-001)
```
**Parallel tracks:** design system (UX-002) · security/privacy (SEC-001/PRI-001) · data rights (DVT-001) · observability (OPS-003) · model governance (AI-002).
GuardianLab exists to prove the engine on the real device **without pretending third-party iOS surfaces provide capabilities they do not** (§234, §581).

## Legend
`REQ` = requirement id (see REQUIREMENTS_REGISTRY). Edges mean "must be sufficiently proven before."

## Layer 0 — Contracts & safety foundation (must precede all)
```
L0.1 Canonical contracts (data models, events, ScoreContract schema)   [SCO-001 schema, §57P000]
L0.2 Security baseline (OAuth/PKCE, token vault, device trust)         [SEC-001]
L0.3 Privacy baseline (retention=false, sensitive-surface guard,       [PRI-001]
     deletion/export)
L0.4 Capability registry + handshake (truthful tiers C5–C0)            [D-0004, §529]
L0.5 Model Router + rollback harness                                   [AI-001]
L0.6 Battery/thermal + cost measurement harness                        [OPS-001, COST-001]
```
L0.1–L0.6 have no inter-dependencies except L0.1 before everything using contracts.

## Layer 1 — Perception → identity → cache (the Guardian spine)
```
PER-001 ──► BND-001 ──► IDR-001 ──► CDNA-001
   (permitted source) (boundary)  (identity I0–I4) (non-personal DNA, rights DVT-001)
IDR-001 ──► DVT-001 (data rights before reuse)
```

## Layer 2 — Understanding & personalization (parallelizable after L1 start)
```
PER-001 ──► COG-001 (topic/message/contribution + confidence)
COG-001 ──► EVD-001 (evidence vs inference)
(independent) TWIN-001 ──► PAI-001 (growth twin → personal algorithm + threshold)
COG-001 ──► PROT-001 (protection status)   IDR-001,COG-001 ──► PROT-002 (semantic shield)
```

## Layer 3 — Scoring & admission
```
COG-001 + EVD-001 + TWIN-001 + PAI-001 ──► SCO-001 (deterministic PBS + confidence)
SCO-001 ──► SCO-002 (why-this-score)
SCO-001 + PROT-001 + CHD-001(policy) ──► ADM-002 (admission controller + precedence)
CDNA-001 + IDR-001 + SCO-001 + PROT-001 ──► ADM-001 (PRE-EXPOSURE decision)   ◄── Priority Zero
```

## Layer 4 — Temporal (long-form) — depends on identity + cognition
```
IDR-001 + COG-001 ──► TMP-001 (TemporalGraph + analysis-ahead)
TMP-001 + IDR-001 ──► TMP-002 (safe ASK/SKIP/RESUME + alignment)
```

## Layer 5 — Presentation (depends on admission + protection)
```
ADM-002 + PROT-001 ──► UX-001 (Pure Bar + progressive disclosure, capability-truthful)
UX-001 ──► ACC-001 (accessibility: color-independent, expand target)
```

## Layer 6 — Family / entitlement / household (parallel track after L0.2)
```
SEC-001 ──► FAM-001 (pairing) ──► CHD-001 (child-disable resistance + anti-coercion)
SEC-001 ──► ENT-001 (account entitlement + trial) ──► HSH-001 (household trust, no GPS-ban)
```

## Layer 7 — Social publishing vertical (parallel track after L0.2)
```
SEC-001 ──► PUB-001 (one provider OAuth→publish→reconcile; wrong-account & dup prevention)
```

## Layer 8 — Reliability / calibration (cross-cutting, after their inputs exist)
```
PAI-001 + PROT-002 ──► REL-001 (offline Guardian + isolated failure domains)
SCO-001 ──► VAL-001 (calibration dataset + feedback)
```

## First vertical slice (Bible §117) — the end-to-end proof
```
ONBOARD → GOALS(TWIN-001) → MY ALGORITHM + 7.5 THRESHOLD(PAI-001) →
CONNECT PERMITTED INPUT(PER-001) → OBSERVE → BOUNDARY(BND-001) → IDENTIFY/CACHE(IDR-001,CDNA-001) →
FAST COGNITION(COG-001) → CONTENT VECTOR → PERSONAL FIT → PBS + CONFIDENCE(SCO-001) →
WHY THIS SCORE(SCO-002) → USER FEEDBACK(VAL-001) → OUTCOME/EVAL RECORD
```
This must work end-to-end (reproducible score, raw sensitive input not persisted, latency/battery measured, honest failure states) before advanced expansion. (Bible §116, App G.)

## Release-blocking gate set (Bible §371 P1–P15, §520, §650/§651)
All of: ADM-001 (pre-exposure), PUB-001 (wrong-account=0, dup=0), SCO-001 (reproducible), PROT-002 (shield precision/recall), PRI-001 (retention/deletion), AI-001 (rollback), OPS-001 (battery/thermal), COST-001 (cost report), IDR-001 (identity/alternate-cut), TMP-002 (no wrong skip), FAM-001/CHD-001 (family + anti-coercion), ENT-001/HSH-001 (entitlement), REL-001 (failure degradation), UX-001 (no false PROTECTED). No item marked implemented without real evidence (§575).
