# R3 §8 — Contextual Counter-Example Corpus V1 (honest findings)

**Status:** `TESTED` (synthetic, DEVICE_UNVERIFIED) · **Source of truth:** `ContextCorpusR3Tests.ContextCorpusR3Tests` (GuardianMediaTests)
**Rights:** 100% synthetic strings + synthetic luma grids authored in the test. Does **NOT** touch the RWC/M3 corpus rights gates.
**No threshold fitting (§8 law):** the corpus is MEASURE-ONLY. No production threshold is read from, or adjusted to, these fixtures.

## What it exercises (REAL production paths, not mocks)

- **OCR-text pairs** → the real frozen `LanguageOCRExpertV1` lexicon, driven through the new pure interpreter
  `GeneralContentCharacterV1.evaluate(...)` — the SAME code the broadcast extension now calls on the cross-app path.
- **Visual pair (7)** → the real `GuardianCanonicalSamplerV1` area-average grids + perceptual comparison, plus the
  `PersonalRelationLadderV1` tier classification.
- **Personal pairs (8, 9)** → the real `PersonalRelationLadderV1` over real `ShieldMatchState` tiers.
- **Child-vs-adult (10)** → the real frozen `ChildAgePolicyEngineV1` (profile policy input).

## The core honest finding (mandate §8)

**Today's lexicon signals are CONTEXT-BLIND.** A death-NEWS text and a violence-GLORIFYING text both raise the
mortality marker; educational disease and fear-exploiting disease both raise the disease marker. The system cannot
read stance, fiction-vs-reality, or intent from the lexicon alone. This is surfaced to the user ONLY as a **risk
marker ("işaret")**, never a harm verdict — and the corpus proves exactly where the blindness lives.

**Text pairs separable today = 2 / 7.** Both "separable" cases (pairs 5 and 11) are separable **only by lexical
accident** — the benign side happened to lack lexicon terms — **NOT** by context understanding. That is honestly
noted in the row text, not hidden as a win.

**Contextual false associations (a benign/supportive side A flagged CAUTION) = 3 / 7** (pairs 1, 2, 4). These are
expected given context-blindness; they are MEASURED and reported, not suppressed. They are the reason a general
caution is a **marker**, never a certainty.

## Findings table (as printed by the test run)

| # | Pair | A (benign/supportive/fiction) | B (harmful/manip/real) | Separated today? | Honest note |
|---|------|-------------------------------|------------------------|------------------|-------------|
| 1 | death-news / violence-glorify | CAUTION | CAUTION | ❌ | Both trip mortality markers → context-blind. (false assoc on A) |
| 2 | disease-education / disease-fear | CAUTION | CAUTION | ❌ | Both trip disease/mortality markers. (false assoc on A) |
| 3 | sports-debate / targeted-insult | EXAMINED_NO_MARKER | EXAMINED_NO_MARKER | ❌ | Profanity/anger lexicon sparse; no targeted-insult detector (H1 open). |
| 4 | earthquake-info / panic-creation | CAUTION | CAUTION | ❌ | Both trip disaster markers → context-blind. (false assoc on A) |
| 5 | fictional-fight / real-violence | EXAMINED_NO_MARKER | CAUTION | ⚠️ | Separable ONLY because A lacked lexicon terms — a lexical accident, not a fiction/reality distinction. Visual violence is H1 UNAVAILABLE. |
| 6 | anti-violence / pro-violence | EXAMINED_NO_MARKER | EXAMINED_NO_MARKER | ❌ | Lexicon reads words, not stance → NOT separable. |
| 11 | supportive-negative-words / threatening | EXAMINED_NO_MARKER | CAUTION | ⚠️ | Separable ONLY because A's fear/mortality terms fell below the lexicon — a lexical accident, not context (the §8 limit). |
| 7 | same-color / different-subject (visual) | — | — | ✅ | REAL canonical sampler: same dominant brightness, different content, correctly NOT confused. VISUAL_SIMILARITY never actions. |
| 8 | same-reference / different-photo (visual) | diff-photo `VISUAL_SIMILARITY` not actionable | same-ref `DIRECT_REFERENCE` actionable | ✅ | EXACT actions, a different photo does not. |
| 9 | real-relation / incidental co-occurrence (personal) | co-occurrence `UNKNOWN` not actionable | needs a DIRECT_REFERENCE | ✅ | Co-occurrence ALONE never mints a match (mandate §3 hard law). |
| 10 | child-profile / adult-profile (same gore item) | adult `ALIGNED` | child `AGE_UNKNOWN_REVIEW` | ✅ | REAL `ChildAgePolicyEngineV1`: child profile is strictly stricter. |

Latency per text evaluation: ~0.5–1.0 ms (synthetic, macOS; DEVICE_UNVERIFIED).

## Hard laws the corpus PINS (must hold regardless of context-blindness)

- **No contextual false association ever ACTIONS.** A visual similarity / low tier / co-occurrence / no-match never
  produces an actionable personal match (pairs 7, 8-diff, 9). A benign text's false CAUTION is a *marker-level* signal,
  not an action — and the general caution surface is WARN-only on a 3rd-party app anyway (rule 18).
- **Child-safety floor outranks personal preference** (pair 10 + `testChildPrecedenceOutranksPersonalPreference`:
  the real `ParentPreferencePolicyV1` is stricter-only — a preference can tighten but never loosen a child decision,
  and the child engine exposes no loosen/allow knob) — ADR-0007.
- **Visual similarity / co-occurrence are NON-actionable** by construction (mandate §3).
- **A benign side is never made WORSE than its harmful twin** for the measurable manipulation pairs (no inverted
  marker ordering).

## What the corpus deliberately does NOT assert

It does **not** assert that pairs 1, 3, 4, 6 are separated — they are **not**, and asserting separation would be a
lie. The non-separable pairs are the honest R3 §8 finding: **the current limitation is real and measured, not a
test failure to hide.** Closing it needs a context-aware model (stance, fiction/reality, intent) with independent
calibration gates — out of scope for V1 (mandate §1/§2/§5).
