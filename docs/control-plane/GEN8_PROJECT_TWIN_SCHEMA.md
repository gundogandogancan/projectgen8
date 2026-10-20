# GEN8 PROJECT TWIN — SCHEMA & LAWS (v1)

The Project Twin is the deterministic, version-controlled, evidence-backed state machine of the GEN8
program. It is an **INDEX + STATE MACHINE**, never a copy of the underlying ledgers: every node points
to authoritative sources by stable ID/path. It answers: what does GEN8 claim, what does the code
actually do, what was tested, what was lab-only, what has physical-device evidence, what has real-world
human/calibration evidence, what failed historically, what is blocked, and what is the next legal DAG node.

## 1. File format law (deliberate deviation, documented)

`GEN8_PROJECT_TWIN.yaml`, `GEN8_ULU_EVREN_MASTER_EXECUTION_DAG.yaml` and
`GEN8_ENGINEERING_FAILURE_MEMORY.yaml` are written in the **strict-JSON subset of YAML 1.2**
(JSON is valid YAML). Reason (concrete, not stylistic): the control plane must be machine-validated
**inside the existing evidence suite on every `swift test` run** with zero new dependencies —
`JSONSerialization` is in the Swift stdlib, while the system Python has no guaranteed YAML parser and a
run-on-demand script is weaker than suite-integrated validation. Humans read the generated `.md` views
(`CURRENT_STATE.md`, `EPOCH_STATUS.md`, …), which are DERIVED and always lose to the canonical files.

## 2. Node schema

Every node in `GEN8_PROJECT_TWIN.yaml → nodes[]`:

```
id                — stable unique ID (EPx-…, Pxxx-…, RWC-PRE-xx, CP-…)
name              — human name
epoch             — EPOCH_I … EPOCH_VIII | META
program           — program grouping (e.g. RWC_PREREGISTRATION, CONTROL_PLANE)
workstream        — git branch / historical phase family
type              — PHASE_LOCKED | CAPABILITY | PROGRAM | GATE | CONTRACT | META

requirements[]    — REQ/D/ADR IDs (registry refs, not copies)
depends_on[]      — hard dependency node IDs (DAG edges)
blocks[]          — convenience inverse (validated for symmetry)
blocked_by[]      — blocker IDs (BLK-… / finding IDs) — required non-empty when status BLOCKED

implementation    — { status, refs[], commits[] }
tests             — { status, refs[], latest_count }
audit             — { status, refs[], latest_verdict }

truth             — SEVEN INDEPENDENT AXES (see §3): { overall, functional, calibration, real_device,
                     privacy, security, resource_performance, human_product }

capability        — { platform_scope, availability }
evidence          — { claim_refs[], implementation_refs[], test_refs[], device_refs[],
                     calibration_refs[], audit_refs[] }
limitations[]     — honest open limitations (verbatim finding IDs where applicable)
blockers[]        — blocker IDs this node carries
failure_memory_refs[] — FM-xxx IDs that bind this node

release           — { release_blocking: bool, gate, wave: W0|W1|W2|W3|null }
rollback          — { commit, tag }
next              — { allowed_when, prohibited_until }
status            — LOCKED | ACTIVE | READY | BLOCKED | PLANNED | RETIRED
```

## 3. Truth taxonomy & seven axes (binding)

Allowed truth values — EXACTLY: `VERIFIED`, `VERIFIED_WITH_LIMITATIONS`, `PLAUSIBLE_NOT_PROVEN`,
`LAB_ONLY`, `UNVERIFIED`, `UNAVAILABLE`, `CONTRADICTED`, `OPEN`, `BLOCKED`.
Forbidden: `DONE`, `COMPLETE`, `PRODUCTION_READY` (release state is a separate dimension; gate state is
separate from truth: `truth.calibration = LAB_ONLY` + `gate = UNMET` is a valid, honest pair).

Seven axes, never collapsed into one boolean: FUNCTIONAL, CALIBRATION/SCIENTIFIC, REAL-DEVICE, PRIVACY,
SECURITY, RESOURCE/PERFORMANCE, HUMAN/PRODUCT. One green axis can NEVER upgrade another.
`truth.overall` is a REPORTING convenience = the weakest release-relevant axis, never better.

## 4. Claim → evidence law

REQUIREMENT → ARCHITECTURE → IMPLEMENTATION → TEST → REAL-DEVICE → CALIBRATION → AUDIT → RELEASE CLAIM.
Not every claim requires every class ("compiles" needs no calibration; "real-world calibrated safety
score" needs ALL), but a missing REQUIRED class must be explicit in `evidence` (empty array = declared
absence, never implied presence).

## 5. State-transition law (change control)

- `UNVERIFIED → LAB_ONLY`: requires lab evidence ref.
- `LAB_ONLY → VERIFIED_WITH_LIMITATIONS`: requires independent audit ref + the appropriate real
  evidence class for the axis.
- `real_device` may NEVER be upgraded without a device evidence ref; simulator/build artifacts cannot
  upgrade it (FM-002/FM-004).
- `calibration` may NEVER be upgraded from synthetic fixtures alone (FM-012); requires rights-clear
  real data + independent annotation + sealed held-out + independent calibration audit.
- `CONTRADICTED` never silently becomes anything else: requires new evidence + an explicit resolution
  record + independent audit where release-relevant (FM-003/FM-014).
- `BLOCKED → READY`: requires blocker-closure evidence refs.
- Newer ≠ more authoritative: a later builder report cannot erase an older physical-device
  contradiction (see authority law, §6).

## 6. Authority / conflict resolution (domain-aware)

Baseline precedence (higher wins WITHIN its domain):
1. immutable independent audit evidence · 2. measured real-device evidence · 3. measured real-world
calibration/human evidence · 4. locked canonical contracts · 5. implementation + automated test
evidence · 6. lab benchmark · 7. architecture proposal · 8. builder claim · 9. prose assumption.
**Domain-awareness:** evidence only carries authority in its own axis — a device thermal measurement
cannot override a privacy contract; a privacy audit cannot upgrade functional truth. Cross-domain
conflicts are not auto-resolved: they produce a CONTRADICTED mark + a resolution-record obligation.

## 7. Governance limits (the twin is not self-governing)

The twin may RECOMMEND the next READY node. It may NOT: auto-merge, auto-deploy, weaken gates, rewrite
history, grant capabilities, convert UNKNOWN/UNVERIFIED to VERIFIED, or erase blockers. Every state
upgrade enters via a human-authorized, evidence-bearing commit, validated by the control-plane tests.

## 8. READY law & priority law (next-action engine)

A node is READY iff: ALL `depends_on` nodes are LOCKED/VERIFIED-enough for their declared gate, AND all
release-blocking predecessor findings are closed or explicitly accepted as limitations, AND every
required evidence class for entry exists, AND no higher-authority contradictory evidence exists.
When several nodes are READY, priority = safety/release-blocker → critical path → unlock value →
evidence value → cost/resource efficiency. NEVER "easiest pretty feature first".
