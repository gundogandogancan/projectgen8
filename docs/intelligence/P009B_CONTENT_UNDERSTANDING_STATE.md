# P009B — Content Understanding State + ContentDNA Candidate

**File:** CrossModalGraphV1.swift · **Tested:** `testUnderstandingStateAndDNAMintRules` + corpus harness

## `ContentUnderstandingStateV1` — the first unified "what is happening?"

Built from provenance-bearing live evidence + the expert graph. Fields: identityStatus
(provisional/confirmed), per-domain modalityCoverage + expertAvailability, topicCandidates, entities,
intentCandidates, safetyEvidence, benefitEvidence, attentionPressure, emotionalLoad, temporalNarrative,
contradictions, uncertainty, oodFlags, evidenceQuality, provenance, staleEvidenceExcluded,
contentDNAReady, unknownReasons.

Laws:
- This is NOT PersonalSuitability. `evidenceQuality` is coverage×certainty bookkeeping, not a content score.
- UNKNOWN reasons are first-class state — the state prefers "unknown because X" over forced interpretation.
- Stale evidence is excluded and counted (`staleEvidenceExcluded`), never silently blended.

## `ContentDNACandidateV2` — durable mint rules

```
mint(...) -> nil  when itemProvisional == true        (provisional identity NEVER finalizes)
mint(...) -> nil  when contentDNAReady == false       (no quality evidence yet)
otherwise -> provenance-bearing, model-versioned, TTL-stamped, derivedNonReconstructive candidate
```

- Provisional items keep shot/scene evidence upstream (Tier-1 handoff buffer); nothing durable is
  minted from an unresolved identity (P009A §17 law carried forward; tested both directions).
- The DNA candidate stores label GROUPS (topic/safety/benefit/attention) + temporal summary + coverage +
  uncertainty — no raw text, no media, no reconstruction path.
