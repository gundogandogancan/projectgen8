# GEN8 — MASTER CONSTITUTION: REAL-SCORE OCTOPUS INTELLIGENCE SYSTEM
## Atom → System → Ecosystem
## Canonical architecture, philosophy, intelligence, scoring, privacy, UX, learning, evaluation and execution doctrine

**RECOMMENDED MODEL:** Claude Fable  
**EFFORT:** High / maximum practical reasoning  
**ROLE:** Chief systems architect + research engineer + implementation coordinator + evidence gatekeeper  
**IMPORTANT:** Do not execute this entire constitution blindly in one turn. Use the Execution DAG and gate each phase.  
**MODEL SWITCH:** `/model` → Fable  
**VERIFY:** `/status`

---

# 0. MISSION

Build Gen8 as a Universal Personal Content Guardian.

Gen8 should understand what the user is about to see/hear, estimate whether that content is suitable for the specific user/policy/context, and present the smallest trustworthy protective signal before or with minimal exposure.

Gen8 is NOT:
- an objective morality oracle,
- a metaphysical “frequency” detector,
- a fake all-seeing system,
- a hidden surveillance system,
- a universal content rating that ignores user context,
- a system that shows a number merely because a model produced one.

Gen8 IS:
- a private-by-default, capability-truthful Guardian layer,
- a multimodal perception + temporal identity + policy system,
- a personal suitability/admission engine,
- a thin application shell over a modular growing intelligence mesh,
- a continuously improving system whose production evolution is gated by evidence.

Canonical pipeline:

```text
OBSERVE
→ IDENTIFY
→ CACHE
→ FAST MULTIMODAL PERCEPTION
→ TEMPORAL / ITEM UNDERSTANDING
→ CONTENT DNA
→ PERSONAL / FAMILY POLICY
→ CALIBRATED ADMISSION
→ SCORE / COLOR / GLYPH
→ DEEPEN IF NEEDED
→ LEARN SAFELY
```

Permanent formula:

```text
ContentDNA + PersonalPolicy + Context
→ PersonalSuitability
```

---

# 1. PRODUCT PHILOSOPHY

## 1.1 NASA behind, one control in front

The implementation may be complex.
The user interface must be radically simple.

Normal user surface should feel like:
- Guardian ON/OFF
- Pure Bar
- semantic state
- optional calibrated score
- tiny glyph
- “Why?”
- My Shield
- Family controls when relevant

The user must not manage models, experts, prompts, queues, calibration, confidence matrices or debug concepts.

## 1.2 Truth over theater

Never display:
- fake precision,
- fake confidence,
- unsupported platform capability,
- “verified” without evidence,
- a positive glyph when evidence is stale,
- a numeric score outside the calibrated region.

## 1.3 Unknown is a product feature

`UNKNOWN` is a valid output.
A trustworthy guardian knows when it cannot safely decide.

## 1.4 Performance is product quality

A correct system that heats the phone, drains battery, grows uncontrollably, or blocks UI is not complete.

---

# 2. CANONICAL TEMPORAL HIERARCHY

```text
OBSERVATION
↓
FRAME / SAMPLE
↓
SHOT / PERSISTENT VISUAL SEGMENT
↓
SCENE / TEMPORAL WINDOW
↓
CONTENT ITEM / FEED ITEM / VIDEO / PAGE
↓
TOPIC / NARRATIVE / INTENT
↓
CONTENT DNA
↓
PERSONAL / FAMILY POLICY
↓
GUARDIAN ADMISSION
```

Rules:
- A shot cut does not necessarily mean a new item.
- A swipe can mean a new item even if visually similar.
- Internal montage/B-roll/cuts may belong to one item.
- Item grouping is an intelligence problem, not merely a motion-threshold problem.
- Never collapse shot/scene/item into one boundary type again.

---

# 3. OBSERVATION / SENSOR LAYER

## 3.1 Official adapters only

Use official OS/platform observation paths.

iOS current path:
- ReplayKit user-consented broadcast where supported.
- No silent hidden capture.
- No private APIs.
- No accessibility abuse.
- No unsupported IPC trick.

Cross-platform future:
- iOS/iPadOS
- Android
- macOS
- Windows
- Linux/browser
- Android/Google TV
- tvOS/Apple TV
- Smart TV only where technically and legally feasible

Canonical principle:

```text
ONE BRAIN.
MANY OFFICIAL OBSERVATION ADAPTERS.
SAME POLICY / SCORE SEMANTICS.
DIFFERENT CAPABILITIES.
```

## 3.2 Automatic Guardian

Permanent rule:

```text
ZERO-TOUCH WHERE PERMITTED.
ONE-TAP PER SESSION WHERE REQUIRED.
NEVER HIDDEN CAPTURE.
```

Required runtime concepts:
- GuardianRuntimeManager
- ObservationSessionManager
- PlatformCapabilityRegistry
- AppContextResolver
- ObservationAdapterRegistry
- ContentBoundaryDetector / ShotSegmenter
- SessionRecoveryController
- PrivacyFirewall

## 3.3 Sensor acceptance

Sensor layer is judged by:
- real-device behavior,
- no burst spam,
- no systemic missed transitions for its declared granularity,
- bounded latency,
- bounded memory,
- thermal behavior,
- privacy,
- session continuity.

Do not make shot-level detector pretend to be an item-level semantic detector.

---

# 4. OCTOPUS INTELLIGENCE ARCHITECTURE

Gen8 intelligence is a federation of specialists coordinated by one Guardian Meta-Brain.

## 4.1 Core

- GuardianMetaBrain
- ExpertRegistry
- IntelligenceTaskRouter
- EvidenceBus
- ProvenanceLedger
- CapabilityResolver
- ResourceGovernor
- IntelligenceCache
- ModelPackRegistry
- LearningSignalBus
- CalibrationRegistry
- PolicyRegistry

## 4.2 Specialist arms

### Vision Brain
Understands:
- scene
- object
- action
- people presence without identity recognition
- visual risk cues
- visual semantic continuity
- symbols/logos where lawful
- spatial/layout context
- image quality/OOD state

### Language / OCR Brain
Understands:
- OCR
- captions
- subtitles
- visible text
- topic
- entities
- sentiment/emotional language
- toxicity where relevant
- manipulation language
- educational content
- semantic continuity

### Speech Brain
Understands:
- on-device speech where permitted
- transcript
- speaker turn structure without identity claims
- semantic continuity
- spoken intent
- sensitive language

### Audio Brain
Understands:
- screams
- explosions
- weapon-like sounds
- crowd
- crying
- calm/nature
- alarms
- environmental events
- audio intensity
- non-speech context

### Music Brain
Understands:
- music presence
- tempo/energy where relevant
- music continuity
- explicit lyric evidence only if transcript is lawfully/technically available
- no metaphysical claims

### Symbol Brain
Understands:
- symbols
- icons
- emoji
- signs
- logos/brand cues
- culturally contextual indicators
- confidence and ambiguity

### Temporal Brain
Understands:
- shot
- scene
- item
- temporal continuity
- edit structure
- narrative evolution
- risk escalation over time
- prior harmless frame cannot erase later dangerous evidence

### Safety Brain
Dimensions include:
- sexual/explicit
- violence/gore
- fear/threat
- self-harm
- drugs/alcohol
- gambling
- dangerous behavior
- sensitive death/disease/news
- profanity
- manipulation/attention pressure
- child-safety policy

### Child Age Brain
Uses:
- parent/guardian-entered age or age band
- developmental suitability policy
- country/rating policy as separate evidence
- parent policy

Never infer child age from face/image.

### Personalization Brain
Uses:
- My Shield
- user preferences
- local corrections
- chosen goals
- muted/blocked themes
- beneficial topics
- local content history only when enabled

### Calibration Brain
Decides whether:
- score may be shown,
- confidence is sufficient,
- domain/language/age slice is calibrated,
- output must remain UNKNOWN.

### Observation / Surface Brain
Knows:
- current platform capability
- session state
- stale-result invalidation
- available UI surfaces
- accessibility/reduce-motion state

---

# 5. THIN SHELL + GROWING INTELLIGENCE MESH

Permanent architecture:

```text
SMALL TRUSTED RUNTIME
+
ON-DEMAND MODEL / DATA / POLICY PACKS
+
CACHE
+
RESOURCE-AWARE ROUTING
```

The app must not scale linearly in installed size with intelligence capability.

## 5.1 Packs

Every future Intelligence Pack should declare:
- packID
- version
- runtime compatibility
- minimum OS
- device capability
- locale/language
- compressed size
- installed size
- warm memory
- checksum
- signature
- dependencies
- privacy class
- fallback
- eviction priority
- rollback version

Packs must be:
- signed
- versioned
- checksum verified
- on-demand
- delta-updatable where feasible
- evictable
- rollbackable
- capability-aware

Do not download arbitrary executable code.
Trusted shipped runtime executes versioned model/data/config assets.

## 5.2 Anti-bloat

Use:
- LRU/TTL
- storage pressure response
- locale-aware packs
- feature/plan-aware packs
- warm/cold lifecycle
- model replacement
- cache eviction
- shared reusable embeddings where appropriate

Measure actual bundle size before setting budgets.

---

# 6. CONTENT IDENTITY + CONTENT DNA

## 6.1 Content Item grouping

Use:
- temporal adjacency
- swipe/pan evidence
- compact visual continuity
- OCR/caption continuity where available
- audio/speech continuity where available
- cache prior
- official surface identity where available
- deferred coalescing when immediate merge is unsafe

Safety rule:

```text
FALSE SPLIT = EXTRA COMPUTE
FALSE MERGE = POTENTIAL SAFETY LEAK
```

Prefer safe split/AMBIGUOUS over unsafe merge.

No positive/safe admission inheritance across ambiguous identity.

## 6.2 ContentDNA

Item-level ContentDNA contains:
- identity/version
- modality summaries
- temporal structure
- topic/entities/intents
- risk evidence
- benefit/learning evidence
- manipulation/attention pressure
- emotional load
- age suitability evidence
- uncertainty
- provenance
- privacy class
- rights/source metadata where relevant
- model versions
- freshness/expiry

Formula:

```text
one expensive content understanding
→ reusable ContentDNA
→ many cheap policy decisions
```

---

# 7. REAL SCORE SYSTEM — DEFINITION

The visible numeric score must represent:

`Personal Suitability / Admission`

It is NOT:
- objective truth,
- morality,
- universal good/bad,
- “frequency”,
- medical health effect,
- model confidence.

Internal canonical range:
- 0–100

Optional UI:
- 0–10 only if calibration supports that visual precision.

## 7.1 Score dimensions

Maintain independent dimensions before fusion:

1. Safety / Protection Alignment
2. Personal Topic Alignment
3. Benefit / Learning Utility
4. Attention / Manipulation Pressure
5. Emotional / Sensitive Load
6. Positive Exposure Alignment
7. Child / Family Age Suitability where active
8. Contextual Relevance
9. Evidence Quality
10. OOD / Ambiguity

Evidence Quality gates the score.
It is not itself the meaning of the score.

## 7.2 Score is separate from confidence

```text
score = suitability estimate
confidence = reliability of estimate
coverage = whether required evidence exists
```

Never use one number for all three.

## 7.3 Veto rules

Protection can override positive utility.

Canonical precedence:

Adult:
```text
STRONG_PROTECTION
>
SHIELD_MATCH
>
CAUTION / CONFLICT
>
UNKNOWN / ANALYZING
>
CONTENT_CHARACTER
```

Child:
```text
STRONG_PROTECTION / AGE_RESTRICTED
>
SHIELD_MATCH
>
AGE_CAUTION / CONFLICT
>
UNKNOWN
>
CONTENT_CHARACTER
```

A positive humor/learning glyph can never override a safety/age restriction.

---

# 8. REAL SCORE LABELING / GROUND TRUTH PROGRAM

A “real score” requires a defined target and independent labels.

## 8.1 Annotation ontology

Create an annotation protocol for:
- suitability/admission
- risk dimensions
- benefit dimensions
- age suitability
- manipulation pressure
- emotional load
- uncertainty
- context dependence

Use multi-annotator labeling.

For subjective dimensions:
- preserve disagreement,
- do not force false consensus,
- model label distribution where useful.

For policy-critical dimensions:
- define operational criteria and expert adjudication.

## 8.2 Dataset design

Must include:
- Turkish
- English
- later other locales
- high-risk
- low-risk
- ambiguous
- benign-but-intense
- educational-sensitive
- satire/humor
- news
- music
- edited fast-cut content
- child-age slices
- culturally variable content
- OOD examples

Use:
- rights-clear material,
- licensed material,
- project-owned material,
- consented eval material.

No silent reuse of private user content for labeling/training.

## 8.3 Splits

- TRAIN/TUNE
- CALIBRATION
- HELD-OUT TEST
- STRESS
- OOD
- LANGUAGE SLICE
- AGE-BAND SLICE

No leakage.

Final held-out is frozen before calibration choices are finalized.

---

# 9. SCORE MODEL / FUSION

Do not hardcode arbitrary final weights and call them truth.

Evaluate transparent fusion candidates:
- monotonic rule model
- small logistic model
- gradient-boosted monotonic model if justified
- calibrated neural head only if evidence justifies complexity

Constraints:
- safety veto preserved
- monotonic behavior where policy requires it
- interpretable dimension contributions
- versioned policy
- reproducible output
- no uncontrolled online weight updates

Personalization can modify policy thresholds/preferences, but must not erase safety-critical evidence.

---

# 10. CALIBRATION

A numeric score is OFF until calibration gates pass.

Evaluate:
- Expected Calibration Error (ECE)
- Brier score
- reliability diagrams
- coverage vs accuracy
- false-safe rate
- false-warning rate
- selective risk
- AUROC/AUPRC where relevant
- per-language slices
- per-age-band slices
- OOD behavior
- subgroup performance when ethically and legally appropriate

Current historical pilot with ECE ~0.55 and false-safe ~0.50 is NOT sufficient.

## 10.1 Provisional engineering gates

Freeze exact gates before final held-out.

Recommended starting internal targets:
- ECE <= 0.05 overall AND acceptable per major language slice
- meaningful Brier improvement over baseline
- safety-critical sentinel false-safe = 0 on the curated sentinel set
- false-safe rate on held-out high-risk slice <= a predeclared low threshold
- score monotonicity tests pass
- confidence/coverage gate suppresses unsupported scores
- OOD → UNKNOWN unless separately validated

These are engineering targets, not claims of universal truth.

## 10.2 Calibration methods

Evaluate:
- temperature scaling
- Platt/logistic calibration
- isotonic regression
- class-wise calibration
- slice-specific calibration only if data supports it

Avoid overfitting calibration to small sets.

---

# 11. SCORE DISPLAY GATE

Numeric score can render only if ALL are true:

- item identity stable enough
- required modality coverage sufficient
- model version calibrated for current domain
- language slice supported
- age-policy slice supported if child mode
- OOD below threshold
- confidence above minimum
- calibration registry says display allowed
- no stale identity
- no unresolved safety conflict

Otherwise:
- state/glyph only if valid,
- or `UNKNOWN`.

---

# 12. MULTIMODAL CROSS-CHECKING

Implement `CrossModalEvidenceGraph`.

The system must detect:
- agreement
- contradiction
- missing evidence
- stale evidence
- temporal mismatch

Examples:
- cheerful image + distressing speech
- harmless caption + violent visual
- educational narration + graphic medical imagery
- music tone inconsistent with text
- satire vs literal language

A single modality cannot dominate blindly.

---

# 13. H1 HIGH-RISK VISUAL SAFETY

The historical H1 gap must be closed before strong visual safety claims.

Required categories include:
- violence
- gore
- severe injury
- explicit sexual content
- dangerous behavior
- child-sensitive material

Generic Vision labels or generic VLM descriptions are NOT substitutes for a calibrated safety classifier.

Possible routes:
- rights-clear specialized classifier
- licensed commercial model
- project-trained classifier on rights-clear/consented data
- carefully benchmarked multimodal model with explicit safety calibration

License and training-data provenance must be audited.

---

# 14. PERSONAL SHIELD

My Shield:
- user-selected blocked/sensitive themes
- preferred beneficial themes
- strength levels
- context rules
- local-first persistence
- no unsafe inheritance across ambiguous item identity

Cross-language concept bridge:
- Turkish/English canonical concepts
- synonyms
- semantic expansion
- user-editable rules

Shield match can trigger higher precedence than normal content-character glyphs.

---

# 15. FAMILY / CHILD

Each child profile:
- age or age band entered by parent/guardian
- no face-based age inference
- minimal child data
- local/private by default

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
- manipulation/ads
- sensitive news/death/disease
- learning/usefulness

Outputs:
- AGE_ALIGNED
- AGE_CAUTION
- AGE_RESTRICTED
- AGE_UNKNOWN/REVIEW

Developmental suitability is distinct from legal rating systems.

---

# 16. LIVE SEMANTIC GLYPH

Semantic glyph is derived from the stabilized Guardian state, not a single classifier.

Examples:
- humor/fun → 😛 / 🙂
- learning → 🧠 / 💡
- useful/aligned → ✅
- calm/nature → 🍃
- music → ♪
- caution → ⚠️
- Shield → 🛡️
- strong protection → ⛔
- unknown → ?
- analyzing → neutral progress

Positive glyph can never override:
- strong protection
- Shield
- age restriction
- caution/conflict

Stale glyph must die immediately on identity change.

---

# 17. SEMANTIC MOTION GRAMMAR

Motion communicates meaning.

Examples:
- humor → playful drop/swing/bounce
- learning → reveal/pulse
- useful → settle/check
- calm → soft drift/fade
- music → subtle rhythm
- caution → controlled attention cue
- Shield → firm snap/lock
- strong protection → immediate sober arrival
- unknown → quiet fade
- analyzing → neutral subtle progress

Rules:
- protection motion outranks playful motion
- animate only on stabilized state changes
- safety escalation may bypass debounce
- respect Reduce Motion
- respect haptic settings
- do not make the experience childish/noisy
- unsupported Dynamic Island behavior uses truthful fallback
- full-fidelity testing lives in GuardianMotionLab

---

# 18. UI SURFACES

## Home
- Guardian ON/OFF
- current protection status
- Pure Bar
- My Shield
- Family
- Privacy
- Packs/storage
- language
- minimal explanations

## Pure Bar
Shows only:
- state/color/glyph
- score only when calibrated
- tiny confidence indicator only if UX research justifies it
- “Why?” affordance

## Dynamic Island / Live Activity
Use only capabilities actually supported.

Never claim cross-process state delivery if App Group/shared capability is unavailable.

## Developer Guardian HUD
A non-production diagnostic surface should show:
- current ShotID
- current ItemID
- SAME / NEW / AMBIGUOUS
- current modality coverage
- cache hit
- latency
- thermal
- active experts
- score gate reason
- UNKNOWN reason
- stale-state invalidation

This exists so the developer can SEE the brain working.

It must be hidden in normal production UX.

---

# 19. DEVICE HEALTH

Architecture:
- event-driven
- cache-first
- local-first
- bounded compute
- accelerator-aware
- coarse-to-fine
- early exit
- adaptive sampling
- lazy model lifecycle
- cancellation
- thermal degradation
- Low Power degradation

Do NOT:
- run heavy inference every frame
- keep every model warm
- keep unbounded histories
- duplicate models across processes unnecessarily

Engineering target:
no material user-perceived degradation.

Never claim zero battery/zero heat.

---

# 20. RESOURCE ROUTING

Meta-Brain chooses the cheapest sufficient path.

Example:

```text
Known ContentDNA cache hit
→ cheap policy evaluation
→ no deep model

Unknown item + strong text
→ text expert first

Unknown visual-only item
→ lightweight vision

Ambiguous/high-risk
→ deeper specialist escalation

Thermal FAIR
→ defer optional deep work
→ keep safety-critical work
```

---

# 21. NETWORK INTELLIGENCE FLYWHEEL

Permanent doctrine:

# EVERY USER IMPROVES THE SYSTEM

But privacy determines HOW.

## 21.1 Local Personal Learning — default

User's own device may learn from:
- ContentDNA/cache
- explicit corrections
- Shield edits
- preferences
- repeated interests
- local false-positive corrections
- local false-negative corrections
- resolved ambiguities
- local performance history

No need to upload raw private media.

## 21.2 Global Intelligence — privacy-gated

May use:
- opt-in corrections
- privacy-preserving derived telemetry
- aggregate disagreement
- aggregate FP/FN
- latency/resource statistics
- rights-clear eval data
- federated learning where technically justified
- secure aggregation
- differential privacy where appropriate

No silent centralization of:
- screenshots
- raw video
- raw audio
- viewing history
- child profile content

## 21.3 Evidence classes

Do not claim more than demonstrated:

```text
LOCAL_LEARNING_IMPLEMENTED
GLOBAL_SIGNAL_COLLECTION_IMPLEMENTED
FEDERATED_OR_AGGREGATE_LEARNING_EXPERIMENTAL
GLOBAL_MODEL_IMPROVEMENT_PROVEN
```

---

# 22. CONTROLLED EVOLUTION

No uncontrolled production self-modification.

Pipeline:

```text
USER EXPERIENCE
→ LEARNING SIGNAL
→ LOCAL UPDATE OR GLOBAL CANDIDATE
→ OFFLINE EVAL
→ SHADOW
→ CANARY
→ CALIBRATION
→ SAFETY / PRIVACY / RESOURCE GATE
→ SIGNED RELEASE
→ MEASURE
→ ROLLBACK / KILL SWITCH
```

Every deployed model/policy:
- versioned
- signed
- reproducible
- rollbackable
- measurable

---

# 23. SECURITY / PRIVACY FIREWALL

Raw observation:
- ephemeral by default
- no disk by default
- no cloud by default
- no global training by default

Derived state:
- minimally reconstructive
- versioned
- retention-classified
- evictable

Threats to model:
- identity fingerprint leakage
- re-identification
- cache collisions
- admission inheritance leak
- telemetry abuse
- child data
- model poisoning
- malicious pack
- rollback abuse
- stale policy
- cross-process leakage

Security requirements:
- pack signatures
- checksums
- secure storage
- least privilege
- capability registry
- explicit consent classes
- audit logs for releases
- kill switch

---

# 24. EVALUATION DOCTRINE

Never let the same synthetic assumptions prove themselves indefinitely.

Every major capability requires:
1. exact contract
2. Tune set
3. Held-out set
4. Stress set
5. OOD set where relevant
6. Physical-device evidence where possible
7. Independent audit
8. immutable artifacts

When synthetic and physical evidence conflict:
physical device wins.

Device-like fixtures created after a failure are useful engineering tools, but are not independent proof by themselves.

---

# 25. REAL DEVICE PROTOCOL

Physical-device evidence should capture:
- device model
- OS
- build/policy/model versions
- session start/stop
- item counts when manually approximated
- latency
- memory
- thermal
- dropped/skipped if instrumented
- privacy container
- session interruption
- exact caveats

Manual ground truth must remain labeled `MANUAL_APPROXIMATE_GROUND_TRUTH`.

Never derive fake exact precision/recall from approximate counts.

---

# 26. INDEPENDENT AUDIT

Every major milestone ends with a clean-session red-team audit.

Auditor must:
- inspect repo, not reports
- run tests
- recompute device metrics
- inspect target wiring
- inspect privacy paths
- inspect eval leakage
- inspect dead code
- inspect capability truth
- author adversarial tests
- classify claims:
  VERIFIED / LIMITED / PLAUSIBLE / UNSUPPORTED / CONTRADICTED / BLOCKED

No implementation changes until audit report is complete.

---

# 27. LOCALIZATION

Initial languages:
- Turkish
- English

UI:
- System Default
- Türkçe
- English

Semantic concepts should be canonical internally and language-rendered externally.

Calibration must be evaluated separately by language slice.

---

# 28. FAILURE MODES

Explicitly handle:
- no permission
- capture stopped
- protected/DRM content
- no pixels available
- no audio
- OCR failure
- speech unavailable
- missing model pack
- pack signature failure
- thermal pressure
- low power
- OOD content
- stale identity
- ambiguous item
- conflicting modalities
- network unavailable
- global learning disabled
- child profile incomplete

Fail safe and capability-truthful.

---

# 29. PLATFORM / DRM TRUTH

Some surfaces cannot expose raw pixels/audio because of:
- DRM
- HDCP
- protected playback
- OS policy
- app restrictions

Fallback paths:
- metadata
- captions
- provider integration
- official APIs
- UNKNOWN / UNAVAILABLE

Never pretend to see protected content you cannot observe.

---

# 30. PRODUCT UX PRINCIPLES

- minimal
- premium
- calm
- alive
- not childish
- no developer jargon in normal UI
- no reason codes in normal UI
- no unnecessary permissions
- no repeated per-content manual actions
- first-run onboarding only
- permanent settings separate from labs/debug

---

# 31. LATENCY MODEL

Target on supported/preloaded/cached paths:
- first trustworthy admission/state <1 second

This does NOT mean:
- every deep model finishes <1s,
- full semantic understanding always completes <1s.

Use:
- fast admission
- asynchronous refinement
- stale-result invalidation
- safety escalation

Measure content-change → trustworthy-state latency, not merely a tiny hash function.

---

# 32. SCORE EXPLANATION

When score is displayed, “Why?” should explain concise reasons:

Example:
- “Educational and aligned with your interests.”
- “Contains intense violence.”
- “May not be suitable for this age.”
- “High attention-pressure pattern.”
- “Low evidence — score hidden.”

Do not show internal raw weights.

---

# 33. SCORE VERSIONING

Every score result carries:
- scoreModelVersion
- policyVersion
- calibrationVersion
- ContentDNA version
- language slice
- age-policy version
- timestamp
- confidence
- coverage
- OOD state

A score without provenance is invalid.

---

# 34. SCORE INVALIDATION

Invalidate/recompute when:
- item identity changes
- ContentDNA changes
- Personal Shield changes
- child age band/policy changes
- model/calibration version changes materially
- stale cache
- new strong risk evidence arrives

Never let an old green score survive a new content identity.

---

# 35. P009 PROGRAM — EXECUTION DAG

Do not execute everything simultaneously.

## Phase A — Independent Red-Team Audit
Use package file 01.
Gate:
GO / FIX / BLOCKED.

## Phase B — Measured Tier-0 Evidence
Use package file 02 only after GO.
Determine:
A separable / B weakly separable / C not safely separable.

## Phase C — P009A identity closeout
Based on measured result:
- if A: build measured profile-aware grouping
- if B: benchmark richer cheap features
- if C: declare Tier-0 capability ceiling and move item grouping to Tier-1

Then real-device + independent audit.

## Phase D — P009B Universal Multimodal Expert Mesh
Wire real experts:
- Vision
- OCR/Language
- Speech
- Audio
- Music
- Symbol
- Temporal
- Safety

Use rights-clear/licensed models only.
Capability + resource routing.
No score yet.

## Phase E — P009C Content World Model / Narrative Brain
Build:
- cross-modal graph
- topic/entity/intent
- temporal narrative
- benefit/manipulation/emotional dimensions
- ContentDNA finalization

## Phase F — P009D Safety + Child Age + Shield
Close:
- H1 visual safety
- ChildAgePolicy
- Personal Shield
- precedence rules

## Phase G — P009E Calibration / Real Score
Build:
- labeling protocol
- rights-clear dataset
- multi-annotator process
- score model
- calibration
- held-out/OOD slices
- score display gate

NO numeric score until PASS.

## Phase H — P008B Semantic Glyph + Motion
After calibrated state exists:
- glyph resolver
- motion grammar
- stabilizer
- accessibility
- Dynamic Island/Pure Bar
- Developer Guardian HUD

## Phase I — Network Intelligence
Implement:
- local learning
- global derived signal pipeline
- opt-in corrections
- federated/aggregate experiments if justified
- signed update system
- learning evidence classes

## Phase J — Cross-platform adapters
Only after iOS semantics are stable.

---

# 36. MODEL SELECTION BY TASK

Use Fable for:
- master architecture
- independent audit
- difficult root-cause
- multimodal system design
- score/calibration architecture
- security/privacy threat model
- long-horizon agentic work

Use Opus for:
- routine Swift implementation
- focused refactor
- test repairs
- documentation updates
- repetitive engineering tasks

Always state:
- recommended model
- effort
- why
- how to switch

---

# 37. COMPLETION DEFINITIONS

## Sensor complete for phase
- declared granularity honest
- physical-device validated
- privacy/resource/session gates pass
- independent audit pass

## Item identity complete
- safe merge precision
- real-device grouping
- no safe-state leakage
- capability truth
- independent audit

## Multimodal understanding complete
- each claimed modality has real evidence
- cross-modal conflicts handled
- OOD path
- resource routing

## Score complete
- operational target defined
- independent labels
- frozen held-out
- calibration passes
- high-risk false-safe gate
- language/age slices
- provenance
- UNKNOWN fallback

## Learning complete
- measured improvement from user-derived signals
- privacy/consent proven
- release gates
- rollback

## Presentation complete
- state/glyph consistent
- stale invalidation
- accessibility
- motion semantics
- physical-device UI proof

---

# 38. FORBIDDEN CLAIMS

Do not claim:
- “real score” before calibration evidence
- “all screens” without capability qualification
- “self-learning” when only interfaces exist
- “global learning” when no real pipeline exists
- “zero battery”
- “zero heat”
- “everything analyzed under 1s”
- “Dynamic Island live semantic loop works” while cross-process state delivery is blocked
- “child safe” without child policy/eval
- “violence/gore detection works” while H1 is open
- “production ready” from synthetic tests alone

---

# 39. REQUIRED PROJECT REGISTRIES

Maintain:
- Requirement Traceability Matrix
- Decision Ledger
- Capability Matrix
- Model Registry
- Policy Registry
- Calibration Registry
- Pack Registry
- Resource Budgets
- FMEA / Resilience
- Privacy Threat Model
- Evaluation Dataset Registry
- Device Evidence Registry
- Independent Audit Ledger

---

# 40. MASTER FINAL REPORT

At the end of each major phase report:

1. Active model / effort
2. Scope
3. Entry truth
4. Code actually changed
5. Production wiring
6. Test results
7. Synthetic evidence
8. Physical-device evidence
9. Independent audit
10. Privacy
11. Resource / thermal
12. Capability truth
13. Calibration status
14. Score status
15. Learning status
16. Pack / app-size status
17. Family / child status
18. Glyph / motion status
19. Known limitations
20. Unsupported claims
21. Next gate
22. Status

Allowed status:
- PASS
- FIX REQUIRED
- BLOCKED

No “done” without evidence.

---

# 41. ULTIMATE SYSTEM FORMULA

```text
OFFICIAL OBSERVATION
→ SHOT / ITEM IDENTITY
→ MULTIMODAL EXPERT MESH
→ CROSS-MODAL EVIDENCE GRAPH
→ TEMPORAL / NARRATIVE WORLD MODEL
→ CONTENT DNA
→ PERSONAL + FAMILY POLICY
→ CALIBRATED PERSONAL SUITABILITY
→ GUARDIAN STATE
→ GLYPH / COLOR / MOTION
→ LOCAL LEARNING
→ PRIVACY-GATED GLOBAL IMPROVEMENT
→ SIGNED MODEL/POLICY EVOLUTION
```

The goal is not a visually impressive demo.

The goal is a Guardian system that is:
- fast,
- private,
- thin,
- modular,
- calibrated,
- self-improving under control,
- honest about uncertainty,
- measurable,
- independently auditable,
- capable of getting better as usage grows without turning the app into a bloated model warehouse.

# EVIDENCE BEFORE “DONE”.
# UNKNOWN BEFORE FALSE CERTAINTY.
# MEASURE BEFORE TUNING.
# REAL DEVICE BEFORE CLAIM.
# AUDIT BEFORE LOCK.
# THIN APP.
# OCTOPUS BRAIN.
# REAL SCORE ONLY AFTER CALIBRATION.
