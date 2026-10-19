# REQUIREMENTS TRACEABILITY MATRIX

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §128, §49(Prompt 000); Prompt 000 §49, §H.
Chain: `USER/PRODUCT REQ → SYSTEM REQ → ADR → CONTRACT → CODE → TEST → DEVICE/BENCHMARK EVIDENCE → RELEASE GATE`. At Phase 0, **code/test/evidence = `NOT_STARTED`** by definition (no product code). Broken chain ⇒ requirement not complete.

| Req | Bible refs | ADR | Contract/Doc | Agent/Skill | Code | Test | Evidence | Gate |
|---|---|---|---|---|---|---|---|---|
| ADM-001 Pre-exposure | §613–656,§223 | ADR-0005,ADR-0007 | CANONICAL_MASTER_SPEC §8 | admission-controller | NOT_STARTED | NOT_STARTED | NOT_STARTED | §650/§371 |
| ADM-002 Admission precedence | §176,§223,§224 | ADR-0007 | FAILURE_TAXONOMY; DECISION_LEDGER | admission-controller | NOT_STARTED | NOT_STARTED | NOT_STARTED | §520 |
| PER-001 Permitted source | §15,§17,§493 | ADR-0004 | SYSTEM_CONTEXT; CAPABILITY_MATRIX | content-cognition | NOT_STARTED | NOT_STARTED | NOT_STARTED | §116.4 |
| BND-001 Boundary | §19 | — | CORE_DOMAIN_BOUNDARIES | content-identity | NOT_STARTED | NOT_STARTED | NOT_STARTED | §116.5 |
| IDR-001 Identity I0–I4 | §20,§498,§550 | ADR-0001 | SCORE/Domain; skill content-identity-resolution | content-identity | NOT_STARTED | NOT_STARTED | NOT_STARTED | §371 |
| CDNA-001 ContentDNA | §621,§85,§348 | ADR-0001,ADR-0008 | DATA_CLASSIFICATION; CONTAINER | content-identity | NOT_STARTED | NOT_STARTED | NOT_STARTED | §371 |
| TMP-001 TemporalGraph | §377,§401,§632 | ADR-0005 | CANONICAL_MASTER_SPEC §8 | temporal-guardian | NOT_STARTED | NOT_STARTED | NOT_STARTED | §411/§651 |
| TMP-002 Skip safety | §386,§393,§551 | ADR-0006 | FAILURE_TAXONOMY; skill temporal-skip-safety | temporal-guardian | NOT_STARTED | NOT_STARTED | NOT_STARTED | §371 |
| COG-001 Cognition | §21,§22,§27 | — | CORE_DOMAIN_BOUNDARIES | content-cognition | NOT_STARTED | NOT_STARTED | NOT_STARTED | §116.7 |
| EVD-001 Evidence vs inference | §37,§39 | — | SCORE_CONTRACT_FRAMEWORK | claim-evidence | NOT_STARTED | NOT_STARTED | NOT_STARTED | §116.8 |
| SCO-001 ScoreContract/PBS | §50,§51,§629 | ADR-0004(score) | SCORE_CONTRACT_FRAMEWORK; PBS_v0.1 | score-fusion | NOT_STARTED | NOT_STARTED | NOT_STARTED | §116.11-13 |
| SCO-002 Why-this-score | §60,§116.14 | — | SCORE_CONTRACT_FRAMEWORK | score-fusion | NOT_STARTED | NOT_STARTED | NOT_STARTED | App G.10 |
| TWIN-001 Growth Twin | §40,§83 | — | CORE_DOMAIN_BOUNDARIES | personal-fit | NOT_STARTED | NOT_STARTED | NOT_STARTED | §116.9 |
| PAI-001 Personal Algorithm | §46,§47 | — | CORE_DOMAIN_BOUNDARIES | personal-fit | NOT_STARTED | NOT_STARTED | NOT_STARTED | §116.1-3 |
| PROT-001 Protection status | §136,§148,§176 | ADR-0007 | CANONICAL_MASTER_SPEC §5 | protection | NOT_STARTED | NOT_STARTED | NOT_STARTED | §158 |
| PROT-002 Semantic Shield | §162,§165,§356 | — | SKILL_REGISTRY semantic-shield-match | protection | NOT_STARTED | NOT_STARTED | NOT_STARTED | §371 |
| FAM-001 Family pairing | §451,§453,§454 | ADR-0009 | PRIVACY_MODEL; THREAT_MODEL | (family svc) | NOT_STARTED | NOT_STARTED | NOT_STARTED | §504 |
| CHD-001 Child/anti-coercion | §433,§455,§548 | ADR-0009 | PRIVACY_MODEL | (family svc) | NOT_STARTED | NOT_STARTED | NOT_STARTED | §448 |
| ENT-001 Entitlement/trial | §305,§464 | ADR-0010 | CONTAINER; COST_MODEL | (entitlement svc) | NOT_STARTED | NOT_STARTED | NOT_STARTED | §505 |
| HSH-001 Household trust | §468,§471 | ADR-0010 | PRIVACY_MODEL | (entitlement svc) | NOT_STARTED | NOT_STARTED | NOT_STARTED | §506 |
| PUB-001 Publish vertical | §326,§330,§334 | ADR-0011 | THREAT_MODEL; skill publish-reconcile | (publishing svc) | NOT_STARTED | NOT_STARTED | NOT_STARTED | §507 |
| AI-001 Model Router/rollback | §86,§188,§563 | ADR-0008 | AGENT_REGISTRY model-router | model-router | NOT_STARTED | NOT_STARTED | NOT_STARTED | §371 |
| PRI-001 Retention/deletion | §71,§72,§344 | ADR-0003(privacy) | PRIVACY_MODEL; skill sensitive-surface-guard | protection | NOT_STARTED | NOT_STARTED | NOT_STARTED | §515 |
| SEC-001 Security baseline | §99,§38(P000) | — | THREAT_MODEL | privacy-security-auditor | NOT_STARTED | NOT_STARTED | NOT_STARTED | §516 |
| DVT-001 Data rights | §348,§564 | ADR-0008 | DATA_CLASSIFICATION | (data-rights) | NOT_STARTED | NOT_STARTED | NOT_STARTED | §371 |
| REL-001 Offline/outage | §101,§553 | — | FAILURE_TAXONOMY | reliability | NOT_STARTED | NOT_STARTED | NOT_STARTED | §371 |
| OPS-001 Battery/thermal | §190,§509 | — | COST_MODEL; CERT_MATRIX | resource-governor | NOT_STARTED | NOT_STARTED | NOT_STARTED | §371 |
| COST-001 Cost report | §308,§518 | — | COST_MODEL | cost | NOT_STARTED | NOT_STARTED | NOT_STARTED | §371 |
| UX-001 Pure Bar | §596,§602 | ADR-0012 | GUARDIAN_VISUAL_CONSTITUTION | (presentation) | NOT_STARTED | NOT_STARTED | NOT_STARTED | §116.4 |
| ACC-001 Accessibility | §103,§559 | — | GUARDIAN_VISUAL_CONSTITUTION | (presentation) | NOT_STARTED | NOT_STARTED | NOT_STARTED | §42(P000) |
| VAL-001 Calibration/feedback | §69,§512 | — | EVALUATION_MASTER_PLAN | eval-redteam | NOT_STARTED | NOT_STARTED | NOT_STARTED | §116.15-16 |
| OPS-002 Device health (P0-B) | §183-218,§556 | — | DEVICE_RESOURCE_BUDGETS; DEVICE_NATIVE_RUNTIME | resource-governor | NOT_STARTED | NOT_STARTED | NOT_STARTED | §210/§371 |
| OPS-003 Observability | §102,§358 | — | OBSERVABILITY_SPEC | privacy-security-auditor | NOT_STARTED | NOT_STARTED | NOT_STARTED | §517 |
| UX-002 P0-Q UX gate | §107,§596-612 | ADR-0012 | DESIGN_SYSTEM_CONSTITUTION; SCREEN_STATE_INVENTORY | (presentation) | NOT_STARTED | NOT_STARTED | NOT_STARTED | PROMPT 000A §2 |
| AI-002 Model governance | §35P000,§68,§563 | ADR-0008 | MODEL_REGISTRY; INTELLIGENCE_TRAINING_AND_DISTILLATION_PLAN | model-router | NOT_STARTED | NOT_STARTED | NOT_STARTED | §524/§371 |
| VAL-002 Dataset/drift gov | §111,§269,§512 | — | DATASET_GOVERNANCE; CALIBRATION_PLAN; LEARNING_AND_DRIFT_PLAN | eval-redteam | NOT_STARTED | NOT_STARTED | NOT_STARTED | PROMPT 000A §7 |

**No orphan requirements** (every row maps to Bible refs + a contract doc). Matrix is updated as contracts/code/tests/evidence land in Prompt 001+.

## PROMPT 001 slice status (2026-10-18)
First real code landed in `packages/GuardianKit` (GuardianCore) + iOS app. Status legend for this slice: **CODE=slice** (real code exists), **TEST=unit-pass (37/0, sim/headless)**, **EVIDENCE=SIM_ONLY** (no device/Instruments yet), **GATE=NOT_MET** (device + calibration pending → not DONE per DoD).

| Req | P001 code | P001 test | Evidence | Note |
|---|---|---|---|---|
| ADM-001 pre-exposure | slice (pipeline+orchestrator, fixture) | S1–S3 pass | SIM_ONLY | fixture preload; device coverage pending |
| ADM-002 admission precedence | slice (deterministic, ADR-0007) | precedence tests pass | SIM_ONLY | reproducible |
| IDR-001 identity I0–I4 | slice (fixture resolver) | temporal/identity tests | SIM_ONLY | real perceptual hashing later |
| CDNA-001 local cache | slice (actor cache) | cache tests pass | SIM_ONLY | L1 only |
| COG-001 cognition | slice (HEURISTIC_V0) | score tests | SIM_ONLY | labelled heuristic, not AI |
| SCO-001/002 score + why | slice (deterministic formula) | score + S5 tests | SIM_ONLY | `?` on insufficient |
| PAI-001 personal algorithm | slice (editable profile) | admission tests | SIM_ONLY | onboarding UI |
| PROT-001/002 protection + shield | slice | shield/positive-exposure tests | SIM_ONLY | false-positive rule proven |
| TMP-001/002 temporal + skip safety | slice | temporal tests + S6–S8 | SIM_ONLY | wrong-version refused |
| UX-001/UX-002/ACC-001 Pure Bar | slice (SwiftUI) | app builds | SIM_ONLY | a11y labels, reduced motion |
| OPS-002/OPS-003 device health/obs | partial (Diagnostics + traces) | scheduler/idle tests | SIM_ONLY | Instruments energy pending |
| SHLD-001 multimodal personal shield | ShieldRuleV2 + ShieldEvaluatorV2 + matchers | ShieldV2Tests (12) + ShieldBridge (5) | SIM_ONLY | low/unknown never silent-hide; bounded index @1000 |
| SHLD-002 cross-modal + privacy | ShieldIntelligenceBridge (Vision/NL) | ShieldBridgeTests | SIM_ONLY | no face biometric / no voiceprint / raw discarded |
| GLY-001 Guardian glyph engine | GuardianGlyphEngine + Stabilizer + SurfaceState | GuardianGlyphTests (11) | SIM_ONLY | stale→UNKNOWN; medical-safe; no jitter |
| SHLD-003 unknown≠match semantics | ShieldMatchState split + ShieldActionControllerV2 abstain | ShieldV2Tests + P006BShieldCloseoutTests | SIM_ONLY | UNKNOWN/UNAVAILABLE never match/hold |
| SHLD-004 global admission / strict | GlobalAdmissionController | P006BShieldCloseoutTests | SIM_ONLY | strict-only HOLD; normal proceeds |
| SHLD-005 durable store + index | PersonalShieldStore + ShieldStoreManager + ShieldIndex | P006BShieldCloseoutTests + durability bench | SIM_ONLY | relaunch survives; reauthoring; no raw media |
| GLY-002 glyph firewall + ordering | primaryFamily + GlyphSurfaceController | GuardianGlyphTests + P006BShieldCloseoutTests | SIM_ONLY | protection outranks content; no stale positive |
| SHLD-006 functional visual durability | VisualSignature + VisualSignatureEngine + durable matcher | P006CVisualDurabilityTests | SIM_ONLY | matches after true relaunch from persisted signature; no raw image |
| SHLD-007 functional states + startup truth | ShieldRuleFunctionalState + off-main loadAndRebuild | P006CCoreTests + P006CVisualDurabilityTests | SIM_ONLY | non-functional never active; reindex-per-launch stated truthfully |
| SHLD-008 audio durability truth | AudioReferenceDurability.classify | P006CCoreTests | SIM_ONLY | sound-class durable; audio/music metadata-only/unavailable |
| NAT-001 native surface safety | NativeSurfaceState + LiveActivityUpdatePolicy + adapters | P007CoreTests | SIM_ONLY | lock-safe; order/stale/debounce; device run PENDING |
| SPCH-001 TR/EN speech V3 | SpeechTranscriberV3 (on-device) | P007SpeechAudioTests | SIM_ONLY | honest BLOCKED_* in lab; no cloud; device transcripts PENDING |
| H1-001 sensitive-visual safety | SensitiveVisualHead (UNAVAILABLE) | P007H1Tests | SIM_ONLY | Outcome B blocked; shield≠safety cross-use prevented |
| LAT-001 full-pipeline admission | AdmissionTimeline + benchmark | P007FullPipelineBenchmarkTests | SIM_ONLY | fast excludes deep; LAB only; device NOT_MEASURED |
| DEV-001 capability routing + lifecycle | DeviceCapabilityProfile + ModelLifecycleV2 | P007CoreTests | SIM_ONLY | runtime-routed; warm reuse; no cold-load per item |
| SOAK-001 leak/soak baseline | TaskLedger + soak | P007SoakTests | SIM_ONLY | drains to baseline; device energy soak NOT_MEASURED |

| NAT-002 real widget extension | GuardianControlExtension target (ControlWidget+ActivityConfiguration) | xcodebuild extension + scheme BUILD SUCCEEDED | SIM_ONLY | COMPILED_NOT_DEVICE_VERIFIED; no signing change |
| LAT-002 real measured pipeline | P007ARealPipelineBenchmarkTests (actual OCR/video/audio/speech/shield) | GuardianMediaTests | SIM_ONLY | measured≠modeled; per-route; real OCR ~218ms |

No requirement is marked DONE; all remain pre-gate (device evidence + calibration required). R1 current; R2 blocked on signing.

| DEV-010 signed device install | user-approved signing 47XQMQZLF6 / com.gen8.guardian.dev | devicectl install+launch; pids 7138/7139 | DEVICE_VERIFIED | app+extension run on iPhone 14 Pro Max iOS 26.6 |
| DEV-011 app group capability | entitlement probe | provisioning FAILED (free team + PLA) | DEVICE_VERIFIED_NEGATIVE | needs paid program; reverted |
| DEV-012 device behavioral proofs | Control Center / Live Activity / benchmark / energy / soak | NOT captured | PENDING | require manual device op / on-device test target |

| MMU-001 multimodal understanding | MultimodalContentUnderstandingV1 + evidence graph | P008CoreTests + P008RealEvidenceTests | SIM_ONLY | provenance; char≠risk≠suitability; real OCR/audio |
| SCR-001 suitability score contract | PersonalSuitabilityScoreV1 + SuitabilityFusionV1 | P008CoreTests | SIM_ONLY | score≠confidence; UNKNOWN gate; weights UNCALIBRATED |
| BND-002 content boundary v2 | ContentBoundaryDetectorV2 + benchmark | P008CoreTests | SIM_ONLY | motion≠new item; false/missed bounded |
| CAL-001 calibration | CalibrationMetrics + eval dataset contract | P008CoreTests | SIM_ONLY | metrics exist; data UNAVAILABLE_INSUFFICIENT_DATA |

| RUN-001 automatic guardian runtime | GuardianRuntimeManager + session state machine + capability truth | P008ACoreTests | SIM_ONLY | zero-touch where permitted; iOS one-tap/session; never hidden |
| CAL-002 calibration pilot | CalibrationPilotRunner (held-out) | P008ACoreTests | SIM_ONLY | LAB_CALIBRATED_LIMITED; false-safe 0.50 → UNKNOWN kept |
| TMP-003 temporal understanding v1 | TemporalUnderstandingEngineV1 | P008ACoreTests | SIM_ONLY | real VIDEO→SCENE→SHOT hierarchy |
| VIS-001 visual semantic baseline | VisualSemanticBaselineV1 (Apple Vision) | P008AVisualBaselineTests | SIM_ONLY | no external VLM; provenance |

| BND-003 boundary engine wired to extension | ContentBoundaryEngineV2 (shared) in SampleHandler | P008AR1BoundaryTests + device build | SIM+DEVICE_BUILD | motion suppressed; swipes kept; policy versioned; device re-run pending |
| RES-001 extension resource instrumentation | mach task_info + signposts + schema V2 | build + procedure | PENDING_DEVICE | CPU/energy via xctrace pending user broadcast |

| BND-004 adaptive boundary v3 generalization | ContentBoundaryPolicyV3 + BoundaryEvidenceAccumulatorV3 + owned TUNE/HELD-OUT harness | P008AR2BoundaryV3Tests (253 total, 0 fail) | LAB_HELDOUT_ACCEPTED | held-out P=1.000 R=0.917 F1=0.957 dup=0.000; tuned on seed:0 only, no leakage |
| BND-005 boundary v3 fresh device validation | SampleHandler frozen V3 on iPhone15,3 iOS 26.6 | P008A_R2_AFTER_crossapp_device_v3.log (SHA e0f23284…) | DEVICE_VERIFIED_NEGATIVE | fresh untouched run: 477 committed vs ~20 (ratio ≈23.9) → over-detection; resource/privacy/UNKNOWN PASS; §17 no-retune; FIX REQUIRED |

| BND-006 motion-normalized segmentation v4 | ContentSegmenterV4 + DeviceMotionProfileV1 + realistic fixtures (TUNE/HELDOUT/STRESS) | P008AR3SegmenterV4Tests (267 total, 0 fail) | LAB_HELDOUT_ACCEPTED | held-out P=1.000 R=0.889 F1=0.941 dup=0 (zero false segments); stress 0 false on extreme/long high-motion, maxRun 0; recall misses only ambiguous high-motion cut (error budget §28); tuned on seed:0 only |
| BND-007 segmenter v4 fresh device validation | SampleHandler frozen V4 on iPhone15,3 iOS 26.6 | P008A_R3_AFTER_crossapp_device_v4.log (SHA f63c8de3…) | DEVICE_VERIFIED_NEGATIVE | fresh untouched run: 73 vs ~20 (ratio 3.65) over-detect; resource PASS (p95 2.86ms, 30.2MB, nominal), privacy PASS (0 media), UNKNOWN 73/73, session continuity PASS; §27 no-retune; FIX REQUIRED |

| BND-008 device-calibrated segmentation v5 | ContentSegmenterV5 (time-based + TemporalSwipeGateV1 + pan-vs-swipe + regionalReplacementRatio) + DeviceMotionProfileV2 + cadence-aware fixtures | P008AR4SegmenterV5Tests (281 total, 0 fail) | LAB_HELDOUT_ACCEPTED | held-out P=1.000 R=0.882 F1=0.938 dup=0; cadence-invariant ≤7%; stress 0 false on sustained-motion/pan/overlay; recall misses only high-motion cut + sub-dwell rapid swipe (error budget §23); tuned on seed:0 only |
| BND-009 segmenter v5 fresh device validation | SampleHandler frozen V5 on iPhone15,3 iOS 26.6 | P008A_R4_AFTER_crossapp_device_v5.log (SHA 6626b5c1…) | DEVICE_VERIFIED_NEGATIVE | fresh run: 57 vs ~20 (ratio 2.85); swipe over-fire FIXED (2/57), panning 0 false, no spam, candidate→commit 0.087; resource/privacy/session PASS; residual = internal shot cuts (shot≠item) → P009 content-identity grouping; §22 no-retune; FIX REQUIRED |

| IDN-001 hierarchical identity brain (shot→scene→item→DNA) | ShotSegmenterV5 + HierarchicalTemporalGraphV1 + ContentIdentityEvidenceGraphV1 + ContentItemGroupingEngineV1 + ContentDNAItemV1 + ContentIdentityCacheV1 | P009AHierarchicalBrainTests (308 total, 0 fail) | LAB_HELDOUT_ACCEPTED | §20 gates ALL PASS: newP 1.000 / newR 0.944 / F1 0.971 / mergeP 1.000 / xMerge 0.0000; montage no-explode, rapid no-collapse; tuned on seed:0 only |
| IDN-002 item grouping device validation (Tier 0) | SampleHandler frozen grouping on iPhone15,3 iOS 26.6 | P009A_AFTER_crossapp_device_itemgroup.log (SHA 7a13fcf0…) | DEVICE_VERIFIED_NEGATIVE | shots=73 items=73 ratio 3.65: Tier-0 merge ceiling 0.49 < threshold 0.50 (structural) + APP_FULL-only lab gate (profile gap, owned); 0 false merges (fails SAFE); resource/privacy/session/UNKNOWN PASS; thermal fair; no-retune; FIX REQUIRED |
| OCT-001 octopus meta-brain skeleton + pack/learning/evolution contracts | GuardianMetaBrainV1, ExpertRegistryV1, EvidenceBusV1, ProvenanceLedgerV1, ResourceGovernorV1, IntelligencePackManifest/Lifecycle, LearningSignalV1/Bus, EvolutionCandidateV1 | P009A tests (verify/rollback/evict/consent/order/dedupe) | CONTRACTS_TESTED | skeleton only; no self-improving claim (evidence classes honest); base shell 18MB Debug / 0 model assets |

| IDN-003 profile-aware Tier-0 grouping transfer | IdentityEvidenceProfileV1 + ProfileAwareItemGroupingPolicyV2 + EngineV2 + Tier-0 evidence (projection/histogram/cadence/regional) + DeferredItemCoalescerV1 | P009AR1Tier0Tests (323 total, 0 fail) | LAB_ALL_GATES_PASS | T0 heldout newP 1.000/newRexp 1.000/mergeP 1.000/xM 0.0000/amb 0.133; stress montage 23/23 rapid 7/7; device-like ratio 1.00 0 xM 43% avoided; T1 regression clean; tuned on T0 TUNE only |
| IDN-004 V2 Tier-0 fresh device validation | SampleHandler frozen V2-Tier0 on iPhone15,3 iOS 26.6 | P009A_R1_AFTER_crossapp_device_tier0.log (SHA 2e410a0a…) | DEVICE_VERIFIED_NEGATIVE | shots=73 items=72 ratio 3.6, 1 SAME, 0 coalesce: real cross-cut continuity absent at Tier-0 feature resolutions (S p50 0.21); evidence-realism failure (fixtures encoded unmeasured assumption); 0 false merges, thermal nominal 73/73, privacy/session PASS; no-retune; FIX REQUIRED |

| IDN-005 measured Tier-0 evidence (B1 closed) | GroupingChannelTelemetryV1 + SHOTEV evidence logging; scripted device session | P009A_R2_MEASURED_tier0_evidence.log (SHA 09f28bee…, git-anchored) + P009A_R2_MEASURED_TIER0_RESULTS.md | DEVICE_MEASURED | OUTCOME C: current Tier-0 channels not safely separable (all overlap; proj one-sided 14/88); dwell-propagation defect found; capability truth declared (extension = shot + provisional identity; full grouping = Tier-1); no tuning performed |
