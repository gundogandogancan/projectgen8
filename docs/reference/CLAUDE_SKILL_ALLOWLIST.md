# CLAUDE SKILL ALLOWLIST (Supply-Chain Freeze)

**Doc status:** `CANONICAL` · **Phase:** 2 · **Date:** 2026-10-18 · PROMPT 002A §5.
**# NO NEW SKILL INSTALLATIONS DURING PROMPT 002.** 82 installed skills are NOT a quality metric. Default posture below is **`DISABLED / NOT ALLOWLISTED`**. Only the minimum set actually used in Prompt 002 is allowlisted.

## Global freeze rules (enforced)
- Installed to **user-global `~/.claude/skills/`** (not the Gen8 repo). Manifest: `~/.claude/skills/_GEN8_INSTALL_MANIFEST.json`.
- **All execution hooks stripped on install** — no hidden background execution, no auto-run scripts.
- No repo mutation by any third-party skill without a visible diff.
- No secrets access; no network side effects unless explicitly requested in a task.
- trailofbits skills are **CC-BY-SA** → personal use only, never vendored into the repo.
- Environment is **frozen + documented**, not auto-deleted.

## Allowlist (minimum set actually relevant to Prompt 002)
| Skill | Source | License | Purpose in P002 | Code exec | Network | Hooks | Status |
|---|---|---|---|---|---|---|---|
| ui-ux-pro-max | uxpm | MIT | P0-Q design rules (contrast/touch/safe-area/reduced-motion) applied to Pure Bar/DesignSystem | search script (manual) | no | stripped | **ALLOWLISTED (advisory)** |
| design-review, design-qa, a11y-audit, ux-writing, design-tokens | uxui | MIT | design/accessibility review of GuardianLab UI | no | no | stripped | **ALLOWLISTED (advisory)** |
| test-driven-development, verification-before-completion, writing-plans | sp | MIT | engineering discipline for the build | no | no | n/a | **ALLOWLISTED (advisory)** |
| semgrep, codeql, supply-chain-risk-auditor, secure-workflow-guide | tob | CC-BY-SA | security/supply-chain review (SEC-001/AI-002) | tool-invoked (manual) | no | stripped | **ALLOWLISTED (advisory, personal)** |
| harness-engineering, evaluation, memory-systems | ctx | MIT | eval harness + context patterns | no | no | n/a | **ALLOWLISTED (advisory)** |

**All other installed skills:** `DISABLED / NOT ALLOWLISTED` for Prompt 002 (available but not used; no auto-exec). They remain installed for future phases per the user's request; re-allowlist explicitly when a phase needs them.

## Explicitly NOT installed (user decision, 2026-10-18)
- **affaan-m/ECC** — contains **1062 SKILL.md** files; installing would catastrophically bloat every session's context and most are irrelevant to an iOS app. Kept as a **pattern reference only** (manifest/model-routing/prompt-defense patterns already adopted in Phase 0).
- **msitarzewski/agency-agents** — **305 agent personas** (subagents, not skills). Kept as reference; NOT installed as skills or subagents.
- **trailofbits** — 68 blockchain/fuzzing/audit skills dropped (only 15 relevant security/eval skills kept).
Rationale: the user chose "keep the current 82" — maximum relevance, minimum context bloat ("god level" ≠ skill count).

## Prompt 002 actual usage
No skill executed code, mutated the repo, accessed secrets, or made network calls during Prompt 002. Design/UX and security skills were used as **advisory references** only. Supply chain is frozen.
