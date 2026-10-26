# ABUSE_MANIPULATION_EVAL_R6 — Independent Evaluation of the R6 Targeted-Abuse + Covert-Manipulation Capability

**Status tier: SYNTHETIC-TESTED (host-run, DEVICE_UNVERIFIED). NOT a general-accuracy claim.**

- Capability under test: `TargetedPressureHeuristicV1` (`targeted-pressure-heuristic-v1`, GuardianMedia) — the R6 §4 +
  ADDENDUM §5/§6 TARGET / ACT / MECHANISM structural dimension, SEPARATE from the R4 stance and R5 emotional register.
- It is a **declared heuristic / structural evidence** producer — NOT an "abuse detector", NOT a sentiment model,
  NOT a measurement of anyone's psychological state (mandate law). Every evidence record it feeds the world model
  carries `calibrationStatus: .heuristicSupportOnly`.
- Evaluation set: **R6-authored, independent** — 23 synthetic, rights-clean TR+EN sentences across the §7 +
  addendum §6 contrast families. **No R3/R4/R5 corpus sentences are reused.** R3/R4/R5 suites remain regression only
  (all green at this run: **477 GuardianMediaTests, 0 failures**, up from the 422 R5 baseline).
- Harness: `Tests/GuardianMediaTests/AbuseManipulationEvalR6Tests.swift` (prints every per-case verdict + metrics;
  the only HARD assertions are safety laws — thresholds are NOT fitted to the fixtures).

## Honesty caveats (read first)

1. The set was authored by the same engineering session that built the capability (synthetic). It demonstrates the
   structural mechanisms work as designed on held-out *phrasings*; it is **not** independent ground truth and no
   production accuracy is claimed. RWC rights/annotation/calibration gates remain untouched (P009E closed; no score).
2. 23 items is a capability probe, not a benchmark. Perfect fixture numbers mean "the designed structures fire on
   clean examples", nothing more.
3. Latency numbers are macOS host numbers (arm64e). Device numbers = DEVICE_UNVERIFIED.
4. Humor/irony, sarcasm, and genuinely ambiguous attribution are abstained to UNKNOWN/NONE **by design** — the
   capability never claims to separate friendly ribbing from abuse without context.

## Results (run 2026-10-26, `swift test --filter AbuseManipulationEvalR6Tests`, measured output verbatim)

### Acceptance per language slice (detection matches the expected positive/negative class)

| Slice | Accepted |
|---|---|
| TR | 12/12 |
| EN | 11/11 |

### Supported own-voice pressure detection (directed demeaning/threat OR a covert mechanism vs the rest)

| TP | FP | FN | TN | Precision | Recall |
|---|---|---|---|---|---|
| 9 | 0 | 0 | 14 | 1.00 | 1.00 |

### Safety laws (hard-asserted — all must be 0 / met)

| Law | Result |
|---|---|
| WRONGLY_SOFTENED_RISK (a detected own-voice pressure must surface CAUTION through the adjudicator) | **0** (law: must be 0) |
| CRITICISM_ACTIONED_WRONGLY (a team/institution criticism must never action) | **0** (law: must be 0) |
| QUOTED_ACTIONED_WRONGLY (a quoted insult must never action as the speaker's) | **0** (law: must be 0) |
| NO_OVERT_LEXICON_PRESSURE detected (addendum §6 success criterion) | **2/2** (≥1 required) |

### Abstention / coverage

- ABSTENTION/NONE: **14/23** — every criticism, supportive, quoted, irony, righteous-anger, apology-request, and
  corrupted-OCR case abstains, which is the DESIGNED correct answer for each.

### Three-dimension separation (stance ≠ register ≠ targeted-pressure)

- On 9/9 comparable supported-pressure cases, the targeted-pressure verdict carried TARGET/ACT/MECHANISM information
  the stance field does not encode at all (`THREE_DIM_SEPARATION: 9/9`). The three dimensions are separate fields
  end-to-end: `ContextEvidenceVerdictV1.stance` vs `EmotionalRegisterVerdictV1.register` vs
  `TargetedPressureVerdictV1.{target,act,mechanism}`.

### Addendum §6 success criterion — pressure WITHOUT an overtly negative lexicon

Both no-overt-lexicon guilt/shame coercion cases (TR + EN) were detected as `GUILT_SHAME_COERCION` **without** any
explicit swear/threat lexicon term — the mechanism came purely from the structural relation (guilt/shame cue +
imperative). The supportive and apology-request look-alikes in the same families produced **0 false alarms**.

### Covert mechanisms exercised (each pinned by a unit test in `TargetedPressureHeuristicR6Tests`)

| Mechanism | TR | EN |
|---|---|---|
| `FEAR_TO_ACTION_DEMAND` | (register path) | (register path) |
| `GUILT_SHAME_COERCION` | detected | detected |
| `PROVOCATION_INCITEMENT` | detected | detected |
| `SOCIAL_COMPARISON_PRESSURE` | — | detected |
| `DECEPTIVE_URGENCY` | detected | — |

### Latency (host, synthetic)

| op | p50 | p95 |
|---|---|---|
| `TargetedPressureHeuristicV1.assess` | 0.478 ms | 0.704 ms |

(SYNTHETIC-TESTED, macOS arm64e host; DEVICE_UNVERIFIED. Per-item cost — never per-frame.)

## Honestly-reported non-separations / known limitations

- **Humor/irony vs genuine attack:** NOT separated without context → UNKNOWN by design (measured: all irony cases
  abstain, 0 false alarms, but a hostile message disguised as a joke would also abstain — a known miss direction,
  reported honestly, never claimed).
- **Collective vs directed worth-attack boundary** relies on an explicit 3rd-party/collective subject cue; a novel
  institution name not in the (declared-heuristic) collective cue list could be mis-targeted. This is a vocabulary
  gap, not a calibrated model — surfaced as such.
- **English worth-nouns** ("failure/loser") count as demeaning only alongside a 2nd-person subject — a terse
  "complete failure" with no "you" abstains (correct for 3rd-party, a miss for an elided-subject direct insult).
- No numeric 0–100 score is produced anywhere; the frozen P009E calibration gate stays closed.

## World-model-for-all-profiles cost (R6 §1 / §6)

Measured on the synthetic bridge-latency benchmark (`WorldModelBridgeR5Tests.testBridgeLatencyBoundedSynthetic`,
unchanged, still green) and the R6 dedup path:

- The world-model bridge + `SafetyPolicyEngineV1` now run for **every profile** (adult included) on the per-item
  path; the `ChildAgePolicyEngineV1` overlay runs only for child/teen.
- R6 §1.1 SINGLE EVIDENCE: the four frozen text experts run **once** per item (`runTextExperts`) and the shared
  envelopes feed the bridge via `precomputedTextEvidence`, so a text-expert signal is produced once, not twice.
- Bridge p95 stays well under the 250 ms synthetic per-item ceiling (host; DEVICE_UNVERIFIED). Under thermal
  serious/critical the world model is **skipped** for the item and its coverage is marked UNKNOWN/PARTIAL — never
  presented as "ran".
- Per-item only; stale jobs cancelled on item change (the existing identity-resolution firewall). The existing
  rapid-swipe benchmarks (`RapidSwipeGateTests`) remain green.

## Traceability

`MANDATE R6 §4 + ADDENDUM §5/§6 → TargetedPressureHeuristicV1 (contract+code) → TargetedPressureHeuristicR6Tests +
WorldModelBridgeR6Tests + AdjudicatorR6Tests + AbuseManipulationEvalR6Tests → (DEVICE_UNVERIFIED)`.
