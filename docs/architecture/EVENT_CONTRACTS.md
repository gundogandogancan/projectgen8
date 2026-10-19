# EVENT CONTRACTS

**Doc status:** `CANONICAL` (schemas, no impl) · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** PROMPT 000A §7; Bible §57(P000), §93. Every event defines: `schema · version · producer · consumers · PII class · retention · idempotency · failure behavior`. **No event without consumers/traceability** (§93).

## Conventions
Versioned (`vN`); correlation/trace id on every event; **no raw private content in any event payload** (features/ids only); PII class ∈ {none, personal, sensitive}; idempotency key where the event drives a side effect.

## Canonical events (PROMPT 000A §7 + Bible §93)
| Event | Producer → Consumers | PII | Idempotent | Failure behavior |
|---|---|---|---|---|
| `CandidateDiscovered` v1 | perception → orchestrator | sensitive | key=candidateId | drop → UNKNOWN |
| `ContentIdentityResolved` v1 | identity → DNA/score/temporal | mixed | key=contentId+version | low-id ⇒ no high-impact action |
| `ContentDNAResolved` v1 | content-intelligence → score/temporal | non-personal | key=reuseKey | miss ⇒ fresh path |
| `FastPreflightCompleted` v1 | on-device intel → admission | sensitive | key=observationId | timeout ⇒ first-frame/UNKNOWN |
| `AdmissionDecisionReady` v1 | admission → presentation | sensitive | key=decisionId | none ⇒ grey `?` |
| `TemporalSegmentFlagged` v1 | temporal → presentation/skip | sensitive | key=segmentId | misalign ⇒ WARN/ASK |
| `GuardianCoverageChanged` v1 | runtime → presentation | internal | key=sessionId | degrade ⇒ truthful coverage |
| `GuardianWarningIssued` v1 | admission → presentation | sensitive | key=warningId | — |
| `GuardianOverride` v1 | user → learning/calibration | personal | key=overrideId | logged as evidence |
| `AutoSkipExecuted` v1 | temporal → outcome | sensitive | key=skipId | require identity+alignment gate |
| `DeviceTrusted` v1 | device-trust → entitlement | sensitive | key=deviceId | — |
| `FamilyRelationshipActivated` v1 | family → policy | sensitive | key=relationshipId | revoke ends relationship |
| `EntitlementChanged` v1 | entitlement → runtime | sensitive | key=accountId+ts | grace on failure |
| `ModelActivated` v1 | model-registry → router | internal | key=modelId+version | shadow→canary gate |
| `ModelRolledBack` v1 | model-registry → router | internal | key=modelId+version | QUARANTINE→FALLBACK |
| `PublishJobCreated` v1 | publishing → workers | sensitive | key=jobId (idempotent) | dup prevention |
| `PublishReconciled` v1 | publishing → UI | sensitive | key=jobId | reconcile before retry |

Plus Bible §93 analytics/lifecycle events (`observation.created`, `content.boundary.detected`, `score.*`, `learning.verified`, `outcome.recorded`, `calibration.drift.detected`, `consent.revoked`, `sensitive.surface.detected`) — same contract rules.

## Phase-0 status
Schemas/contract rules only; no event bus implemented. Materialized in `packages/contracts` later.
