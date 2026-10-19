# P009A — ContentDNA (Item Level)

Status: `TESTED`. Source: `ContentDNAItemV1` + `ContentItemGroupingEngineV1.mintDNA`.

## Canonical formula (§10)
```
Shot Evidence → Item Group → Item-Level ContentDNA → PersonalPolicy → PersonalSuitability
```
DNA is minted PER ITEM (not per shot): one expensive understanding → many cheap personal decisions.

## Record contents
identity (`ContentDNAID` + `itemID` + `ContentIdentityRevision`) · shot/scene counts · modality evidence summaries
(edge counts per VISUAL/TEXT/AUDIO/TEMPORAL/SURFACE/CACHE — derived only) · temporal span · risk escalation flag
(monotone-max per §8) · uncertainty (provisional identity → 0.8) · provenance chain · privacy class
(DERIVED_NON_RECONSTRUCTIVE) · model versions (`item-grouping-policy-v1`, `boundary-policy-v5`) · cache expiry ·
invalidated flag.

**Numeric suitability score remains OFF** (§25); DNA carries evidence, never an uncalibrated number. UNKNOWN stays
the outward fallback.

## Lifecycle discipline
- SPLIT invalidates the item's DNA (cached understanding may not apply to either half) —
  `testContentDNAInvalidationOnSplit`; the cache drops invalidated DNA (`ContentIdentityCacheV1.invalidate`).
- MERGE bumps the item revision (MERGED); DNA re-mint required at the new revision.
- Cache records carry confidence/version/expiry/privacy/local-scope; collisions degrade to re-analysis (§11).

## Relationship to prior ContentDNA versions
Prior ContentDNA (V2–V4, shot/clip-scoped in lab contexts) remains valid for its scopes; `ContentDNAItemV1` is the
first ITEM-scoped DNA and the feed-level unit that PersonalPolicy/Suitability will consume in P009B+.
