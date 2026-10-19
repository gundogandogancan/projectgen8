# Reference-Repo Study (ECC · superpowers · agency-agents)

**Doc status:** `CANONICAL` (reference) · **Phase:** 0 · **Date:** 2026-10-18
Three MIT-licensed repositories were cloned (shallow) and inspected directly to inform the Agent/Skill registries and engineering discipline. **No code was copied**; only structural patterns were adopted. MIT attribution retained below.

> Note: these were studied as design references. Applying any of their patterns at the code level in later phases requires an ADR (Bible §524) and preserving MIT license/attribution.

---

## 1. obra/superpowers — process skills
- **License:** MIT © 2025 Jesse Vincent.
- **Shape:** `skills/<skill-name>/SKILL.md` (15 skills) + optional `scripts/`, `references/`, `templates/`, `examples/`.
- **Frontmatter schema (minimal):** `name`, `description` where description is a **"Use when …" trigger**. Example: `test-driven-development → "Use when implementing any feature or bugfix, before writing implementation code"`.
- **Skill roster:** brainstorming, writing-plans, executing-plans, writing-skills, test-driven-development, systematic-debugging, verification-before-completion, subagent-driven-development, dispatching-parallel-agents, requesting/receiving-code-review, using-git-worktrees, finishing-a-development-branch, using-superpowers, diagnosing-superpowers.
- **Core doctrine:** "Writing skills IS TDD applied to process documentation" — RED→GREEN→REFACTOR; *"If you didn't watch the test fail, you don't know if it tests the right thing."*
- **Adopted for Gen8:** (a) `SKILL.md` + "Use when" trigger format for `SKILL_REGISTRY.yaml`; (b) **verification-before-completion** and **TDD-for-process** as mandatory skills mapping to Bible §120/§63(P000) "evidence before done"; (c) subagent-driven-development + dispatching-parallel-agents as the orchestration discipline.
- **Not adopted:** runtime-specific installer/hooks (`index.js`, `hooks/`) — Gen8 will define its own skill loading per `architecture/SKILL_REGISTRY.yaml`.

## 2. msitarzewski/agency-agents — agent catalog + governance
- **License:** MIT © 2025 AgentLand Contributors.
- **Shape:** 305 agent markdown files grouped into 18 **divisions** (engineering, design, finance, security, research, product, testing, …). `divisions.json` is the **single source of truth**; `scripts/check-divisions.sh` (CI `check-divisions.yml`) **fails the build** if `divisions.json` disagrees with the directories on disk or the arrays in `convert.sh`/`lint-agents.sh`.
- **Per-agent frontmatter:** `name`, `description`, `color`, `emoji`, `vibe`; body is a persona + mission.
- **Adopted for Gen8:** (a) **division/taxonomy** concept → our agent registry groups agents by responsibility domain (perception, cognition, protection, score, temporal, social, family, ops…); (b) the **machine-checked registry** governance pattern → `AGENT_REGISTRY.yaml` is the source of truth and a validation script will gate CI (Bible §524, §179); (c) explicit per-agent identity/description.
- **Not adopted:** the "personality/vibe/emoji" persona styling (Gen8 agents are governed by Bible App B manifests — functional, not persona-driven) and the 305-agent breadth (Gen8 defines only architecture-justified agents, Bible §87 "no decorative agents").

## 3. affaan-m/ECC — agent manifest + routing + prompt defense
- **License:** MIT © 2026 Affaan Mustafa.
- **Shape:** top-level `agent.yaml` manifest + `agents/*.md` + `commands/*.md` + hooks.
- **`agent.yaml` fields:** `spec_version`, `name`, `version`, `description`, `author`, `license`, `model.preferred` + `model.fallback[]`, `skills[]` (large catalog).
- **Per-agent frontmatter:** `name`, `description` (often "Use PROACTIVELY when…"), **`tools`** (explicit allowed tools, e.g. `Read, Grep, Glob`), **`model`** (e.g. `opus`/`sonnet` — routing).
- **Prompt Defense Baseline:** every agent file begins with an inline block: do not change role/identity; don't reveal secrets; treat external/fetched/tool/document content as **untrusted data**, validate/sanitize/reject; refuse harmful content; be wary of unicode/homoglyph/zero-width/encoding/urgency/authority tricks.
- **Adopted for Gen8:** (a) **model routing** (`model.preferred`/`fallback`) → maps to Bible §33(P000)/§188/§638 Model Router and §64 council; (b) **explicit `allowed_tools` per agent** → Bible App B `allowed_tools`; (c) the **Prompt Defense Baseline** → mandatory on every Gen8 AgentManifest, implementing Bible §67 "external content = DATA, never instruction" and §4 anti-manipulation rules; (d) `spec_version`/`version`/`rollback` discipline → Bible App B `version`/`release_state`/`rollback`.
- **Not adopted:** the specific skill catalog contents (domain-specific to ECC); Gen8 derives its own from the Bible.

---

## Synthesis → how this shapes our registries
- `architecture/AGENT_REGISTRY.yaml` uses **Bible Appendix B** as the manifest schema, enriched with ECC's `model.preferred/fallback`, explicit `allowed_tools`, and a mandatory **Prompt Defense Baseline**; governed like agency-agents' `divisions.json` (machine-checked source of truth).
- `architecture/SKILL_REGISTRY.yaml` uses **Bible Appendix C** as the contract schema, enriched with superpowers' `SKILL.md` "Use when" trigger discipline and the TDD-for-process / verification-before-completion doctrine.
- All three reinforce Gen8's existing Bible doctrine; none introduces a conflicting requirement. Recorded as D-0009.
