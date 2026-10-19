# P009C — Topic / Entity / Intent Graphs

## TopicGraphV1 + SemanticTaxonomyV1 (`p009c-taxonomy-v1`)

TR+EN canonical concept mapping FIRST: mesh labels (which already come from the real TR+EN P003
lexicons) map to single concept IDs (`concept:mortality`, `concept:education`, `concept:calm-nature`…);
scene labels map via a synonym table. Multi-topic by design: ranked nodes with dominance (weighted
evidence, never averaged confidence), persistence (episode counts), transitions, uncertainty. No forced
single-topic classification. Taxonomy is VERSIONED; a version change supersedes DNA and invalidates the
world-model cache (tested). Translation-equivalence is explicit in the taxonomy — and the corpus law
forbids using translation as fake held-out independence (carried from R1 F2).

## EntityGraphV1

Kinds: person-present (NON-identifying — only via presence signals like `person-speaking`; arbitrary
person labels are structurally refused), organization, place, product, object, activity, event, concept,
media-title (only if legally/technically sourced — none exists yet), brand/logo candidate.
Laws (tested): no real-person identification, no sensitive-trait inference (forbidden-fragment guard),
confidence + provenance mandatory, conflicting evidence (two strong places in one moment) marked
`conflicting` and RETAINED UNRESOLVED — never auto-picked.

## IntentGraphV1

13 candidate intents (inform/teach/entertain/persuade/sell/provoke/warn/request-action/seek-engagement/
narrate-experience/express-emotion/satire-humor/unknown). Intent is HYPOTHESIS: supporting modalities +
evidence, counter-evidence (e.g., satire cue counters `inform`), temporal scope, uncertainty (floored —
support never reaches certainty). Ambiguity is explicit: close competitors ⇒ `intentAmbiguous=true`
(tested: teach-vs-sell stays ambiguous).
