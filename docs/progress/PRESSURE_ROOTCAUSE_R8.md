# PRESSURE_ROOTCAUSE_R8 — Why Recall Collapsed (by family) + On-Device Model Readiness

**Status tier: ANALYSIS + READINESS (code-grounded). This is NOT a production-detector claim.** The
`TargetedPressureHeuristicV1` remains a declared, high-precision structural heuristic feeding the world model as
`heuristicSupportOnly`. The R7 adversarial set (`ADVERSARIAL_PRESSURE_R7.md`, TP=2/FP=0/FN=7/TN=15, Precision 1.00,
Recall 0.22) is now **REGRESSION-ONLY** — no threshold is fit to its authored sentences (mandate §5/§6). No RWC
rights/annotation/calibration gate is bypassed; all remain OPEN.

## 1. Root cause of the 7 R7 false negatives — BY FAMILY (what STRUCTURAL capability is missing, not which words)

| R7 FN family | Example (truncated) | Missing STRUCTURAL capability (not vocabulary) |
|---|---|---|
| **deceptive-urgency** | "Son 2 dakika! Hemen tıkla yoksa…" | A **scarcity/deadline → compelled-action** structure recognizer. The heuristic keys on a fixed cue combination; the manipulation is the *temporal-pressure-plus-imperative* RELATION, which no structural arm models. Needs a deadline/urgency-operator + imperative-target dependency, not more "hemen/son dakika" tokens. |
| **conditional-guilt** | "Beni gerçekten sevseydin…" | A **counterfactual-conditional → obligation** structure ("if you really X, you would Y"). The coercion lives in the *conditional mood binding the listener's worth to compliance* — a syntactic pattern (protasis/apodosis with 2nd-person obligation), absent from the lexeme-based arm. |
| **shame-coercion** | (guilt/shame variants) | Same gap as conditional-guilt: **evaluative-predicate-of-the-listener → behaviour demand**. No modelling of "your worth is contingent" framing. |
| **provocation / incitement** | "Herkes gidip onlara haddini bildirsin… saldırın!" | A **collective-imperative → named/implied out-group target** recognizer. The heuristic caught 2nd-person insults but not a *3rd-party-directed call to act*. Needs imperative-mood + agent="everyone" + patient=out-group. (Hard safety law held: condemnation ≠ incitement.) |
| **mixed TR+EN directed** | "You are so aptal, hiçbir işe yaramıyorsun…" | **Code-switched target resolution.** An EN "You are" + a TR insult resolved the target to THIRD_PARTY (wrong). The arm's language-scoped target resolver does not carry the 2nd-person referent ACROSS a language switch mid-clause. |
| **multi-speaker attribution** | "A: … B: … A: sen zaten her şeyi batırırsın" | **Speaker segmentation.** The directed insult sits on one dialogue line; with no speaker turn model the directed line is not isolated and own-voice vs quoted cannot be assigned per-turn. |
| **implicit target** | (directed pressure, unnamed target) | **Implicit/elided-target resolution.** Directed pressure with no explicit "you"/name is unrecognized; needs discourse-level referent tracking, not a lexeme. |

**The single honest finding:** recall is lost because the covert-mechanism arms (deceptive-urgency / guilt-shame /
provocation) are **cue-combination detectors, not structure/relation detectors**, and because **target resolution is
language-scoped and sentence-local** (no code-switch carry, no speaker turns, no implicit-referent tracking). Adding
words to the existing arm would overfit the authored set and raise false positives — explicitly rejected (mandate §5.1).

## 2. What this means for the pipeline (no change to behaviour this round)

- `TargetedPressureHeuristicV1` stays the **cheap Tier-0 structural first signal** (its FP=0 discipline is valuable).
- The missing capabilities above are **context/relation** problems — the staged plan (mandate §6.E) is: Tier-0 cheap
  structural signal → Tier-1 context model ONLY when the cheap signal is ambiguous → evidence fusion in the EXISTING
  world model. No LLM-per-frame; no new parallel Guardian intelligence.
- Until independent held-out evidence exists, the capability remains categorical (`heuristicSupportOnly`) — never a
  calibrated score, never an "abuse" verdict.

## 3. Annotation readiness (the real path to recall) — `PressureAnnotationOntologyV1`

The deliverable this round is **corpus READINESS**, not a detector. `PressureAnnotationOntologyV1` (new, pure, versioned,
Codable; `GuardianMedia`) is the independent-annotation schema:

- **Mechanism** (`PressureMechanismV1`): directed-demeaning, conditional-guilt, shame-coercion, deceptive-urgency,
  provocation-incitement, fear-to-action, implicit-targeting, **legitimate-emergency**, criticism-not-attack,
  quoted-or-reported, satire-irony, supportive, **ambiguous**, none. Every R7 FN family maps to a label
  (`r7FailureFamilyToMechanism`, pinned by test) — proving the schema is ready for exactly the data that was missed.
- **Target** (`PressureTargetV1`): second-person-viewer / named / group / institution / third-party / **implicit** /
  none / unsupported — the dimension R7 got wrong on mixed-language + implicit targets.
- **Intent**, **Stance**, **EmotionalPressure**, **quotedNotOwnVoice**, **legitimateEmergency**, **ambiguous**,
  **language** (incl. `MIXED_TR_EN`), plus annotator id + free-text disagreement notes.
- **Inter-annotator agreement** (`PressureAnnotationAgreementV1`): distinct labels, majority mechanism, and an explicit
  **unresolved-split** state (`majorityMechanism == nil`) — disagreement is recorded, never silently resolved by the
  model-building agent (mandate §6.C). A JSON schema example (`exampleRecordJSON`) lets an external tool validate.

This is consistent with the RWC gates: it is a schema for FUTURE rights-clear, independently-labelled data. It opens no
gate and makes no accuracy claim.

## 4. On-device model-candidate evaluation (honest, measured where possible)

Measured `canImport` facts on the installed SDK (test `PressureAnnotationOntologyR8Tests.testOnDeviceModelCandidateProbe…`,
printed `MODEL_CANDIDATE_PROBE`, host macOS 26.5 / Xcode 26.x):

| Candidate | Installed-SDK availability (measured) | Licensing | RAM / thermal (est., DEVICE_UNVERIFIED) | TR/EN fit | Verdict for the pressure problem |
|---|---|---|---|---|---|
| **Apple NaturalLanguage** | `canImport(NaturalLanguage)` = **true** (already used across GuardianIntelligence) | Apple OS framework, no extra license | Low RAM, low thermal; on-device | Good tokenization/lang-ID; embeddings TR/EN present | **USE for Tier-0 structure/target** (tagger + embeddings for referent/mood cues). Does NOT solve relation-level manipulation alone, but is the cheap, shippable structural layer. |
| **Apple Foundation Models** | `canImport(FoundationModels)` = **true** on THIS SDK | Apple OS framework (on-device LLM); usage-policy constrained | Higher RAM/thermal; session-based; must be budgeted + thermal-gated like the photo shield | Strong TR/EN; but output must be **independently verified before action** (hallucination risk, mandate §6.E) | **CANDIDATE for Tier-1 context ONLY when the cheap signal is ambiguous.** NOT per-frame. Device-measured budget required before any action-level use (DEVICE_UNVERIFIED). Availability is real on this SDK but the *supported, policy-clear* on-device inference path must be re-verified against current Apple docs at implementation time (constitution §3). |
| **CoreML small classifier** | `canImport(CoreML)` = **true** | Apple framework; the MODEL weights need a rights-clear training set | Small model = low RAM/thermal | Depends entirely on training data | **BLOCKED on corpus.** The ontology + independent annotation (above) are its prerequisite. No model can be trained or claimed until the annotated corpus exists. |

**Recommendation.** (1) Keep `TargetedPressureHeuristicV1` as the cheap Tier-0 signal. (2) Build the **rights-clear,
independently-annotated corpus** using `PressureAnnotationOntologyV1` — this is the binding blocker for real recall.
(3) Evaluate **Foundation Models as the Tier-1 context arm, gated + budgeted + output-verified**, on a real device,
BEFORE any action-level use. (4) A CoreML classifier only becomes viable once (2) exists. (5) The R7 set is
regression-only; the model's success must be measured on INDEPENDENT held-out data, never re-using R7 (mandate §6).

**Not done this round (honest):** no corpus acquired, no model trained, no Tier-1 context model wired, no device
measurement. The analysis + versioned ontology + measured capability probe ARE the deliverables; production detector is
explicitly NOT COMPLETE.
