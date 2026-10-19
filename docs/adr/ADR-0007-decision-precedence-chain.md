# ADR-0007 — Canonical decision-precedence chain

**Status:** ACCEPTED (locked by PROMPT 000A §3, 2026-10-18)
**Date:** 2026-10-18 · **Locked:** 2026-10-18 (architecture reviewer directive)

## Context
The Admission Controller (ADM-002) applies a precedence order over all arm outputs. The Bible states this precedence twice with different wording:
- **§176:** `LEGAL/SECURITY > CHILD_SAFETY_POLICY > USER_HARD_EXCLUSION > PERSONAL_PROTECTION > PERSONAL_BENEFIT_RANKING`.
- **§224:** a fuller chain that additionally inserts a **MALICIOUS / EXTREME HIGH-CONFIDENCE SAFETY SIGNAL** tier and an **EXPLORATION** tier.

## Problem
A single deterministic precedence must govern the controller; two variants cannot both be canonical. This is a release-blocking ambiguity for ADM-002 (deterministic reproducibility).

## Options
1. Adopt §176 (simpler).
2. Adopt §224 (superset; adds malicious-signal + exploration tiers).
3. Author a merged chain that is explicitly the superset and resolves tier ordering.

## Decision (LOCKED by reviewer, PROMPT 000A §3)
§176 remains authoritative for the **conceptual four-layer protection model** (1. Non-negotiable System Integrity · 2. Default Human Safety Baseline · 3. Personal Protection Constitution · 4. Semantic Shield). The **decision-precedence ordering of §224 supersedes** the shorter §176 ordering. Canonical precedence:
```
LEGAL / SECURITY
  > CHILD SAFETY FLOOR
    > MALICIOUS / EXTREME HIGH-CONFIDENCE SAFETY SIGNAL
      > USER HARD SEMANTIC SHIELD
        > PERSONAL PROTECTION POLICY
          > PERSONAL ALGORITHM THRESHOLD
            > BENEFIT RANKING
              > EXPLORATION
```
Constraints bound into this decision:
- Does **NOT** authorize ideological filtering.
- Ordinary lawful adult content remains **user-agency governed**.
- Emergency / safety-critical **exception paths remain separate** (§423 necessary-safety, §424 user-initiated access).
- **Spiritual interpretation cannot override Truth/Evidence** (§141, §426, §547).

## Why
§224 is the later, more complete canonical ordering; Bible precedence (§2) favors the later version. Child-safety floor sits directly under legal/security (above even malicious-signal handling) because verified guardian authority is a floor, not a preference. The malicious/extreme-safety tier sits above user preference but under legal/child-safety. User hard Semantic Shield outranks personal protection policy and benefit; exploration is lowest and never overrides protection.

## Impact
Admission determinism, UX copy, child safety, Semantic Shield absoluteness.

## Acceptance tests (once locked)
- Controller output is reproducible from logged inputs + precedence version.
- A malicious high-confidence signal overrides personal benefit but not a legal/security block.
- User hard exclusion is never silently overridden by benefit ranking.

## Open risks
- Interaction with "necessary safety information exception" (§423) and "user-initiated access exception" (§424) must be encoded as scoped exceptions, not precedence violations.
