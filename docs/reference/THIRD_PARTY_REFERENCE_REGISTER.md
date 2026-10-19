# THIRD-PARTY REFERENCE REGISTER

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** PROMPT 000A §13; Bible §53(P000 MCP policy). **External repos are research references, NOT canonical architecture authority.** No external repo may silently define architecture. Detailed study: `REFERENCE_REPO_STUDY.md`.

| # | Name / URL | License | Purpose | Exact concept learned | Code copied? | Provenance | Supply-chain status |
|---|---|---|---|---|---|---|---|
| 1 | obra/superpowers — github.com/obra/superpowers | MIT © 2025 Jesse Vincent | skill format + engineering discipline | `SKILL.md` `name`+`description`("Use when…") format; TDD-for-process; verification-before-completion; subagent-driven dev | **NO — PATTERN STUDY ONLY** | shallow clone to `/tmp/ref-superpowers`, inspected read-only | not a dependency; nothing vendored |
| 2 | msitarzewski/agency-agents — github.com/msitarzewski/agency-agents | MIT © 2025 AgentLand Contributors | agent taxonomy + governance | "divisions" taxonomy; `divisions.json` CI-enforced source of truth; per-agent frontmatter | **NO — PATTERN STUDY ONLY** | shallow clone to `/tmp/ref-agency-agents`, read-only | not a dependency |
| 3 | affaan-m/ECC — github.com/affaan-m/ECC | MIT © 2026 Affaan Mustafa | agent manifest + routing + prompt defense | `agent.yaml` (`spec_version`, `model.preferred/fallback`, skills catalog); per-agent `tools`/`model`; inline Prompt Defense Baseline | **NO — PATTERN STUDY ONLY** | shallow clone to `/tmp/ref-ecc`, read-only | not a dependency |
| 4 | trailofbits/skills — github.com/trailofbits/skills | **CC-BY-SA-4.0** (ShareAlike) | security/eval/testing skills | semgrep/codeql/sarif, libfuzzer/aflpp/libafl fuzzing, harness-writing, constant-time-testing, coverage-analysis, code-improver, second-opinion | **NO — PATTERN STUDY ONLY** | shallow clone `/tmp/ref-tob-skills`, read-only | **ShareAlike: do NOT vendor content into repo; reference patterns only** |
| 5 | OthmanAdi/planning-with-files — github.com/OthmanAdi/planning-with-files | MIT | persistent on-disk planning | `task_plan.md`/`findings.md`/`progress.md` as working memory; lifecycle hooks; 5+ tool-call tasks | **NO — PATTERN STUDY ONLY** | shallow clone `/tmp/ref-planning-files`, read-only | not a dependency |
| 6 | pbakaus/impeccable — github.com/pbakaus/impeccable | Apache-2.0 | code-quality/verification | Rust verification engine + `impeccable` skill; code-quality gates | **NO — PATTERN STUDY ONLY** | shallow clone `/tmp/ref-impeccable`, read-only | not a dependency (NOTICE attribution if ever vendored) |
| 7 | muratcankoylan/Agent-Skills-for-Context-Engineering — github.com/... | MIT | context engineering | context fundamentals/degradation/compression/optimization, memory systems, multi-agent patterns, harness-engineering, long-horizon-prompting | **NO — PATTERN STUDY ONLY** | shallow clone `/tmp/ref-ctx-eng`, read-only | not a dependency |
| 8 | nextlevelbuilder/ui-ux-pro-max-skill — github.com/... | MIT | UI/UX design intelligence | priority rules: contrast 4.5:1, touch 44×44, safe areas, reduced-motion, semantic color tokens, no emoji-as-icons; styles/palettes/font-pairings | **NO — PATTERN STUDY ONLY** | shallow clone `/tmp/ref-uiux-promax`, read-only | not a dependency; informs P0-Q / Design System |
| 9 | plugin87/ux-ui-agent-skills — github.com/plugin87/ux-ui-agent-skills | MIT © 2026 Thientan Soparat | design/UX agent skills (~26) | design-review, design-qa, a11y-audit, ux-writing, design-tokens, critique, image-to-code, brandkit | **NO — PATTERN STUDY ONLY** (skills installed to personal `~/.claude`, not repo) | shallow clone `/tmp/ref-uxui-agent`, read-only | informs P0-Q; excluded `tests/fixtures/.../leaky` bad example |

**Skill installation (2026-10-18):** 82 skills from repos #1–#9 installed to the user-global `~/.claude/skills/` (NOT the product repo), execution `hooks:` stripped (least-privilege/security-by-design), trailofbits (CC-BY-SA) curated to 15 relevant security/eval skills and kept only in personal `~/.claude` (never in-repo, to avoid ShareAlike entanglement). Reversible via `~/.claude/skills/_GEN8_INSTALL_MANIFEST.json`. This is personal tooling, NOT a product dependency; nothing is imported/shipped by Gen8.

## Rules applied (PROMPT 000A §13; Bible §53)
- **No code copied** from any of the three. All usage is `PATTERN STUDY ONLY`. If any code is ever vendored later, this register must record exact files/lines + license obligations, and an ADR must approve it.
- Patterns adopted are reconciled against the **Bible's own schemas** (Appendix B AgentManifest / Appendix C SkillContract) — the Bible governs; the references only informed structure (D-0009).
- Clones live under `/tmp` (ephemeral), are not part of the repo, and are not a build dependency. No secrets, no network trust extended.
- These repos are **not** canonical authority; precedence remains: law/policy → Build Bible → Canonical Master Spec → prior decisions (Bible §2).

## Supply-chain posture
Nothing from these repos is imported, executed, or shipped. Future real dependencies go through dependency scanning + SBOM (SEC-001) and an ADR.
