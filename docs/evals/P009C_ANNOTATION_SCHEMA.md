# P009C — Annotation Schema (`P009CAnnotationV1`)

Formal, code-defined schema (consistency is structural — the tests consume the same type):

| Dimension | Field(s) | Matching |
|---|---|---|
| topics | expectedTopics / forbiddenTopics (concept IDs) | exact concept-ID match |
| entities | expectedEntityPrefixes | prefix (partial) match |
| intents (SUBJECTIVE) | intentsAnnotatorA / intentsAnnotatorB | model hypotheses must intersect EACH annotator's set; `intentDisagreement` preserved and test-asserted non-empty where annotators differ |
| intent ambiguity | expectIntentAmbiguous | exact |
| semantic episodes | minEpisodes | lower bound |
| contradiction | expectContradiction + allowedContradictionOutcomes | presence + outcome ⊆ allowed |
| context | expectedContextTags | containment in any episode |
| narrative | expectRiskEscalated / expectRecoveryObserved | maxRisk ≥ 0.6 / recovery label |
| emotional (SUBJECTIVE) | emotionalAnnotatorA/B | intersect the UNION (disagreement kept) |
| manipulation | expectManipulationEvidence | non-empty evidence |
| uncertainty | allowedKnowledgeStates + expectUnsupportedLanguage | state ∈ allowed; language axis raised |
| DNA | expectDNAReady | exact |

Two independent annotation slots exist for every subjective dimension; disagreement is PRESERVED in the
corpus (test `testAnnotationDisagreementPreserved`) — expectations accept either annotator's view and
never silently merge them. Annotations are project-authored (same rights class as the corpus).

## Metrics posture (§25)

On an authored corpus these are STRUCTURAL counts, not real-world P/R: exact/partial topic/entity/intent
match per scenario, contradiction detection presence+type, episode-boundary lower bounds, escalation/
recovery correctness, abstention/UNKNOWN correctness, OOD behavior, stale exclusion, DNA refusal/revision
correctness. All reported as pass/fail per scenario (TUNE 21/21, HELD_OUT 10/10, STRESS 4/4, OOD 4/4).
No single vanity score is produced anywhere.
