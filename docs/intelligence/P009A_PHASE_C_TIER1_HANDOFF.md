# P009A Phase C — Tier1IdentityHandoffV1
Per shot decision the extension constructs a handoff record (production-wired in SampleHandler): observation/shot/
provisional-item IDs, transition type, temporal evidence (gap/prevDwell/elapsedItem ms), compact visual evidence
(theme/proj/hist/chrome/regional scalars), ambiguity reason, strongNew, prior relation, thermal bucket, capability
profile, model/policy versions (incl. evidence-independence-guard revision). Storage: `Tier1HandoffBufferV1`
bounded in-process ring (64) — NO persistence, NO raw private media by construction (Mirror-tested). This is the
contract Tier-1 consumes for full grouping + ContentDNA finalization when in-process multimodal evidence exists.
