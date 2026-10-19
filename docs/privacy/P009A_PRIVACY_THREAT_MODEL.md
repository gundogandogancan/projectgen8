# P009A — Privacy Threat Model (identity brain + flywheel)

Status: source-level `VERIFIED`; device-container recheck **PASS** on the P009A item-group run (2026-10-19):
container held exactly ONE derived `.log` (222,622 bytes); media sweep (mp4/mov/png/jpg/heic/wav/m4a/caf/yuv/raw) =
**0 files**; 73/73 decisions `score=UNKNOWN`; no raw frame/audio/video, no OCR transcript, no upload
(`cloud=false`). `ZERO_VERIFIED_ON_DEVICE` — 4th consecutive device run with a clean container.

## Data classes (§23)
| class | policy |
|-------|--------|
| Raw private observation | ephemeral by default; no disk, no cloud, no global training ingestion by default (unchanged from R1–R4; device-verified 3×) |
| Derived identity (signatures, shot/item descriptors, DNA) | minimized reconstructability (region hashes/projections/fingerprints); classified retention; versioned provenance; safe eviction (`invalidate`, cache FIFO, graph compaction) |
| Learning telemetry | SEPARATE from content cache (`LearningSignalBusV1` vs `ContentIdentityCacheV1`); LOCAL/GLOBAL scope separation; consent-gated (global w/o opt-in REJECTED, tested); bounded retention (`retentionDays`) |

## Threats → mitigations (§23)
| threat | mitigation |
|--------|------------|
| fingerprint leakage | identity keys are coarse quantized popcount digests; full signatures stay local; privacy class on every evidence edge |
| re-identification / correlation | IDs are session-scoped counters (no content encoded); `derivedLinkable` class exists to force bounded retention where correlation is possible |
| cache collision | verified against full signature; uncertainty degrades to RE-ANALYSIS, never a wrong identity reuse (`testCacheCollisionReanalysis`) |
| cross-identity admission leak | §7 structural rule: `safeAdmissionInheritance` only on confirmed same-item; ambiguous = provisional split (tested) |
| telemetry abuse | LearningSignalV1 has NO raw-media field by construction (Mirror-tested); aggregationEligible + consent class gates |
| child/family data | ChildAge stays a future contract; child age only parent-entered, never inferred from face/image (§24); precedence ladder preserved for ContentItem/DNA consumers |
| model poisoning | §17 pipeline: offline eval → shadow → canary → calibration → gate → signed release; no self-modification; packs checksum+signature verified, QUARANTINED on failure |
| rollback abuse | rollback only to the manifest-declared version; single-step; state-machine tested |

## Extension / process reality (§22)
Broadcast extension keeps EXTENSION-LOCAL fast identity only (Tier 0, derived continuity). No hidden IPC is invented;
App Group limits remain real (free team). Full multimodal identity runs only where ephemeral raw observation is
legitimately in-process (app) or later with official shared-container capability. Both tiers share semantic contracts.

## P009B addendum — expert-mesh threat surfaces (2026-10-19)

| threat | vector | control | evidence |
|---|---|---|---|
| Raw media reaches semantic layer | expert inputs | ExpertInputV2 carries derived strings/labels/floats only; GuardianCore has no AVFoundation/Vision imports and zero networking | testEvidencePrivacyDerivedOnly; module structure |
| Private text leaks via evidence labels | OCR/transcript copied into labels | labels are category strings; raw text never copied (asserted) | testEvidencePrivacyDerivedOnly |
| Reconstruction from DNA candidate | durable semantic store | label GROUPS + coverage/uncertainty only; privacyClass derivedNonReconstructive; TTL-stamped | testUnderstandingStateAndDNAMintRules |
| Debug HUD exposes private content | developer panel | #if DEBUG whole-file + Developer Mode gate; displays statuses/counters/labels, no raw dumps; no production dependency | GuardianIntelligenceHUD.swift |
| Cross-session identity bleed | stale handoffs | stale-session quarantine + generation stale firewall | testHandoffSanitization; testStaleResultCannotCrossIdentity |
| Person profiling | vision/speech experts | scene-level labels only; no face/voice identity, no demographics (structurally absent) | ExpertArmsV1.swift review |
