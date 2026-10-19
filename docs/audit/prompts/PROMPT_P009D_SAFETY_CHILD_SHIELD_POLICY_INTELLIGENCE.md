# PROMPT P009D — SAFETY + CHILD AGE + PERSONAL SHIELD POLICY INTELLIGENCE

**RECOMMENDED MODEL:** Claude Fable
**EFFORT:** High / maximum practical reasoning
**MODEL SWITCH:** `/model` → Fable
**VERIFY:** `/status`

# 0. HARD ENTRY GATE

DO NOT START unless the independent P009C-R1 re-audit final verdict is exactly:

`PASS — P009C CONTENT WORLD MODEL LOCKED; GO TO P009D`

If this exact PASS is not present:
STOP and return:
`BLOCKED — P009C-R1 RE-AUDIT PASS REQUIRED`

Do not infer PASS from builder reports.

# 1. MISSION

Convert the locked non-personal Content World Model into policy intelligence for:
- Safety
- Child/Family age suitability
- Personal Shield
- strong protection states
- age caution/restriction
- personal topic conflict
- UNKNOWN/REVIEW states

Do NOT yet create a calibrated numeric PersonalSuitability score.

Canonical path:

CONTENT WORLD MODEL
→ SAFETY POLICY EVIDENCE
→ CHILD AGE POLICY
→ PERSONAL SHIELD POLICY
→ POLICY CONFLICT RESOLUTION
→ ADMISSION STATE CANDIDATE
→ REASON CODES

Still OFF:
- 0–100 score
- 0–10 score
- production glyph
- production motion

# 2. CORE COMPONENTS

Implement:
- SafetyPolicyEngineV1
- HighRiskVisualSafetyRegistryV1
- ChildAgePolicyEngineV1
- AgeSuitabilityPolicyV1
- PersonalShieldPolicyV2
- PolicyConflictResolverV1
- AdmissionStateCandidateV1
- PolicyReasonCodeV1
- PolicyProvenanceV1
- PolicyVersionRegistryV1
- JurisdictionAgeBandRegistryV1
- ParentPreferencePolicyV1
- SafetySentinelRegistryV1

# 3. SAFETY DIMENSIONS

Canonical safety dimensions:
- explicit/sexual
- violence/gore/severe injury
- fear/threat
- self-harm
- drugs/alcohol
- gambling
- dangerous behavior
- profanity
- sexual themes
- sensitive death/disease/disaster/news
- manipulation/attention pressure

Every dimension must carry one status:
- IMPLEMENTED_CALIBRATED
- IMPLEMENTED_UNCALIBRATED
- HEURISTIC_SUPPORT_ONLY
- UNAVAILABLE

Never silently upgrade status.

# 4. H1 HIGH-RISK VISUAL SAFETY

H1 remains an explicit blocker unless actually closed.

For every high-risk visual class record:
- exact provider/model
- exact class definition
- capability profile
- dataset/provenance
- calibration status
- held-out evidence
- false-safe evidence
- device/runtime status
- version

If no dedicated audited classifier exists:
- keep `UNAVAILABLE_EVIDENCE_BACKED`
- never infer visually safe from generic Vision labels
- never produce positive admission from missing H1 evidence

Strong lexical/audio/world-model risk may still escalate.

# 5. CHILD / FAMILY POLICY

Child age is:
- parent/guardian-entered only
- never inferred from face/image
- minimum necessary data
- local/private default

Support versioned, jurisdiction-aware age bands.

Dimensions:
- adult/explicit
- violence/gore
- fear
- drugs/alcohol
- gambling
- self-harm
- dangerous behavior
- profanity
- sexual themes
- manipulative ads
- sensitive news/death/disease
- educational usefulness

Outputs:
- AGE_ALIGNED
- AGE_CAUTION
- AGE_RESTRICTED
- AGE_UNKNOWN_REVIEW

No numeric child score in P009D.

# 6. AGE POLICY SOURCE TRUTH

Separate:
- legal ratings
- provider ratings
- parent preferences
- developmental suitability
- Gen8 evidence

Never present developmental suitability as a legal rating.
Every decision records source class.

# 7. PERSONAL SHIELD V2

Consumes canonical concepts, not raw text.

Supports:
- blocked/avoided topics
- sensitive categories selected by user
- optional preferred/positive topics
- named concepts/entities where supported
- language-independent canonical concepts

Rules:
- cross-language matching only through canonical IDs
- unsupported semantic guess cannot hard-block
- Shield-match confidence separate from policy outcome
- strong safety protection outranks positive preference
- local-first storage
- no silent cloud sync

# 8. POLICY PRECEDENCE

Canonical precedence:

STRONG_PROTECTION
> AGE_RESTRICTED
> SHIELD_MATCH
> AGE_CAUTION / SAFETY_CAUTION / CONFLICT
> UNKNOWN / REVIEW
> NEUTRAL / CONTENT_CHARACTER

Positive/benefit evidence never overrides strong protection, age restriction, or unresolved high-risk conflict.

# 9. POLICY CONFLICT RESOLUTION

Handle examples:
- educational + graphic injury
- humor + self-harm phrase
- calm music + explicit visual
- Shield-blocked topic + educational benefit
- age-aligned learning + frightening imagery
- parent preference vs general age policy

Output:
- resolved state
- dominant reason
- secondary reasons
- unresolved conflicts
- confidence
- provenance

No majority vote.

# 10. ADMISSION STATE CANDIDATE

States:
- STRONG_PROTECTION
- AGE_RESTRICTED
- SHIELD_MATCH
- CAUTION
- AGE_CAUTION
- UNKNOWN
- REVIEW
- NEUTRAL

Categorical only.
Not a numeric score.

# 11. REASON CODES

Stable typed codes, e.g.:
- H1_VISUAL_UNAVAILABLE
- HIGH_RISK_MULTIMODAL_CONFLICT
- CHILD_AGE_RESTRICTED_EXPLICIT
- CHILD_AGE_CAUTION_FEAR
- SHIELD_TOPIC_MATCH
- SHIELD_ENTITY_MATCH
- POLICY_CONFLICT_UNRESOLVED
- EVIDENCE_INSUFFICIENT
- PROVIDER_UNAVAILABLE
- IDENTITY_PROVISIONAL
- OOD_UNKNOWN

# 12. UNKNOWN / FAIL-CLOSED

If:
- H1 is required but unavailable
- identity unresolved
- evidence insufficient
- conflict unresolved
- child policy source missing
- jurisdiction unsupported
- OOD

then do not invent a positive state.

Prefer UNKNOWN / REVIEW / CAUTION according to policy.

# 13. RIGHTS-CLEAR POLICY CORPUS

Required families:
- educational but graphic
- humorous but explicit
- prevention-context self-harm
- literal self-harm encouragement
- drug education vs promotion
- gambling news vs promotion
- profanity quote vs direct insult
- frightening child content
- mild cartoon violence
- severe realistic violence
- sexual themes by age band
- manipulative child-targeted CTA
- sensitive news
- mortality/disease education
- Shield topic match
- Shield near-match false positive
- cross-language Shield concept match
- unsupported age/jurisdiction
- H1 unavailable path
- multi-policy conflict

# 14. ANNOTATION

Annotate independently:
- safety dimension presence
- severity band
- context qualifier
- child suitability by policy source
- Shield canonical concept
- precedence outcome
- UNKNOWN/REVIEW requirement

Preserve disagreement.

# 15. SAFETY SENTINELS

Create curated sentinel registry:
- explicit
- severe violence/gore
- self-harm encouragement
- dangerous behavior
- age-critical sexual content
- child-targeted manipulation

Later calibration must not produce false-safe on this sentinel set before user-facing score/glyph release.

# 16. PRIVACY

Child age and Shield:
- local-first
- OS-protected storage where available
- minimal data
- no inferred age
- no hidden analytics/cloud

Policy logs:
- derived reason codes only
- no raw transcript/frame/audio

# 17. VERSIONING

Bind every policy decision to:
- policy engine version
- taxonomy version
- age registry version
- jurisdiction version
- Shield version
- world-model version
- provider/model versions
- timestamp/freshness

Changing Shield/child policy should recompute cheap policy state without re-understanding valid ContentDNA.

# 18. CACHE SEPARATION

Keep non-personal:
ContentDNA / WorldModel

separate from personal:
Personal/Family Policy Decision

No cross-user policy cache leakage.

# 19. DEVELOPER POLICY HUD

DEBUG-only:
- safety dimensions + implementation status
- H1 status
- child age band
- age-policy source
- Shield matches
- precedence path
- reason codes
- UNKNOWN/REVIEW cause
- AdmissionStateCandidate
- score display OFF

No production glyph.

# 20. PHYSICAL / IN-APP VALIDATION

After freeze, user-gated validation on owned/rights-clear examples:
- Shield match
- age caution
- age restricted
- H1 unavailable
- educational+sensitive conflict
- explicit UNKNOWN
- changed policy using cached ContentDNA

Capture route, reasons, cache reuse, latency, privacy, HUD truth.

# 21. METRICS

Per dimension/policy:
- precision/recall/F1 where labels exist
- false-safe
- false-warning
- abstention/UNKNOWN
- age-policy agreement
- Shield precision
- conflict-resolution accuracy
- reason-code accuracy
- cache reuse
- latency

No final composite score.

# 22. PREDECLARED GATES

- no positive/neutral state when strong protection supported
- no AGE_ALIGNED when age-restricted evidence supported
- H1 unavailable cannot be treated visually safe
- Shield canonical match works cross-language
- unsupported Shield guess cannot hard-block
- age never inferred from image
- legal vs developmental policy separated
- child policy versioned
- no raw child/shield/content data leaks
- personal policy cache isolated
- reason codes provenance-bearing
- UNKNOWN/REVIEW first-class
- score/glyph OFF

# 23. CARRIED BLOCKERS

Keep explicit:
- App Group/cross-process limitation
- extension Shield limitation
- final score calibration not done
- H1 incomplete if still open
- ChildAgePolicy device proof if pending
- residual Tier-0 near-identical burst-window merge
- proof-log beta privacy decision
- LAB_ONLY/UNAVAILABLE expert paths
- unproven device paths

# 24. TESTS

All prior tests remain green.

Add:
- strong-protection precedence
- age restriction precedence
- Shield match
- cross-language Shield
- Shield false positive
- educational+graphic conflict
- prevention-context self-harm
- literal self-harm encouragement
- drug education/promotion
- gambling news/promotion
- quote vs direct profanity
- child fear
- mild vs severe violence
- sexual-theme age bands
- manipulative child CTA
- unsupported jurisdiction
- H1 unavailable
- age not inferred
- legal-vs-developmental source
- cached DNA + changed policy
- no cross-user policy cache
- reason-code correctness
- raw-data leakage prevention
- score/glyph OFF

# 25. GITHUB DISCIPLINE

Use canonical GitHub evidence workflow:
- branch `phase/p009d`
- atomic commits
- push coherent changes
- full suite
- clean tree
- audit-candidate tag `gen8-p009d-audit-candidate`
- independent audit exact tag/SHA
- no force-push/amend after audit starts

# 26. FINAL REPORT

Return:
1. ACTIVE MODEL / EFFORT
2. ENTRY P009C LOCK
3. GITHUB BRANCH / COMMITS / PUSH
4. SAFETY POLICY ENGINE
5. H1 REGISTRY / STATUS
6. CHILD AGE POLICY
7. AGE POLICY SOURCE TRUTH
8. PERSONAL SHIELD V2
9. POLICY PRECEDENCE
10. CONFLICT RESOLVER
11. ADMISSION STATE CANDIDATE
12. REASON CODES
13. UNKNOWN / FAIL-CLOSED
14. POLICY CORPUS
15. ANNOTATION
16. SAFETY SENTINELS
17. PRIVACY
18. VERSIONING
19. CACHE SEPARATION
20. DEVELOPER HUD
21. TUNE
22. FREEZE
23. HELD-OUT
24. STRESS / OOD
25. PHYSICAL / IN-APP VALIDATION
26. RESOURCE / LATENCY
27. CARRIED BLOCKERS
28. SCORE / GLYPH STATUS
29. TESTS
30. KNOWN LIMITATIONS
31. FILES CHANGED
32. AUDIT-CANDIDATE TAG / SHA
33. STATUS

Status exactly one:
`READY FOR INDEPENDENT P009D AUDIT`
`FIX REQUIRED`
`BLOCKED`

Then STOP.
Do not start P009E calibration.
Do not enable score/glyph/motion.
