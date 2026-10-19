# P009B — Cross-Modal Expert Graph (`CrossModalExpertGraphV1`)

**File:** CrossModalGraphV1.swift · **Tested:** corpus conflict scenarios + `testSafetyVsBenefitConflictRepresented`

## Naming

The P008 `CrossModalEvidenceGraphV1` (CrossModalEvidenceGraph.swift) is the frozen concept-level fuser
over `MultimodalContentUnderstandingV1`. THIS type relates P009B `ExpertEvidenceV2` records — hence the
distinct name `CrossModalExpertGraphV1`. Both coexist; neither replaces the other in this phase.

## Edge semantics (pairwise over live evidence; NO majority vote)

| Condition | Edge |
|---|---|
| either side `inputModalityAvailable == false` | `UNAVAILABLE_DEPENDENCY` |
| risk (`safety:sensitive*`/`safety:fear*`/`temporal:risk-escalated`/`symbol:warning`) vs positive (`benefit:` non-none) | `CONTRADICTS` — "safety-critical evidence dominates; no vote" |
| risk + risk | `AGREES_WITH` (risk-agreement) |
| positive + positive | `AGREES_WITH` (benefit-agreement) |
| otherwise | `WEAK_SUPPORT` (co-occurrence) |
| stale evidence | `STALE` self-edge; excluded from live pairing |

## Laws

- Contradictions are REPRESENTED, never averaged away. `educational-plus-sensitive` and
  `benign-then-risky` corpus scenarios require ≥1 contradiction edge and pass.
- Stale (old-generation) evidence can never form agreement edges with current evidence.
- Bounded (`maxEdges` ring) — no unbounded growth.
- The graph produces structure for `ContentUnderstandingStateV1`; it does not decide anything.
