# P009C-R1 — Findings Lock (immutable evidence anchor)

**Date:** 2026-10-19 · **Entry verdict:** `FIX CRITICAL P009C FINDINGS` · **Branch:** `phase/p009c-r1`
**Prompt:** `docs/audit/prompts/PROMPT_P009C_R1_PRIVACY_LEXICON_CLOSEOUT.md` · **Workflow:** `docs/canonical/GEN8_GITHUB_EVIDENCE_WORKFLOW_v1.0.md`

## SHA-256 locks

| Artifact | SHA-256 / ref |
|---|---|
| Independent P009C audit report | `fe04cfcbceb1329d190cb466f8cf395b6e1dba706e82609436ab337a18c3677a` |
| **ORIGINAL** `AUDIT5_P009CProbes.swift` (frozen copy: `docs/audit/AUDIT5_P009CProbes_ORIGINAL_LOCKED.swift.txt`) | `97ec7e22e391d60d443bae4ea988d4cd40542c19583b324082e8acdd88b3cdcf` |
| Audit commit | `b648cb1` · implementation commit `aaa0cf6` · prior locks `42b96a2`/`d61ca15`/`de58f0c`/`4ce238f` |

## GitHub discipline status

Branch `phase/p009c-r1` created off locked main head (`b648cb1`). Atomic commits with finding IDs; SHAs
recorded in the implementation-evidence doc. **PUSH = EXTERNAL_EXECUTION_DEPENDENCY:** this repository has
NO configured remote (`git remote -v` empty). Tags/commits are created locally and immutable; the user
must add a GitHub remote (`git remote add origin <url> && git push -u origin --all --tags`) to complete
the push steps. Nothing is amended/squashed after the audit-candidate tag.

## Characterization-probe inversion manifest (declared BEFORE any fix)

Exactly THREE AUDIT5 assertions document the audited defects and were written by the auditor to flip on a
proper fix (its own comment on F-1: "a proper fix … should FLIP this assertion"). The original file is
SHA-frozen above; in the active file ONLY these are inverted, annotated `// P009C-R1 FIX INVERSION`;
every other line stays byte-identical:

| Probe | Original (defect) assertion | After-fix assertion |
|---|---|---|
| `testProbe_FINDING_VisualLabelTokenReachesDurableDNA` (F-1) | planted visual-label token REACHES durable DNA; prefix whitelist accepts `entity:<raw>`; finalizer does not refuse | token NEVER appears in DNA (unmapped label = ephemeral); `PersistenceLawValidatorV2` rejects `entity:object:<token>`; finalize succeeds WITHOUT the token (closed-vocabulary law, not a token blacklist) |
| `testProbe_FINDING_CrossLanguageSubstringTopicPollution` (F-2) | EN "lesson" yields `concept:urgency` via TR `son` substring | NO urgency concept from EN educational text (locale-partitioned exact-token matching) |
| `testProbe_ForeignEvidenceDNARefusedButCacheAccepts` (F-5, final assert only) | cache accepts the impure model | cache REJECTS it (`WorldModelEvidencePurityGateV1`); lookup returns nil |

## Rules honored
No token blacklists; no probe weakened/deleted; `Lexicons.swift` word lists untouched (language-aware
matching + a VERSIONED supplemental vocabulary layer sit above them); prior-phase artifacts byte-intact;
CAL_RESERVED untouched.
