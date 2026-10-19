# ADR BACKLOG

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §50(Prompt 000 numbering), §1484 initial ADR candidates, Appendix D; Prompt 000 §U, §50. ADR states: `PROPOSED` · `ACCEPTED` · `SUPERSEDED` · `REJECTED`. Template: Bible Appendix D.

Many architectural decisions are **recorded as accepted** in `DECISION_LEDGER.md` (D-00xx) but still need formal ADRs with full options/evidence/migration before implementation locks them. Items needing **current official platform verification** are flagged.

| ADR | Title | State | Needs platform verification? | Ledger link |
|---|---|---|---|---|
| ADR-0001 | ContentDNA + Content Identity architecture (reuse keys, I0–I4) | PROPOSED | no | — |
| ADR-0002 | Relocate Xcode app to `apps/ios/`; adopt Swift 6 language mode | PROPOSED (file) | no | D-0003 |
| ADR-0003 | New Apple ID / Team ID / final bundle id (replace `com.aymedo.Gen8`) | PROPOSED (file) | **yes (Apple)** | D-0001 |
| ADR-0004 | Universal adapter architecture + capability tiers C5–C0 | PROPOSED | **yes (all platforms)** | D-0004 |
| ADR-0005 | Pre-exposure architecture (orchestrator, deadlines, two-speed) | PROPOSED | **yes (platform preload/player APIs)** | — |
| ADR-0006 | Temporal skip safety + controlled-player strategy | PROPOSED | **yes (YouTube IFrame, players)** | — |
| ADR-0007 | Canonical decision-precedence chain (§176 vs §224) | **ACCEPTED (file)** | no | D-0015 (PROMPT 000A §3) |
| ADR-0008 | Local-vs-cloud routing + model supply chain + shared-cache rights | PROPOSED | no | D-0008 |
| ADR-0009 | Family authority + anti-coercion + pairing | PROPOSED | **yes (Apple/Android family APIs)** | — |
| ADR-0010 | Entitlement abstraction + household trust (no GPS-ban) | PROPOSED | **yes (StoreKit/Play)** | D-0011 |
| ADR-0011 | First social publisher choice + capability manifest | PROPOSED | **yes (provider APIs §334)** | — |
| ADR-0012 | Pure Bar presentation (supersedes persistent Star) | ACCEPTED→file later | no | D-0006 |
| ADR-0013 | Score contract + deterministic fusion (no LLM final score) | ACCEPTED→file later | no | D-0005 |
| ADR-0014 | Controlled evolution (self-improving, not self-governing) | PROPOSED | no | — |
| ADR-0015 | Package manager + monorepo tooling for JS/TS packages & extension | PROPOSED | no | — |
| ADR-0016 | Backend/cloud provider + data residency region | PROPOSED | no | — |

**Rule (Prompt 000 §54, §U):** do not silently resolve uncertain external platform facts. Every "needs platform verification" ADR stays `PROPOSED` until current official docs are checked (via the `official-source-verification` skill) with a citation + `last_verified` date. Concrete files authored so far: ADR-0002, ADR-0003, ADR-0007. Others are authored when they move toward locking.
