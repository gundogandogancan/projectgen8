# P009A Phase C — Provisional Identity
`ExtensionProvisionalIdentityV1` (PhaseCContractsV1.swift): ShotID + provisional ContentItemID + relation
(CANDIDATE_SAME/CANDIDATE_NEW/AMBIGUOUS — Tier-0 SAME decisions are RECLASSIFIED to CANDIDATE semantics, never
authoritative) + strongNew + compact fired-evidence list + independent-family count + profile/policy/shot revisions.
Tier-0 inheritance: structurally impossible (engine grants inheritance only in APP_FULL_TIER1 and never on
provisional identity — `testTier0NeverInheritsSafeAdmission`). ContentDNA under provisional identity (§9):
`mintDNA` returns nil for provisional items (`testNoDurableDNAWhileProvisional`); `ShotOnlyEvidenceRecordV1` carries
shot-level evidence with IMMEDIATE risk escalation (monotone-max); Tier-1 merge consolidates later (coalescer test);
split invalidates/rebuilds (existing DNA-invalidation tests).
