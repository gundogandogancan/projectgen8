# P009B-R1 — AUDIT FINDINGS CLOSEOUT + REAL RUNTIME WIRING

**RECOMMENDED MODEL:** Claude Fable
**EFFORT:** High / maximum practical reasoning
**MODEL SWITCH:** `/model` → Fable
**VERIFY:** `/status`

## ENTRY VERDICT

Independent audit verdict: `FIX CRITICAL P009B FINDINGS`.

Do not start P009C. Do not enable score/glyph. Preserve the full audit, original AUDIT3 probes, P009A locks and Phase-C artifacts.

Audit findings to close:
- F1: deep-analysis lease is consumed even when an expert returns transient UNAVAILABLE.
- F2: TUNE/HELD-OUT/STRESS/OOD/CAL splits are weak/non-independent because seed parity aliases them.
- F5: availability inflation; several experts are labelled REAL_RUNTIME although the only consumer is DEBUG HUD/corpus and no real provider feeds ExpertInputV2 in production/in-app runtime.
- F6: cache hit can bypass generation/identity stale firewall; collision recovery is manual.
- F7: ContentDNACandidateV2.mint trusts caller-supplied provisional state.
- F3/F4 docs contain incorrect claims and 17/18 scenario mismatch.
- ExpertInputV2 accepts malformed NaN/∞ values such as editDensity.
- route latency is structurally zero.
- asset-audit records omit required governance fields.
- required corpus families are missing: sarcasm-vs-literal, cheerful+distressing, risky→benign recovery, montage, repeated scene, B-roll.
- deadlineMs is not enforced.

Audit-verified clean areas MUST NOT regress:
P009A locks, C6 fix, stale firewall for executed work, malformed handoff quarantine, thermal safety law, benefit-vs-risk precedence, temporal monotone-max, score OFF, H1/child honesty, derived-only/no-network privacy.

---

## 1. LOCK AUDIT EVIDENCE

Create `docs/audit/P009B_R1_AUDIT_FINDINGS_LOCK.md`.

SHA-lock:
- independent P009B audit report
- original AUDIT3_P009BProbes.swift
- commit containing audit artifacts
- 388-test pre-audit state
- 25 auditor probes
- all P009A/Phase-C immutable artifacts

Do not modify auditor tests to make them pass.

---

## 2. F1 — FIX DEEP-ANALYSIS LEASE SEMANTICS

Introduce explicit execution/lease states such as:

`NOT_ATTEMPTED / LEASED / EXECUTED_MEANINGFUL / EXECUTED_ABSTAINED / UNAVAILABLE_TRANSIENT / UNAVAILABLE_PERMANENT / CANCELLED / STALE / FAILED`

Rules:
- transient UNAVAILABLE does not permanently consume the item/domain deep-analysis opportunity
- permanent capability absence may suppress retries for the current capability/session version
- cancelled/stale attempts may retry under the correct generation
- meaningful results dedupe
- retries are bounded; no storms

Tests:
- unavailable→available executes later
- permanently unavailable does not spin
- cancelled/stale retry
- meaningful result dedupe
- abstention bounded behavior

---

## 3. F2 — REBUILD SPLITS FOR REAL INDEPENDENCE

Current seed parity design is invalid evidence.

Rebuild corpus generation so TUNE, HELD_OUT, STRESS, OOD and CALIBRATION_RESERVED differ structurally:
- distinct scenario instances/templates
- distinct temporal structures
- distinct modality combinations
- distinct text/surface examples
- distinct noise/OOD transforms
- no byte-identical derived-input records across splits
- calibration set untouched by tuning

Implement `CorpusSplitLeakageAuditorV1` that fails on:
- exact canonical duplicate
- seed aliasing
- near-template leakage above a declared similarity rule

Workflow:
TUNE → allowed fixes only → freeze → HELD_OUT/STRESS/OOD run once.
Do not inspect/use CALIBRATION_RESERVED except to verify it remains reserved.

---

## 4. F5 — CAPABILITY TRUTH + REAL PROVIDER RUNTIME WIRING

Do NOT fix this only by renaming enum values.

Classify every expert from actual code + wiring + evidence:

- REAL_RUNTIME_DEVICE_PROVEN
- REAL_RUNTIME_NOT_DEVICE_PROVEN
- REAL_IN_PROCESS_LAB_ONLY
- CONTRACT_ONLY
- UNAVAILABLE

Build `RealObservationToExpertInputAdapterV1`.

Where technically available, reuse existing P002–P006 real providers:
- Vision
- Vision OCR
- NaturalLanguage/text semantics
- SpeechTranscriber
- SoundAnalysis
- Music presence
- temporal provider
- symbol provider/input

Required real path:
`real owned/rights-clear in-process observation/media → provider → RealObservationToExpertInputAdapterV1 → ExpertInputV2 → expert → GuardianMetaBrainV2 → CrossModalExpertGraphV1 → ContentUnderstandingStateV1`

No synthetic corpus fallback in the production adapter.

If a modality cannot be wired now:
mark it LAB_ONLY / CONTRACT_ONLY / UNAVAILABLE and make HUD/docs/capability matrix match.

Do not label the entire mesh device-proven because one or two experts were exercised.

---

## 5. F6 — CACHE GENERATION + IDENTITY FIREWALL

Every cache record/read must bind to:
- identity revision
- session/generation compatibility
- model version
- evidence schema version
- TTL/freshness
- privacy scope
- collision evidence

On mismatch: MISS/REANALYZE, never return positive/safe evidence.

Add automatic collision handling:
- strong mismatch → invalidate
- ambiguous collision → re-analysis
- split revision invalidates
- stale generation cannot silently reuse

Tests: stale generation, split, collision, model mismatch, schema mismatch, TTL expiry, valid confirmed hit.

---

## 6. F7 — DNA MINT MUST USE AUTHORITATIVE IDENTITY

Replace caller-trusted `itemProvisional: Bool` with an authoritative `IdentityResolutionSnapshotV1` containing:
- item ID
- revision
- resolution state
- source profile
- evidence provenance
- confirmation authority
- generation/session
- unresolved split/merge state
- strongNew/conflict state

`ContentDNACandidateV2.mint` must independently verify identity is confirmed and current.

A malicious caller attempting to mint DNA from provisional/stale/split-pending evidence must get nil/quarantine.

---

## 7. EXPERT INPUT SANITIZER V2

Sanitize before expert execution:
- NaN / ±∞
- editDensity
- confidence
- timestamps/durations
- audio/visual scores
- vectors/arrays
- malformed locale
- impossible modality flags
- negative resource values

Normalize only where semantically safe; otherwise abstain/quarantine.
Invalid values must never become confident evidence.

Add fuzz/property tests.

---

## 8. REAL LATENCY INSTRUMENTATION

Replace structural 0 ms values with monotonic measurements for:
- MetaBrain route
- per-expert execution
- cache lookup
- graph fusion
- ContentUnderstandingState build
- cancellation/stale discard

HUD shows p50/p95 only from measured samples.
No samples → `NOT_MEASURED`, never `0 ms`.

---

## 9. DEADLINE ENFORCEMENT

Make deadlineMs operational:
- monotonic deadline
- router checks before scheduling
- expert gets remaining budget
- optional late work cancelled/deferred
- safe minimum/safety-critical path follows resource policy
- late result cannot attach after deadline or identity change

Tests: expired deadline, on-time result, late result, cache path, FAIR thermal, identity change race.

---

## 10. EXTERNAL ASSET AUDIT V2

Complete required governance fields for every framework/model/data asset:
- exact name/version or OS-managed status
- code license
- weights license
- commercial-use status
- redistribution status
- training-data provenance documentation
- restrictions
- model/asset size
- installed size
- warm memory
- measured latency or NOT_MEASURED
- languages
- safety limitations
- privacy behavior
- offline support
- OS/device support
- fallback
- checksum/signature where applicable
- verification source
- audit date

For Apple OS frameworks, use `NOT_APPLICABLE_OS_FRAMEWORK` where appropriate; never invent licenses/provenance.

No new external model is required just to fill the ledger.

---

## 11. COMPLETE RIGHTS-CLEAR CORPUS

Add truly distinct scenarios for:
- sarcasm vs literal trigger
- cheerful visual + distressing audio
- risky → benign recovery
- montage
- repeated scene
- talking-head + B-roll

Correct the real scenario count everywhere.

Ensure risky→benign does not erase historical strong-risk evidence.

---

## 12. FIX DOC/CODE CONSISTENCY

Correct F3/F4 false claims.
Do not describe byte-identical inputs as distinct surface variants.
Do not claim all-modalities-unavailable fires where router semantics make it impossible.

Generate corpus metadata from code where feasible.

Add consistency tests:
- scenario count
- split names
- capability labels
- availability labels

---

## 13. HUD TRUTHFULNESS

Developer HUD must show:
- actual availability class
- actual provider wiring
- capability profile
- real vs synthetic source mode
- `NOT_MEASURED` latency where appropriate
- score OFF

Required banner:
`SOURCE: REAL IN-PROCESS`
or
`SOURCE: RIGHTS-CLEAR SYNTHETIC/DERIVED LAB`

Never let lab corpus playback visually masquerade as real perception.

---

## 14. USER-GATED PHYSICAL DEVICE / IN-APP PROOF

After code freeze, install debug build and ask the user for the physical run.

Use owned/rights-clear media.

Exercise where available:
- real Vision
- real OCR
- real Speech/Audio
- real Music presence
- multimodal conflict
- unavailable/unsupported case
- repeated item/cache
- stale/cancel case if reproducible

Capture:
provider→adapter→expert→MetaBrain→graph→ContentUnderstandingState,
HUD proof, route latency, cache, stale/cancel counts, memory, thermal, privacy.

Only physically exercised experts may become DEVICE_PROVEN.

If manual gesture is needed, STOP and request it; do not fabricate completion.

---

## 15. ACCEPTANCE BEFORE RE-AUDIT

Required:
- all original auditor probes preserved and passing
- F1 lease semantics pass
- split leakage auditor passes
- availability matches runtime truth
- at least one genuine real-provider production/in-app route exists
- cache cannot bypass generation firewall
- DNA caller spoof impossible
- invalid expert inputs safe
- latency is actually measured
- deadline enforced
- missing corpus families added
- asset ledger truthful/complete
- HUD distinguishes real vs synthetic
- score/glyph remain OFF
- privacy/resource safety preserved

---

## 16. FINAL REPORT

Return exactly:

1. ACTIVE MODEL / EFFORT
2. AUDIT FINDINGS LOCK
3. F1 DEEP-LEASE FIX
4. F2 SPLIT INDEPENDENCE
5. F5 CAPABILITY TRUTH
6. REAL PROVIDER → EXPERT RUNTIME TRACE
7. F6 CACHE FIREWALL
8. F7 DNA AUTHORITY
9. INPUT SANITIZATION
10. LATENCY INSTRUMENTATION
11. DEADLINE ENFORCEMENT
12. ASSET AUDIT V2
13. CORPUS COMPLETION
14. DOC/CODE CONSISTENCY
15. HUD TRUTH
16. TUNE / FREEZE
17. HELD-OUT
18. STRESS / OOD
19. PHYSICAL DEVICE / IN-APP PROOF
20. PRIVACY
21. RESOURCE / THERMAL
22. EXPERT REALITY MATRIX
23. TESTS
24. KNOWN LIMITATIONS
25. FILES CHANGED
26. STATUS

Status exactly one:
`READY FOR INDEPENDENT P009B-R1 RE-AUDIT`
`FIX REQUIRED`
`BLOCKED`

Then STOP.
Do not start P009C.
