# P009A-R1 — Identity Evidence Profiles (canonical)

Status: `TESTED`. Source: `IdentityEvidenceProfileV1` (ProfileAwareGroupingV2.swift).
**Canon: a single global threshold across materially different evidence profiles is FORBIDDEN** (the P009A failure).

| profile | same-channels | unavailable | ceiling (frozen weights) | policy revision | fallback |
|---------|---------------|-------------|--------------------------:|-----------------|----------|
| `EXTENSION_FAST_TIER0` | theme, projection, histogram, edit-cadence, chrome, regional, cut-prior | captions, speech/audio, app bundle identity, cloud/VLM | **0.95** | `item-grouping-policy-v2-extension-tier0` | AMBIGUOUS provisional split |
| `APP_FULL_TIER1` | Tier-0 + caption-match + audio-continuity | cross-app bundle id, cloud/VLM (pending packs) | **1.60** | `item-grouping-policy-v2-app-tier1` | AMBIGUOUS provisional split |
| `FUTURE_SHARED_TIER1` | — | ALL (capability BLOCKED) | — | BLOCKED | BLOCKED |

Each profile declares modalities, channels, ceiling, resource budget, privacy class, merge-policy revision, and
fallback. Same-scores are NORMALIZED by the profile ceiling (`S = rawSame / ceiling`), so "merge confidence" means
"fraction of the evidence this profile could possibly have" — missing modalities are never negative evidence.
§3 acceptance matrix enforced this revision: Tier-0 TUNE+HELD-OUT+STRESS+DEVICE-LIKE all REQUIRED and run;
Tier-1 TUNE+HELD-OUT+regression run; FUTURE_SHARED blocked. "Tier-1 passed therefore Tier-0 is good enough" is
structurally impossible now (per-profile frozen revisions, logged every session).
