# R2 — REAL VISUAL GUARDIAN: Live Photo Shield + Cross-App Intelligence + Dynamic Island Truth

Base: branch `product/device-evidence-slice`, HEAD `e11e1b3` (R1). This note is the add-only progress record for R2.
Tests: GuardianMediaTests baseline 248 → **271, 0 failures** (swift test). App/extension Xcode build:
**BUILD_UNVERIFIED_BY_AGENT** (xcodebuild DENIED in sandbox — pbxproj registered by hand per the R1-learned rules).

## FIX (§A) — truth projection independent sources
- Heartbeat (`GuardianObservationHeartbeatV1`) gained two INDEPENDENT fields: `decisionEpochSeconds` (the decision's
  OWN timestamp) and `currentItemIdentityRevision` (latest observed item, separate from the decision's item). Tolerant
  decode keeps legacy snapshots working.
- Extension (`SampleHandler`) now tracks + publishes `lastDecisionEpoch`, `lastDecisionItemRevision`,
  `lastObservedItemRevision` as distinct facts; cleared on paused/resume/policy-reload edges.
- App (`GuardianLabModel.realityProjection`): `osCaptureStarted` now comes from the extension's `broadcasting`
  lifecycle fact (not only freshness); `decisionFresh` comes from the decision's OWN TTL (`decisionOwnFresh`), so a
  fresh heartbeat can NO LONGER refresh an old decision; current-vs-decision item divergence → STALE_ITEM.
- Tests: `GuardianRealityProjectionTests` +3 independent-source rules; `GuardianObservationHeartbeatTests` +2.

## BUILD (§B) + G-fix — live photo shield on the real capture path
- New `PhotoShieldLumaMatcherV1` (GuardianMedia, GuardianCore-only — NOT GuardianIntelligence, to keep the extension
  lean): builds a P006C signature from an in-place luma grid (no CGImage decode), whole-frame hint first then a BOUNDED
  center+content ROI escalation. Precision-first: only HIGH/EXACT is actionable; LOW/MEDIUM = evidence-only. Full
  provenance (rule id, ROI, hamming, item revision, policy revision, session, timestamp). §B5 stale firewall.
- `SampleHandler` runs the photo pass ONCE per fresh item (inside `mustEvaluate`), skipped under thermal serious/
  critical, ROI escalation only on nominal thermal, newest-item-wins. A photo match escalates the surface to
  SHIELD_MATCH with the DISTINCT `personalPhotoMatchWarnOnly` reason (§C — visual match ≠ wellbeing claim). Session
  cost summary emitted (`PHOTO_SHIELD_SUMMARY`).
- §G: `PersonalPhotoShieldV1.ruleID` now delegates to `PhotoShieldLumaMatcherV1.stableRuleID` (FNV-1a over label+epoch,
  process-stable) replacing `abs(label.hashValue)` (randomized per process — a real cross-process store bug). Legacy
  `photo-<n>-<epoch>` ids still load/match.

## INTELLIGENCE (§C/§E) — what the matcher can and cannot distinguish
- CAN (synthetic, DEVICE_UNVERIFIED): full-screen reference (same pipeline → actionable); reference embedded in a
  social-UI composite (recovered via content/center ROI); different resolution; deleted reference no longer matches;
  policy change changes the match set; 10-item rapid sequence with NO stale carryover; unrelated/flat frames never
  actionable; corrupt signature skipped not fabricated.
- HONEST FINDING: a cross-path identical reference (CGImage ingest vs live luma) is a REAL match but NOT guaranteed
  near-exact (two downsamplers differ → MEDIUM/LOW) — precision-first does NOT escalate it. Semantic identity
  (who/what the image depicts) remains UNKNOWN in V1 — a perceptual match is a VISUAL match only.

## ISLAND (§D) — explicit three-state update chain
- New `GuardianIslandUpdateChainV1` (GuardianMedia): three operating states (appForeground /
  appSuspendedOtherForeground / captureEnded), three SEPARATE evidence fields (APP GROUP WRITE ≠ ACTIVITYKIT UPDATE ≠
  ISLAND PRESENTED). Suspended-app write that cannot reach ActivityKit → `WRITTEN_NOT_UPDATED` + `blockedBySuspension`
  (the known gap, reported not hidden). Presentation ceiling stays DEVICE_UNVERIFIED (no public visibility API).
- Tests: `GuardianIslandUpdateChainTests` (7).

## APPLE (§D2)
- `docs/progress/APPLE_CAPTURE_STRATEGY_R2.md`: ReplayKit (keep, shipping, VERIFIED) vs ScreenCaptureKit-on-iOS
  (RESEARCH, availability/min-OS/API all [UNVERIFIED] offline). ScreenCaptureKit prototype = NOT_DONE (would require
  inventing API signatures while network-sandboxed — refused per CLAUDE.md §3).

## RESOURCE (§B6/§F)
- Photo shield bounded per ITEM (never per frame), ≤3 ROIs, whole-frame-first early-out, ≤128px luma sampling, no
  second decode, skipped under thermal pressure. Derived-signature-only (no raw frame/crop persisted); deletion prunes
  features (tested). No raw signature bytes in logs. All latency/count numbers are DEVICE_UNVERIFIED (synthetic).

## PROOF / NOT_DONE / BLOCKED
- swift test --filter GuardianMediaTests → 271 passed, 0 failures. swift build → clean.
- NOT_DONE: ScreenCaptureKit prototype; device Island visibility proof; real social-app FP/FN; app-side wiring of
  `GuardianIslandUpdateChainV1` into the actual ActivityKit bridge (type + tests shipped; bridge consumption is next).
- BLOCKED: xcodebuild (sandbox) → app/extension compile UNVERIFIED by agent; suspended-app ActivityKit update path
  (needs push-token Live Activity verification); all Apple-API claims pending implementation-time doc verification.
