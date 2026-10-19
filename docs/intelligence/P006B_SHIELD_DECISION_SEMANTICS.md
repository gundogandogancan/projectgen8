# P006B — Shield Decision Semantics

> **UNKNOWN IS NOT A MATCH. UNAVAILABLE IS NOT A MATCH. STRICT HOLD BELONGS TO GLOBAL ADMISSION.**

## 1. The eight states (`ShieldMatchState`, `GuardianCore/ShieldV2.swift`)
Determinable:
```
NO_MATCH  MATCH_LOW  MATCH_MEDIUM  MATCH_HIGH  MATCH_EXACT
```
Non-determinable (the Shield itself cannot tell whether the rule matches):
```
MATCHABILITY_UNKNOWN   MATCHER_UNAVAILABLE   EVIDENCE_CONFLICT
```
`isMatch` is true **only** for the four MATCH_* tiers. `isNonDeterminable` is true for the last three. A non-determinable
state does **not** mean safe, does **not** mean matched, and does **not** auto-hold content. `matchRank` orders only
actual matches — a non-determinable result can never outrank or masquerade as a match.

## 2. Shield layer decision (`ShieldLayerDecision`) — the Shield MAY ABSTAIN
`ShieldActionControllerV2.decide(rule:match:)`:
| Match state | Shield layer decision | Action recommendation |
|---|---|---|
| MATCH_EXACT / MATCH_HIGH | `EXECUTE` | the rule's configured action (may hide/skip if capability allows) |
| MATCH_MEDIUM | `ASK` (if configured action destructive) / `WARN` | ask / warn |
| EVIDENCE_CONFLICT | `ASK` | ask |
| MATCH_LOW | `NOTE` | allow-with-note (never a silent hide) |
| NO_MATCH | `NO_SHIELD_ACTION` | — |
| MATCHABILITY_UNKNOWN / MATCHER_UNAVAILABLE | **`NO_SHIELD_DECISION`** (abstain) | **none** |

## 3. ShieldDecision contract (`PersonalShieldDecision`)
`ruleID?, matchState, layerDecision, actionRecommendation?, coverage, missingMatchers[], uncertainty, reasonCodes[],
exceptionApplied, evaluatedRules, matchersRun`. `coverage` = fraction of the winning rule's required matchers that could
run; `missingMatchers` names the ones that could not; `uncertainty` rises with non-determinable coverage.

## 4. Global admission owns strict HOLD (`GlobalAdmissionController`)
The Shield never issues a system-level HOLD. The global controller maps the ShieldDecision + mode:
- `EXECUTE` → HOLD (the user's own hard rule matched — honor it).
- `WARN`/`ASK` → CAUTION. `NOTE` → PROCEED. `NO_SHIELD_ACTION` → PROCEED.
- `NO_SHIELD_DECISION` → **PROCEED in normal mode**; HOLD only under `STRICT_NO_EXPOSURE_IF_UNVERIFIED`
  **and** a controlled surface **and** `modalityExpectedButUnavailable` (§5). Reason-coded `ADMIT_STRICT_HOLD_UNVERIFIED`.

**Consequences (tested):** a missing music matcher cannot warn every non-music item; a missing speech matcher cannot
hold every image. Abstention is isolated to the rule whose matcher was unavailable, and never escalates by default.

## 5. Rule-specific matcher routing (§3)
`ShieldRuleV2.effectiveMatchers` = explicit `allowedMatchers` or the per-input-type default
(`ShieldRuleV2.defaultMatchers`). The evaluator runs a matcher on a rule **only** if the matcher's id is in that set
**and** `matcher.handles(inputType)` is true. A `MUSIC_TRACK` rule routes only to the music matcher; if that matcher is
unavailable the rule yields `MATCHER_UNAVAILABLE` → `NO_SHIELD_DECISION`, not a global hold.

## 6. Cross-language (§9) — certification-driven, not locale-string-driven
`SemanticTextMatcher` consults an injected `CrossLanguageConceptBridge`:
- `sameLanguage` / `verifiedCanonicalBridge` → a strong match may stay `MATCH_HIGH` (reason `CROSS_LANGUAGE_VERIFIED`).
- `unverifiedBridge` → downgrade one tier (`CROSS_LANGUAGE_DOWNGRADED`).
- `unavailable` → `MATCHABILITY_UNKNOWN`.
We never downgrade merely because locale strings differ, and never upgrade merely because machine translation returned a
phrase. The default bridge is conservative (cross-locale = unverified) until a certified pair is registered.
