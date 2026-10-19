# GEN8 — GITHUB EVIDENCE & EXECUTION WORKFLOW v1.0

GitHub is the external source of truth for code/evidence history.

## Branch model
- `main` = last independently audited locked state only
- implementation branch per phase/fix, e.g. `phase/p009c-r1`
- audit branch per independent audit, e.g. `audit/p009c-r1`
- never force-push audited history

## Atomic commit rule
Push after each coherent engineering fact, not after every tiny edit or shell command.

Examples:
- `P009C-R1 F1: constrain durable entity vocabulary`
- `P009C-R1 F2: language-aware lexicon matching`
- `P009C-R1: privacy and corpus integrity tests`

Each commit should include phase/finding ID and purpose.

## Push/gate rule
After each atomic change:
1. focused tests
2. commit
3. push
4. record commit SHA in evidence docs

Before audit:
1. full suite
2. clean working tree
3. push
4. create immutable tag such as `gen8-p009c-r1-audit-candidate`
5. record tag + SHA + test count

## Independent audit
Auditor receives exact tag/commit and audit prompt.
Builder narrative is not ground truth.
Audit-only tests/reports go on audit branch and are committed/pushed.

## Lock rule
Only after independent PASS:
- merge via PR
- tag exact locked commit, e.g. `gen8-p009c-locked`
- update Decision Ledger + Claim/Evidence Ledger

## Repository protection
Recommended:
- private repo
- protected main
- no force-push
- PR required
- CI checks where feasible
- secret scanning
- no API keys/tokens
- no raw private user media
- no DerivedData/build junk
- no unrelated regenerated benchmark churn

## Canonical flow
SPEC → IMPLEMENT → FOCUSED TEST → ATOMIC COMMIT → PUSH → FULL TEST
→ AUDIT-CANDIDATE TAG → INDEPENDENT AUDIT → FIX → RE-AUDIT
→ PR → MERGE → LOCK TAG → NEXT PHASE
