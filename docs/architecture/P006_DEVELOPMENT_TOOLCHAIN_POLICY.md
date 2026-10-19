# P006 — Development Toolchain Policy (Agents / Skills / MCP)

**Doc status:** `CANONICAL` · **Phase:** 6 · **Date:** 2026-10-18 · PROMPT 006 §33. **The application RUNTIME must NOT depend on Claude skills or MCPs.** They are development-time tools only.

## Runtime intelligence (ships in the product)
Specialist models (Apple-native + our deterministic/lexicon/trained heads) · deterministic engines (fusion/orchestrator/governor) · Apple frameworks (Vision/NaturalLanguage/SoundAnalysis/Speech/AVFoundation/CryptoKit) · internal orchestration. **No MCP, no Claude skill, no cloud is required for end-user Guardian inference.**

## Development agents (build-time only)
May assist: architecture audit · Swift/iOS implementation · ML training · security review · performance profiling · accessibility audit · localization QA · data/eval tooling. (See `AGENT_REGISTRY.yaml` build-time agents.)

## MCP / connectors (development/workflow aids only)
GitHub · issue tracking · CI · design source · official-docs search · observability. **No MCP reaches end-user runtime.**

## Skill supply-chain freeze (still active)
Per `CLAUDE_SKILL_ALLOWLIST.md`: 82 skills installed user-global, hooks stripped, minimal advisory allowlist, trailofbits personal-only (CC-BY-SA). **No new unapproved skill installation** (confirmed none this phase). These never ship in Gen8.

## Verification
Grep confirms no runtime import of MCP/skill machinery in `GuardianCore`/`GuardianIntelligence`/`GuardianMedia` — only Foundation + Apple frameworks. Product is self-contained, local-first.
