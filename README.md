# Gen8

**Codename:** Gen8 · **Lineage:** SOCIME × ALGORITHM · **Category:** Universal Human Impact Intelligence System (Personal Attention Guardian + Social Command OS)

> One brain, many native bodies. NASA behind, one signal in front.

Gen8 is a universal, cross-device system that helps a person **understand** the permitted digital content they see and hear, **evaluate** it against their own goals, **see** whether it actually develops them, **recognize** manipulation/risk signals, and **take control of their own algorithm** — without the product optimizing for screen time.

This repository is governed by an evidence-first engineering doctrine. See the canonical foundation in [`docs/canonical/`](docs/canonical/) and the working rules agents must follow in [`CLAUDE.md`](CLAUDE.md).

## Status

| Aspect | State |
|---|---|
| Phase | **Phase 0 — Project Genesis + Architecture Closure (PROMPT 000 + 000A, foundation only)** |
| Product code | **IMPLEMENTATION BASELINE: default SwiftUI template only** (`Gen8/` app target) |
| Architecture | Closed per PROMPT 000A: dual-P0 locked, ADR-0007 accepted, iOS-first + GuardianLab, full §0–656 coverage |
| Platform order | **iOS-first + GuardianLab** → browser → Android → publisher → desktop/TV (D-0011) |
| Build readiness | See the PROMPT 000A report (§14 STATUS) |

## Canonical sources of truth (precedence)

1. User safety, applicable law, OS/platform policy, data rights
2. `SOCIME_ALGORITHM_FINAL_GOD_LEVEL_CLAUDE_BUILD_BIBLE_v2.5.md` (external master doc)
3. [`docs/canonical/CANONICAL_MASTER_SPEC.md`](docs/canonical/CANONICAL_MASTER_SPEC.md)
4. Previously finalized SOCIME / SOCIME × ALGORITHM decisions
5. Prior approved prompt/spec artefacts
6. Research / proposal / hypothesis-level ideas

## Repository map (Phase 0)

```
docs/
  canonical/    reality report, master spec, constitution, decision ledger
  architecture/ system context, containers, domain boundaries, P0 DAG, failure taxonomy, agent/skill registries
  adr/          architecture decision records (backlog + proposed)
  requirements/ requirements registry (traceable IDs)
  traceability/ requirements ↔ ADR ↔ contract ↔ code ↔ test ↔ evidence matrix
  score-contracts/ score contract schema + PBS v0.1
  capability/   platform capability matrix, OEM quirk registry, device certification matrix
  privacy/      privacy model
  security/     threat model
  data-rights/  data classification & rights
  evals/        evaluation master plan
  cost/         cost model
  design/       Guardian visual constitution
  runbooks/     operational runbooks (placeholders in Phase 0)
  reference/    external reference-repo study (ECC, superpowers, agency-agents)
Gen8/           existing iOS/visionOS/macOS SwiftUI app target (to be relocated to apps/ios — see ADR-0002)
Gen8.xcodeproj  Xcode project (bundle id to change with new Apple ID — see ADR-0003)
```

The full target monorepo shape (`apps/`, `packages/`, `services/`, `evals/`, `infra/`) is **documented** in [`docs/architecture/CONTAINER_ARCHITECTURE.md`](docs/architecture/CONTAINER_ARCHITECTURE.md) but **not materialized** in Phase 0 (no empty directories for appearance — Build Bible §46 / §113).

## License / attribution

Reference patterns were studied from three MIT-licensed repositories (ECC, obra/superpowers, msitarzewski/agency-agents). See [`docs/reference/REFERENCE_REPO_STUDY.md`](docs/reference/REFERENCE_REPO_STUDY.md) for attribution and what was/was not adopted.
