# PROMPT P009A-PHASE-C — TIER-0 CAPABILITY CLOSEOUT + DWELL FIX + C6 SAFETY REPAIR
## Convert measured Outcome C into an honest production contract before P009B

**RECOMMENDED MODEL:** Claude Fable
**EFFORT:** High / maximum practical reasoning
**MODEL SWITCH:** `/model` → Fable
**VERIFY:** `/status`

# 0. ENTRY TRUTH — BINDING

Measured Phase-B result:
`MEASURED — TIER-0 NOT SAFELY SEPARABLE`

Evidence:
- ~154 s physical evidence-build session
- 7,844 frames
- 89 shots
- 88 SHOTEV transition rows
- conservative labels: 10 SAME_ITEM_INTERNAL_CUT, 3 NEW_ITEM, 7 launch-noise excluded, 68 unlabeled excluded
- current cheap Tier-0 features materially overlap
- previous real device runs: ~73 shots → 73/72 items
- no policy retuned to force counts
- evidence-build logging caused THERMAL_SERIOUS due I/O and must remain audit/debug-only
- privacy remained derived-log only
- score/glyph OFF
- P009B not started

Evidence limitation:
Do NOT claim cheap Tier-0 grouping is impossible in principle. The supported claim is:
the CURRENT feature set/resolution is not sufficiently and safely separable for production full item grouping.

Permanent capability decision:
- `EXTENSION_FAST_TIER0` = shot segmentation + provisional item identity
- full item grouping = Tier-1 multimodal brain or future official shared capability
- no more forced item-count matching in Tier-0

# 1. EVIDENCE LOCK

Preserve and SHA-lock:
- entire P000→P009A history
- independent audit
- auditor C6 failing probe
- Phase-B evidence log + distributions
- Outcome C decision
- prior frozen policies

Create `docs/evals/P009A_PHASE_C_EVIDENCE_LOCK.md`.

# 2. FIX DWELL PROPAGATION BUG

Measured defect: `prevDwellMs = 0` on 100% of SHOTEV rows.

Fix prior-shot end-time propagation only.
Requirements:
- use monotonic presentation timestamps
- first shot dwell = nil/unknown
- no negative dwell
- cadence/jitter/drop safe
- session/app-switch safe
- no threshold retune

Tests:
- 60/30/20 fps
- jitter/drop
- first shot
- long dwell
- rapid cuts
- session boundary

# 3. RECLASSIFY TIER-0 SEMANTICS

Create `ExtensionProvisionalIdentityV1`.

Tier-0 may output:
- ShotID
- provisional ContentItemID
- CANDIDATE_SAME_ITEM
- CANDIDATE_NEW_ITEM
- AMBIGUOUS
- strongNew flags
- compact derived continuity evidence
- provenance/profile/version

Tier-0 MUST NOT claim:
- authoritative feed-item grouping
- exact item count
- full ContentDNA identity
- safe positive-state inheritance across ambiguous identity

# 4. REWRITE TIER-0 ACCEPTANCE GATES

Remove Tier-0 item-count ratio as a release gate.

New Tier-0 gates:
- shot segmentation has no burst/pathological spam
- pan behavior bounded
- resource/privacy/session pass
- strongNew veto works
- ambiguous identity never inherits safe/positive admission
- stale identity invalidates
- provisional IDs are versioned
- full grouping is not claimed

Item count becomes diagnostic only.

# 5. RESOLVE AUDITOR C6 BRIGHT-TO-BRIGHT FALSE MERGE

C6 is a critical open safety blocker.

Do not delete/weaken/relabel/exclude the failing test.

Root-cause:
- exact evidence path
- merge anchor
- missing strongNew/conflict
- stale/cache/coalescer contribution
- correlated features

Implement the smallest principled safety fix.

Forbidden:
- tuning to device item count
- hardcoding C6 fixture constants
- app-specific geometry
- weakening strongNew

Acceptance:
- original C6 passes
- all previous safety tests pass
- no new false merges in variants

# 6. ADD C6 FAMILY ADVERSARIAL TESTS

Add:
- bright→bright different items
- dark→dark different items
- same dominant color different items
- same template different items
- same layout different semantic item
- rapid similar items
- persistent chrome + content replacement
- similar crossfade
- low-motion replacement
- high-motion replacement

Expected: NEW or AMBIGUOUS; never unsafe SAME without independent continuity.

# 7. EVIDENCE INDEPENDENCE GUARD

Create `EvidenceIndependenceGuardV1`.

Define evidence families:
- TEMPORAL/INTERACTION
- VISUAL_STRUCTURE
- CONTENT/SEMANTIC
- SURFACE/UI
- CACHE/PRIOR

Correlated theme/hist/regional gross-luma channels must not count as 3 independent proofs.

A confirmed SAME requires:
- minimum independent-family support, OR
- one explicitly high-trust anchor with characterized failure mode,
- and no strongNew/conflict.

# 8. TIER-1 HANDOFF CONTRACT

Create `Tier1IdentityHandoffV1`.

Fields:
- session/observation ID
- ShotID
- provisional item ID
- transition type
- temporal evidence
- compact visual evidence
- ambiguity reason
- strongNew flags
- prior relation
- resource state
- capability profile
- model/policy versions

No raw private media persistence in the handoff record.

# 9. CONTENTDNA SAFETY UNDER PROVISIONAL IDENTITY

Rules:
- no durable item-level ContentDNA finalization while identity unresolved
- allow SHOT_ONLY evidence record
- Tier-1 merge can consolidate later
- Tier-1 split invalidates/rebuilds
- no positive/safe-state inheritance across unresolved identity
- strong risk evidence may escalate immediately

Add tests for merge/split/risk/stale/cache/session reset.

# 10. RELEASE EVIDENCE BUILD OFF

Phase-B evidence build caused THERMAL_SERIOUS due high-volume writes.

Requirements:
- `GEN8_EVIDENCE_BUILD` OFF in release
- no per-frame MOTION/SHOTEV file logging in release
- audit/debug paths excluded from release behavior
- bounded signposts only if safe
- add `testReleaseDisablesEvidenceLogging`

# 11. RESOURCE + PRIVACY RECHECK

Measure separately:
- evidence-build overhead
- release-equivalent overhead
- shot-commit identity latency
- memory
- thermal
- file I/O
- graph/cache bounds

Privacy:
- no raw persistence
- no network path
- no raw handoff storage
- derived identity bounded
- release evidence logging disabled

# 12. CAPABILITY MATRIX — BINDING

`EXTENSION_FAST_TIER0`
- user-consented observation
- shot segmentation
- provisional item identity
- strongNew / ambiguity safety
- compact derived evidence
- NO full item grouping claim

`APP_FULL_TIER1`
- target: richer multimodal grouping + ContentDNA finalization

`FUTURE_SHARED_TIER1`
- blocked until official capability exists

# 13. P009A CLOSEOUT PASS DEFINITION

PASS requires:
- dwell bug fixed
- Tier-0 capability reclassified
- old item-ratio gate removed
- C6 + adversarial family pass
- no positive-state inheritance from provisional identity
- Tier1IdentityHandoffV1 exists
- ContentDNA provisional rules tested
- release evidence logging disabled
- resource/privacy regressions absent
- all tests green
- independent audit passes

This closes the IDENTITY FOUNDATION, not full semantic grouping.

# 14. SCORE / GLYPH

Keep OFF:
- numeric score
- green tick
- semantic glyph
- P008B motion

UNKNOWN remains fallback.

Do not start P009B before independent Phase-C audit PASS.

# 15. REQUIRED DOCS

Create/update:
- `docs/evals/P009A_PHASE_C_EVIDENCE_LOCK.md`
- `docs/architecture/P009A_PHASE_C_TIER0_CAPABILITY_CONTRACT.md`
- `docs/intelligence/P009A_PHASE_C_PROVISIONAL_IDENTITY.md`
- `docs/intelligence/P009A_PHASE_C_EVIDENCE_INDEPENDENCE_GUARD.md`
- `docs/intelligence/P009A_PHASE_C_TIER1_HANDOFF.md`
- `docs/evals/P009A_PHASE_C_C6_ROOT_CAUSE.md`
- `docs/evals/P009A_PHASE_C_C6_ADVERSARIAL_RESULTS.md`
- `docs/evals/P009A_PHASE_C_DWELL_FIX_RESULTS.md`
- `docs/evals/P009A_PHASE_C_RELEASE_RESOURCE_RESULTS.md`
- `docs/privacy/P009A_PHASE_C_PRIVACY_RECHECK.md`
- `docs/implementation/P009A_PHASE_C_IMPLEMENTATION_EVIDENCE.md`

Update capability matrix, traceability, decision ledger, FMEA, policy registry, project canon.

# 16. FINAL REPORT

Return:
## 1. ACTIVE MODEL / EFFORT
## 2. ENTRY EVIDENCE LOCK
## 3. DWELL BUG ROOT CAUSE + FIX
## 4. TIER-0 CAPABILITY RECLASSIFICATION
## 5. ACCEPTANCE GATE REWRITE
## 6. C6 ROOT CAUSE
## 7. C6 SAFETY FIX
## 8. C6 ADVERSARIAL FAMILY
## 9. EVIDENCE INDEPENDENCE GUARD
## 10. PROVISIONAL IDENTITY CONTRACT
## 11. TIER-1 HANDOFF
## 12. CONTENTDNA PROVISIONAL RULES
## 13. RELEASE EVIDENCE-LOGGING STATUS
## 14. RESOURCE RESULTS
## 15. PRIVACY RESULTS
## 16. CAPABILITY MATRIX
## 17. TESTS
## 18. KNOWN LIMITATIONS
## 19. FILES CHANGED
## 20. STATUS

Status exactly one:
`READY FOR INDEPENDENT PHASE-C AUDIT`
`FIX REQUIRED`
`BLOCKED`

Then STOP.
Do not start P009B.
