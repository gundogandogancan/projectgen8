# GEN8 — INDEPENDENT P009B-R1 RE-AUDIT REPORT
## Audit-findings closeout verification — fresh-context session

**Auditor:** independent fresh-context re-audit session (no builder/prior-auditor context inherited)
**Date:** 2026-10-19 · **Mandate:** `docs/audit/prompts/GEN8_INDEPENDENT_P009B_R1_REAUDIT.md`
**Audited commit:** `c94d6d9` (R1 closeout) against `d61ca15` (first audit, verdict `FIX CRITICAL P009B FINDINGS`), `de58f0c` (P009B impl), `4ce238f` (Phase-C lock)
**Mode:** read-only inspection → SHA verification → probe-inversion diff audit → two independent full-suite runs → 23 fresh adversarial probes authored and executed. **No existing source or test file was modified by the re-auditor** (two test files ADDED; see §17).

---

## 1. AUDITOR SESSION

- Clean session. The closeout report, lock doc, and prior audit were treated as claims to verify, never as truth.
- Toolchain: `swift test` (SwiftPM, macOS lab, arm64e), `shasum -a 256`, `git diff/log` byte comparisons, full source reads of every R1-changed runtime file, `diff` of the frozen vs active auditor-probe file, 23 fresh probes in `AUDIT4_P009BR1Probes.swift` (+ real-path probes in GuardianIntelligenceTests).
- No tuning performed; no thresholds touched; no P009C work.

## 2. REPO / BUILD INTEGRITY

- HEAD = `c94d6d9`. All SHA-256 locks in `P009B_R1_AUDIT_FINDINGS_LOCK.md` **re-verified byte-exact**:
  - frozen ORIGINAL `AUDIT3_P009BProbes_ORIGINAL_LOCKED.swift.txt` = `3c5ae4be…b607b1` ✔
  - prior audit report = `f01bba52…d0d1b7` ✔
  - `SampleHandler.swift` = `89ac5dba…ee0153` ✔ · `PhaseCContractsV1.swift` = `b6d14ed4…367335` ✔
  - `ProfileAwareGroupingV2.swift` = `d97428f6…698c6` ✔ · `PHASEC_CloseoutTests.swift` = `9b4eea81…47ab8c` ✔
- Full suite reproduced independently **twice**: **450/450 passed, 0 failures** (builder claim verified exactly).
  With the 23 fresh re-audit probes: **473/473 passed**.
- `git diff 4ce238f..c94d6d9 --stat`: no frozen Phase-C file appears anywhere in the post-lock diff.
- Working-tree note (persisting prior finding F13, LOW): every `swift test` run regenerates
  `ml/evaluation/results/p005-e2e-benchmark.json` (LAB timing re-measurement, same envelope — not fabrication).
  My runs left it modified; restore was permission-blocked in this session. Process hygiene only.

## 3. ORIGINAL PROBE REGRESSION (mandatory check 1)

- The frozen ORIGINAL AUDIT3 file's SHA matches the lock doc exactly.
- `diff` frozen-vs-active: the delta is **EXACTLY the four pre-declared characterization inversions** from the
  lock manifest — F1 lease burn (lines 160–163), F7 spoof mint (199–200), NaN editDensity (378–380),
  structural-zero latency (427–435). **No other probe was weakened, deleted, or altered; every other line is
  byte-identical.** The two declared NO-inversion items (low-info TTL at +1 ms; old-generation same-item cache
  hit) are indeed un-inverted in the active file.
- Each inversion is a direct logical negation of the original assert (contains↔not-contains `scene:cat`;
  NotNil↔Nil of the same mint expression; `isNaN==true`↔feature-nil; `allSatisfy{==0}`↔`!allSatisfy{==0}`).
  Since the active suite passes, the frozen originals would now **fail for the right reason — the defect is
  gone**. (The frozen copy was not separately compiled: it shares the active class name, and renaming would
  modify frozen content; the byte diff + negation equivalence establishes the same conclusion.)
- All 25 AUDIT3 probes (21 unchanged + 4 inverted) ran and passed inside both of my 450-test runs.
- V1 corpus file delta since the audit: additive defaulted struct fields + a frozen-evidence comment only —
  **scenario content untouched**, and V1 feeds no gate (AUDIT3 characterizations still run against it).

## 4. F1 VERDICT — **CLOSED (verified)**

`DeepAnalysisLeaseStateV1` + lease law in `ResourceGovernorV2` (OctopusRuntimeV2.swift:273–352), outcome
mapping in `GuardianMetaBrainV2.leaseOutcome` (MetaBrainV2.swift:102–106), wired at route lines 162–196.
Verified by code read + builder tests + my probes:
- transient UNAVAILABLE releases the lease → later real input IS analyzed (probe 1; the inverted AUDIT3 probe);
- meaningful execution dedupes, refusal reported (`deep-dedupe:`), never silent;
- permanent unavailability suppresses with explicit reason (`deep-permanent-unavailable:`) (my probe);
- retries bounded (`maxRetryAttempts=3`, `deep-retry-exhausted:` reported; per-(item,domain) — other items
  unaffected) — no storms (my probe);
- cancelled/stale outcomes retry under the correct generation (builder closure test re-run, verified).
- Note (LOW, informational): `route()` itself never classifies an outcome as `UNAVAILABLE_PERMANENT` — only an
  external caller can; today permanence is effectively "bounded retry exhaustion". Honest and safe, just narrow.

## 5. F2 VERDICT — **CLOSED (verified)**

- `P009BCorpusV2` is seedless: **no seed parameter exists**, each split is a separately authored bank.
  Counts verified from code AND my own run: TUNE 24 / HELD_OUT 16 / STRESS 10 / OOD 8 / CAL_RESERVED 6,
  all gate failures = 0.
- `CorpusSplitLeakageAuditorV1.audit()` returns empty on the real banks (my probe re-asserts); the declared
  rule (exact canonical duplicate always; near-template = Jaccard > 0.8 **and** same modality combo) is
  **self-tested**: my probes plant an exact duplicate and a near-duplicate and confirm the rule fires, and
  confirm a genuinely-different scenario does NOT trip it (no hair trigger). CAL participates in all pair
  checks (contamination scan) and in hashing.
- CALIBRATION_RESERVED: fingerprint `aa6bd546ae28278f` reproduced in both of my runs; nothing executes the
  bank (reservation line prints "never executed"); my probe now **locks the reserved-bank content to that
  fingerprint** and asserts it carries no gate expectations.
- Translation check: HELD_OUT is not a translation of TUNE — authored-distinct content (inspected: e.g.
  `h-text-only-tr` science-education vs `t-text-only-en` birdhouse; TR+EN mixed inside every split).
- Limitation (LOW, declared): token-Jaccard is surface-level — it cannot detect cross-language/semantic
  duplication by construction. Mitigated by authored-distinct banks; recorded, not hidden.

## 6. F5 EXPERT REALITY MATRIX (auditor's independent classification, 5-tier)

| Expert | Code constant | Runtime (my probe) | Real provider path | Device proof | Auditor class |
|---|---|---|---|---|---|
| Vision | `realInProcessLabOnly` | ✔ | Apple Vision classify via adapter (lab) | none | **REAL_IN_PROCESS_LAB_ONLY** |
| OCR/Language | `realInProcessLabOnly` | ✔ | REAL VNRecognizeTextRequest + NLLanguageRecognizer via adapter (ran in my suite) | none | **REAL_IN_PROCESS_LAB_ONLY** |
| Speech | `realInProcessLabOnly` | ✔ | contract (honest UNAVAILABLE w/o grant) | none | **REAL_IN_PROCESS_LAB_ONLY** |
| AudioEvent | `realInProcessLabOnly` | ✔ | REAL SoundAnalysis via audio adapter (lab) | none | **REAL_IN_PROCESS_LAB_ONLY** |
| Music (presence) | `realInProcessLabOnly` | ✔ | audio adapter | none | **REAL_IN_PROCESS_LAB_ONLY** |
| Music (identity) | — | — | none | — | **UNAVAILABLE** (honest label on every record) |
| Symbol / Temporal / SafetyEvidence / Benefit / AttentionPressure | `realInProcessLabOnly` ×5 | ✔ | pure logic | none | **REAL_IN_PROCESS_LAB_ONLY** |
| EXTENSION_TIER1_LITE | — | empty profile | — | — | **UNAVAILABLE** (correct) |
| FUTURE_SHARED_TIER1 | — | empty profile | — | — | **CONTRACT_ONLY/BLOCKED** (correct) |

The prior inflation (5 arms claiming `.realRuntime`) is **gone**: all ten constants read
`REAL_IN_PROCESS_LAB_ONLY`, the runtime registry reports the same (my probe sweeps all 10 domains), the HUD
displays the registry truth, and the contract doc/capability matrix use the 5-tier names (builder's
doc-consistency test re-verified). No arm claims DEVICE_PROVEN or NOT_DEVICE_PROVEN — correct, since no
production (non-DEBUG) consumer exists.
- Note (LOW): five arms accept `availability` as an init parameter (defaulted). No production/test call site
  passes a non-default value (grep-verified); trusted-module boundary, recorded as an observation.

## 7. REAL RUNTIME TRACE (mandatory check 5) — **EXISTS AND RAN**

`P009BR1RealProviderTraceTests` executed in BOTH of my independent runs (not skipped):
in-test **rendered owned image → REAL VNRecognizeTextRequest** (read `"LEARN THE SCIENCE LESS…"`) → REAL
NLLanguageRecognizer (`en`) → `RealObservationToExpertInputAdapterV1` (provenance `ocr←apple-vision-ocr…`,
sourceMode `REAL_IN_PROCESS`) → `ExpertInputV2` → 10 experts via `GuardianMetaBrainV2.route` (executed=10)
→ `CrossModalExpertGraphV1` → `ContentUnderstandingStateV1` (confirmed; `benefit:educational-candidate`;
provenance chain intact) → measured monotonic latency (routeP50 ≈ 0.235 ms, non-zero samples).
Adapter law verified by code read + my probes: **no synthetic/corpus fallback exists in the adapter**; blank
input → nil fields → honest UNAVAILABLE downstream. A real path exists; the mesh is not interface theater.
Scope truth: the real path is **in-process lab** (test/DEBUG-HUD) — no production consumer invokes it yet
(correctly reflected by the LAB_ONLY tier).

## 8. F6 CACHE VERDICT — **CLOSED (verified)**

`IntelligenceCacheV2` entries bind identityRevision + schemaVersion + privacyClass + TTL (low-info 5 s /
normal 1 h) + modelVersion + generation-at-insert. Verified by code + builder tests + my probes:
- revision bump → `identity-revision-mismatch` MISS + record invalidated + REANALYZE (risky new content gets
  analyzed — my probe);
- strong collision (reported by the identity layer) → automatic invalidation; ambiguous → forced
  re-analysis on next read (my probes);
- low-info poison serves only inside its 5 s TTL, then expires → real input finally analyzed (my probe at
  4 999 ms vs 5 001 ms);
- old-generation reuse for the SAME item+revision stays legal **and is never silent**
  (`cache-hit-old-generation:` reason — my probe); declared as a limitation in the blockers file;
- schema mismatch structurally invalidates; privacy-scope mismatch misses; provisional items never insert;
  model-version bump never served old evidence (builder tests re-run).
- Note (LOW): TTL arithmetic uses the caller-supplied `nowMs` timeline (consistent across insert/lookup in
  all production-path calls); timestamp disorder was fuzzed (my probe) without unsafe behavior.

## 9. F7 DNA VERDICT — **CLOSED (verified)**

`IdentityResolutionSnapshotV1` + authoritative `ContentDNACandidateV2.mint` (CrossModalGraphV1.swift:191–206)
verify: confirmed state · tier1AppFull authority · appFullTier1 profile · no split/merge pending · no
conflict · current generation · `state.contentDNAReady` · **evidence-level** `anyEvidenceProvisional` ·
evidence item-ID subset · evidence generation subset. The legacy entry point is hardened with the same
evidence-level checks. My spoof matrix (9 axes + lying caller + **cross-generation mixed evidence**) is
refused in full, with a lawful-mint control proving the refusals are load-bearing. The evidence markers are
recorded from the evidence records themselves — a caller lying on every flag it controls still gets nil.
- Note (LOW, informational): `identityRevision` rides in the snapshot but has no counterpart in the state to
  cross-check at mint time; generation + item-ID subsets carry the protection today.

## 10. INPUT SANITIZATION — **VERIFIED**

`ExpertInputSanitizerV2` runs pre-route inside `route()` (MetaBrainV2.swift:121) — before ANY expert sees the
bundle; flags surface as `input-sanitized:` UNKNOWN reasons (visible, never silent). Verified: non-finite
visual confidence → 0 (max uncertainty); out-of-range clamped; non-finite tempo / tempo-without-music /
invalid edit density / invalid elapsed dropped; malformed locale dropped (→ und → UNSUPPORTED abstention);
labels/text truncated at 64/10 000. My fuzz sweep (NaN/±∞/−1/7.5/1e308/−1e−9 across all numeric fields +
malformed locale + oversized arrays + timestamp disorder + nil-item route) leaked **zero non-finite features**,
kept confidences in [0,1], never crashed, and a clean route works after the flood. NaN editDensity never
reaches any feature and can never fabricate `attention:rapid-edit-density` (my probe; the inverted AUDIT3
probe). Tier-1 handoff sanitizer (`InputSanitizerV1`) unchanged and still quarantining.

## 11. LATENCY / DEADLINE — **VERIFIED**

- Latency: `MonotonicClockV1` (DispatchTime uptime) + `OperationLatencyRegistryV1`; `route()` measures route /
  per-expert exec / cache-lookup / stale-discard / late-discard with the injectable monotonic clock. Samples
  in my runs are non-zero (routeP50 ≈ 0.235 ms); no-sample state returns **nil → rendered NOT_MEASURED,
  never "0 ms"** (HUD `latencyText` + builder test); non-finite samples refused. The old structural-zero
  defect is gone (inverted AUDIT3 probe passes).
- Deadline: pre-schedule gate (no NEW work past budget; cache still servable) + late-result discard law
  (`deadline-late-discarded:`, result never attaches, lease outcome STALE → retryable). My probes: a 50 ms
  heavy expert against a 10 ms budget is discarded AND retryable later (no permanent blindness); an expired
  budget schedules nothing, serves cache, and does not burn the lease (`notAttempted` preserved).

## 12. ASSET AUDIT — **VERIFIED**

`ExternalIntelligenceAssetAuditV2` ledger: 6 records (4 Apple OS frameworks + 2 project-authored assets),
every §19 field present; Apple records use `NOT_APPLICABLE_OS_FRAMEWORK` sentinels for weights-license and
training-data provenance and `NOT_MEASURED` for unmeasured runtime characteristics — **nothing invented**
(my probe asserts the sentinels). Unclear license is constructor/computed-property-forced to
`integrationApproved=false` in both V1 and V2 (my probe). Zero new external model assets since the prior
audit (repo + diff inspection). Runtime provenance ledger returns an empty trace for unknown subjects —
provenance is never fabricated (my probe).

## 13. CORPUS / SPLIT METHODOLOGY — **VERIFIED**

See §5. Additionally: the six R1 §11 missing families exist in TUNE (sarcasm-vs-literal — law: literal
trigger fires, no sarcasm fabrication; cheerful-visual+distressing-audio; risky→benign recovery — law:
escalation survives, represented as contradiction, never averaged away; montage; repeated scene;
talkinghead/B-roll) and are exercised through the mesh harness with temporal scripts. Doc↔code consistency is
test-enforced (`testDocCodeConsistency` reads the eval docs and matches counts/labels; re-ran green). F3/F4
doc corrections verified in the docs themselves (false STRESS/OOD claims struck through and retracted;
V1 count corrected to 18 everywhere; `testV1CorpusCountTruth` pins it).

## 14. DEVICE / HUD EVIDENCE — honest PENDING; nothing claimed, nothing to falsify

- Spec check 14 is conditional: "**If** device proof is claimed, verify…". **No device-operational proof is
  claimed anywhere** — `P009B_DEVICE_VALIDATION.md`, the blockers file, and the decision ledger all state
  build+install evidence only (twice, incl. the truthful R1 HUD) and declare the §14 in-app HUD run +
  owned-media session USER-GATED and NOT_MEASURED. I found **no doc claiming a device run** — verified.
- HUD truthfulness (code): whole file `#if DEBUG` (+ `#if DEBUG` again at the GuardianLab mount, behind
  Developer Mode); mandatory SOURCE banner (`REAL IN-PROCESS` only when the real adapter returned provider
  provenance; corpus playback always labeled `RIGHTS-CLEAR SYNTHETIC/DERIVED LAB`); availability column reads
  the live registry (5-tier truth); latency rows render NOT_MEASURED without samples; "Score display OFF" row;
  no raw media, no glyph.
- My mislabel probes attack the banner's truth condition at the adapter layer: empty/blank perception can
  never produce provider provenance (REAL banner unreachable); provenance entries only ever name real provider
  chains; corpus text injected via the text path **cannot impersonate Vision-OCR provenance**. All hold.
- Verdict reasoning from the spec text: the device check is conditional and satisfied vacuously-with-
  verification (no claim exists, and the pending item is honestly declared in every relevant artifact, with an
  explicit upgrade rule — only physically exercised experts may become DEVICE_PROVEN). Check 5's lock
  condition ("if no real path exists, P009B cannot lock as a real expert mesh") is met by the real in-process
  path (§7). The §14 user-gated run therefore remains an **open limitation (§18), not a lock blocker** under
  this spec — PASS is not withheld for it.

## 15. PRIVACY / RESOURCE — **VERIFIED (structural)**

- Zero `URLSession`/`URLRequest`/`import Network` in GuardianKit sources (my grep). No upload path.
- `ExpertInputV2` carries derived strings/labels/floats only; raw pixels never leave the adapter (code read);
  OCR text ephemeral, never persisted by experts; evidence and DNA carry `derivedNonReconstructive`.
- Release evidence logging structurally OFF: `SampleHandler.swift` byte-identical to the Phase-C-audited state
  (SHA re-verified) — carried verification stands.
- Score/glyph: `CalibrationRegistrySkeletonV1` refuses calibration and score display for every domain/language
  (my probe); H1 visual dimensions explicitly UNAVAILABLE on **every** safety record; "no lexical signal" is
  explicitly NOT a safe verdict (my probe); child policy remains contract-only and is reported as such.
- Thermal law re-verified under composition with deadlines (FAIR defers cost ≥ 5 non-safety; conservation probe:
  under FAIR + budget pressure **no requested domain vanishes silently** — each is executed/cached/deferred/
  unavailable or named in an UNKNOWN reason).

## 16. P009A REGRESSION — **NO REGRESSION**

All Phase-C immutables byte-identical (SHA locks §2 + absence from `git diff 4ce238f..c94d6d9 --stat`).
`AUDIT2_PhaseCCloseoutProbeTests` (including the untouched C6 probe) and `PHASEC_CloseoutTests` (incl.
`testC6FamilyAdversarial`) ran and passed in my independent runs. The broadcast-extension path never
references the mesh. Legacy V1 grouping engine still deprecated; no V2 runtime type holds a V1 reference.

## 17. AUDITOR FRESH PROBES — 23 new, all passing, zero source changes needed

Files ADDED (nothing modified): `Tests/GuardianCoreTests/AUDIT4_P009BR1Probes.swift` (20 tests) and
`Tests/GuardianIntelligenceTests/AUDIT4_P009BR1RealPathProbes.swift` (3 tests). Spec minimum list covered:
unavailable→available provider (+ permanent-suppression + bounded-storm), stale cache same item ID (old-gen
reuse reported / revision bump / collision paths / low-info TTL), DNA mint spoof (9-axis matrix + lying
caller + cross-generation evidence), NaN editDensity (+ full fuzz sweep w/ timestamp disorder), deadline race
(late heavy result discarded + retryable; expired budget serves cache, keeps lease), HUD real-vs-synthetic
mislabel attempt (3 adapter-level attacks), corpus near-duplicate detector (self-test + no-false-positive +
reserved-bank fingerprint content-lock `aa6bd546ae28278f`), duplicate heavy expert scheduling (collapses to
one run via lease AND via cache, refusals reported), malformed provenance (unclear license refused; sentinels
never invented; empty trace for unknown subjects), FAIR thermal + deadline pressure (composition + the
conservation law + identity race). **473/473 with probes; every probe passed against unmodified sources.**

## 18. OPEN LIMITATIONS (declared, non-blocking for this re-audit's scope)

1. **§14 user-gated device/in-app HUD proof PENDING** (honest; build+install×2 done; upgrade rule declared).
   `EXPERT_MESH DEVICE-OPERATIONAL` stays UNVERIFIED; D-0016 device-health side OPEN.
2. Carried blockers unchanged and honestly listed: C2 App Group, C3 extension shield vacuity, C4 no
   calibrated score (by design → P009C), C5 H1 visual + child contract-only, Tier-0 burst-window merge
   residual, proof-log beta decision.
3. Cache old-generation same-revision reuse is legal-by-design (now explicitly reported) — safety rests on
   identityRevision binding + identity-layer collision reporting (declared in blockers).
4. LOW observations from this re-audit: availability is an init parameter on 5 arms (no caller misuses it);
   `route()` cannot itself classify permanent unavailability; snapshot `identityRevision` not cross-checked at
   mint; token-Jaccard leakage rule is surface-level only; `adapt(providerText:)` trusts its upstream-real
   caller (can never claim Vision-OCR provenance — probed); benchmark JSONs regenerate on every test run (F13
   hygiene, persists; my runs left `p005-e2e-benchmark.json` modified — restore was permission-blocked).
5. Real-provider path is in-process lab only; no production consumer invokes the mesh (truthfully labeled).

## 19. VERIFIED PROGRESS (recomputed; approximate, never false-precise)

- **iOS Guardian beta path:** ≈ **30–40 %** (INFERRED). Relative to the prior audit (≈25–35 %): all five
  fix-level defect classes closed and probe-verified, a real in-process perception path now exists end-to-end
  with honest tiering, eval splits are genuinely independent with a self-tested leakage auditor, and
  instrumentation/deadline/asset governance are real. Still missing: production mesh wiring, device proof,
  calibration/score (P009C), H1 visual, child policy, extension semantics.
- **Full Universal Gen8 vision:** ≈ **9–13 %** (INFERRED).

## 20. GO / NO-GO

Every mandatory check (1–15) executed. All SHA locks hold; the probe-inversion delta equals the pre-declared
manifest exactly and nothing beyond it; 450/450 reproduced twice and 473/473 with 23 fresh adversarial probes
that needed **zero** source changes; F1/F2/F5/F6/F7 verified closed in code, not just in docs; the sanitizer,
monotonic latency, deadline laws, asset ledger V2, corpus families, and doc↔code consistency all verified;
a real provider → adapter → mesh → graph → state trace physically ran under this auditor's own executions;
Phase-C artifacts untouched; C6 green; score/glyph structurally OFF; H1/child honest; no network, no raw
persistence; release logging OFF. The single §14 device/HUD item is user-gated, claimed by no one, honestly
declared everywhere with a truthful upgrade rule — under this spec's conditional device check it is an open
limitation, not a lock blocker. Remaining findings are LOW/informational and recorded above.

`PASS — P009B MULTIMODAL EXPERT MESH LOCKED; GO TO P009C`
