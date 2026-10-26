# EMOTION_EVAL_R5 — Independent Evaluation of the R5 Emotional-Register Capability

**Status tier: SYNTHETIC-TESTED (host-run, DEVICE_UNVERIFIED). NOT a general-accuracy claim.**

- Capability under test: `EmotionalRegisterAdapterV1` (`emotional-register-adapter-v1`, GuardianMedia) — the R5 §5
  emotional-register / fear-pressure dimension, SEPARATE from the R4 stance field.
- Evaluation set: **R5-authored, independent** — 30 synthetic, rights-clean TR+EN sentences across the §7 contrast
  families. **No R3/R4 corpus sentences are reused**; the R3/R4 suites remain as regression only (all green at this
  run: 422 GuardianMediaTests, 0 failures).
- Harness: `Tests/GuardianMediaTests/EmotionEvalR5Tests.swift` (prints every per-case verdict + metrics; the only
  HARD assertions are safety laws — thresholds are NOT fitted to the fixtures).

## Honesty caveats (read first)

1. The set was authored by the same engineering session that built the adapter (synthetic). It demonstrates the
   structural mechanisms work as designed on held-out *phrasings*; it is **not** independent ground truth and no
   production accuracy is claimed. RWC rights/annotation/calibration gates remain untouched (P009E closed; no score).
2. 30 items is a capability probe, not a benchmark. Perfect fixture numbers below mean "the designed structures
   fire on clean examples", nothing more.
3. Latency numbers are macOS host numbers (arm64e). Device numbers = DEVICE_UNVERIFIED.

## Results (run 2026-10-26, `swift test --filter EmotionEvalR5Tests`, measured output verbatim)

### Acceptance per language slice

| Slice | Accepted (expected-set match) |
|---|---|
| TR | 15/15 |
| EN | 15/15 |

### Pressure-register detection (FEAR_PRESSURE / COERCIVE_THREAT / SENSATIONAL_PANIC / URGENCY_VIA_FEAR vs rest)

| TP | FP | FN | TN | Precision | Recall |
|---|---|---|---|---|---|
| 10 | 0 | 0 | 20 | 1.00 | 1.00 |

### Safety laws (hard-asserted)

| Law | Result |
|---|---|
| WRONGLY_SOFTENED_RISK (pressure register + stance-softened marker must surface CAUTION) | **0 violations** (law: must be 0) |
| QUOTED_THREAT_MISFIRES (quoted/reported threat classified as the speaker's own pressure) | **0** (law: must be 0) |

### Abstention / coverage

- ABSTENTION (UNKNOWN): **12/30** — includes every case where abstention is the *designed correct* answer
  (quoted threat ×2, fiction ×2, irony ×2, corrupted OCR ×2, criticism/insult ×4).

### Stance ↔ register separation

- On 10/10 comparable pressure cases the register field carried pressure information the stance field does not
  encode (`STANCE_VS_REGISTER separation: 10/10`). The two dimensions are separate fields end-to-end
  (`GeneralContentCharacterVerdictV1.contextStance` vs `EmotionalRegisterVerdictV1.register`), and the adjudicator
  law pins that REPORTS stance + FEAR_PRESSURE register surfaces **both** (caution with the distinct register
  reason `emotionalRegisterPressureCaution`).

### Latency (host, synthetic)

| op | p50 | p95 |
|---|---|---|
| `assessRegister` (per item) | 0.210 ms | 0.256 ms |
| `WorldModelEvidenceBridgeV1.build` (per item, 4 real experts + builder + policy) | < 1 ms typical; test-pinned p95 < 250 ms budget (measured far below) |

RAM/CPU/thermal: not measured on device — **DEVICE_UNVERIFIED** (the bridge+register run only inside the per-item
`mustEvaluate` gate; Tier-0 per-frame cost is unchanged by construction).

## Per-contrast outcomes (confusion, verbatim)

| Contrast | Expected | Got | Separation |
|---|---|---|---|
| disease edu vs fear-selling (TR+EN) | INFORMATIONAL vs URGENCY_VIA_FEAR/FEAR_PRESSURE | INFORMATIONAL vs URGENCY_VIA_FEAR | ✅ separated |
| quake preparedness vs panic (TR+EN) | INFORMATIONAL vs pressure family | INFORMATIONAL vs URGENCY_VIA_FEAR | ✅ separated |
| plain news vs sensation (TR+EN) | INFORMATIONAL/UNKNOWN vs SENSATIONAL_PANIC | INFORMATIONAL vs SENSATIONAL_PANIC | ✅ separated |
| supportive vs emotional threat (TR+EN) | SUPPORTIVE vs COERCIVE_THREAT | SUPPORTIVE vs COERCIVE_THREAT | ✅ separated |
| quoted threat vs direct threat (TR+EN) | UNKNOWN vs COERCIVE_THREAT | UNKNOWN vs COERCIVE_THREAT | ✅ separated (quotation → abstain) |
| sport criticism vs targeted insult (TR+EN) | — | UNKNOWN vs UNKNOWN | ❌ **NOT separated (expected)** — see §6 below |
| fiction vs real (TR+EN) | UNKNOWN (quoted-frame) | UNKNOWN | ✅ honest abstention |
| corrupted OCR (TR+EN) | UNKNOWN | UNKNOWN | ✅ honest abstention (no confident pressure from garbage) |
| irony (TR+EN) | UNKNOWN | UNKNOWN | ✅ honest abstention |

## §6 TARGETED ABUSE — honest capability declaration: UNAVAILABLE

The sport-criticism vs targeted-insult pair **does not separate** and this is reported as the expected, honest
outcome. The register adapter abstains on both (UNKNOWN) — correctly refusing to call criticism of a team/coach
abuse (criticism alone is NEVER abuse), but also unable to flag the directed insult.

Missing capabilities, precisely:
1. **Addressee-target resolution** — distinguishing "the viewer is the target" from "a third party/public figure is
   discussed" requires more than 2nd-person detection (the insult case fires `addressee:2nd-person` but so does
   supportive speech; direction alone is not abuse evidence).
2. **Insult/derogation vocabulary with rights-clean, independently labeled calibration data** — no audited lexicon
   or model exists in the repo; building an uncalibrated insult list would violate the no-fear-word-list law's
   spirit and the P009E calibration gate.
3. **Humor/irony disambiguation** — structurally undetectable (UNKNOWN BY DESIGN, same law as R4).

Per the mandate ("yarım iki model yerine ölçülmüş bir çalışan yetenek"), targeted abuse is declared
**UNAVAILABLE** in R5 and remains the next canonical open capability. The eval set keeps the pair so the gap stays
measured in every future run.

## What feeds the world model now (R5 §4/§8 score-dimension separation)

- CONTENT CHARACTER — `GeneralContentCharacterV1` markers (R3/R4, unchanged).
- STANCE / INTENT — `ContextEvidenceAdapterV1` (R4, unchanged).
- EMOTIONAL REGISTER — `EmotionalRegisterVerdictV1` (NEW): enters `WorldModelEvidenceBridgeV1` as its own
  `ExpertEvidenceV2` (attentionPressure domain, own provenance/model version, `heuristicSupportOnly`).
- CHILD AGE SUITABILITY — real `ChildAgePolicyEngineV1` outcomes on the live path (NEW).
- EVIDENCE QUALITY — honest UNAVAILABLE records for vision-high-risk/speech/audio/music/symbol + self-eval counters
  (`registerAbstain`, `familyDegradedReads`, `bridgeUnavailableRecords`).
- CALIBRATED SUITABILITY — **still closed** (P009E). No numeric score anywhere in R5.
