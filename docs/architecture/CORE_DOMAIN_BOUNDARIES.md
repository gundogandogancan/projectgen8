# CORE DOMAIN BOUNDARIES

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §56, §92, §94; Prompt 000 §56. Data-model principle: **domain ownership first, no giant schema up front.**

Each domain owns its entities, lifecycle, retention, encryption class, delete/export behavior, versioning, and access patterns. Domains communicate via versioned contracts/events (`API_EVENT` candidates: Bible §93, §57 P000), never shared mutable tables.

| Domain | Owns (entities) | Key contracts/events | Privacy class | Bible |
|---|---|---|---|---|
| **Identity & Account** | User, Workspace, ConnectedPlatformAccount | auth tokens (vaulted) | sensitive | §92, §325 |
| **Device & Trust** | Device, TrustedDevice, DeviceKey | DeviceTrusted | sensitive | §465 |
| **Entitlement** | SubscriptionEntitlement, Plan, Trial | EntitlementChanged | sensitive | §305, §464 |
| **Household** | HouseholdAnchor, TravelMode, SharingRiskState | household signals | sensitive | §468 |
| **Family** | FamilyWorkspace, FamilyRole, FamilyRelationship, FamilyConsent, FamilyVisibilityPolicy, SharedGoal | FamilyInviteCreated, FamilyRelationshipActivated | sensitive | §73–§76, §453 |
| **Perception** | DigitalObservation, ObservedContentSession | ContentObserved, CandidateDiscovered | sensitive (ephemeral raw) | §17–§19 |
| **Content Identity** | ContentIdentity, ContentObject | ContentIdentityResolved | mixed | §20, §498 |
| **ContentDNA** | ContentDNA, EnergyProfile, features | ContentDNAResolved | non-personal (global), else DENY | §621, §85 |
| **TemporalGraph** | TemporalContentGraph, TemporalSegment | TemporalSegmentFlagged | sensitive | §377 |
| **Cognition** | ContentCognition, Topic, Message, Intent, Narrative, Influence, Symbolic | content.analysis.* | sensitive | §21–§36 |
| **Truth/Evidence** | Claim, EvidenceNode, Source, SourceLineage, DataProvenance | claim.extracted, evidence.updated | mixed | §37–§39 |
| **Protection** | WholePersonImpactVector, PersonalProtectionProfile, ProtectionStatus | protection.decision | sensitive | §136–§148 |
| **Semantic Shield** | SemanticShieldRule, ExclusionMemory, EntityGraph | shield.match | personal | §161–§166 |
| **Personal Algorithm / Growth Twin** | PersonalAlgorithmProfile, PersonalGrowthTwin, SkillState, KnowledgeState, AttentionBudget, ExplorationPolicy, UserGoal | twin.updated | personal | §40–§48 |
| **Score** | ScoreContract, ScoreComponent, ContentAssessment, Expected/VerifiedImpact, ScoreExplanation, Warning, FilterDecision | score.preliminary/final.generated, user.score.override | internal | §49–§52 |
| **Admission** | AdmissionDecision, GuardMode | AdmissionDecisionReady, GuardianWarningIssued, AutoSkipExecuted | sensitive | §223–§243 |
| **Learning/Outcome** | LearningAssessment, LearningEvidence, ApplicationEvidence, OutcomeEvent | learning.verified, outcome.recorded | personal | §54–§56 |
| **Calibration/Evolution** | CalibrationReport, FailureCase, Challenger | calibration.drift.detected, model.challenger.created | internal | §66–§69 |
| **Model Registry** | ModelPack, Manifest, RouteDecision | ModelActivated, ModelRolledBack | internal | §35 P000, §212 |
| **Social (Creator)** | CreatorOutput, CanonicalSocialPost, PublishGroup, PublishJob, InboxItem, NetworkSnapshot, RelationshipEvidence | PublishJobCreated, PublishReconciled | sensitive | §319–§339 |
| **Privacy/Consent** | DataConsent, RetentionPolicy, DeletionRequest, AuditEvent | consent.revoked | sensitive | §71, §75 |
| **Capability** | PlatformCapabilityProfile, OEMQuirk, CertificationRecord | capability.changed | internal | §174, §528, §545 |

## Boundary rules
1. **No cross-domain table sharing.** Domains expose contracts/events only.
2. **Core domain packages are platform-free** — no SwiftUI/Android/UI/provider SDK imports (Prompt 000 §32).
3. **Observed vs inferred** fields are segregated in every perception/cognition entity (Bible §17, §4.3).
4. **Personal vs non-personal** separation: global ContentDNA is non-personal; personal scores recomputed locally (Bible §85, §270).
5. **Truth/Policy firewall:** truth/evidence, personal benefit, positive-exposure policy, spiritual lens, age/family policy are distinct planes that must not silently override each other (Bible §141, §426; Prompt 000 §8).
