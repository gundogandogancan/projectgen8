# GEN8 — INDEPENDENT P009C RED-TEAM AUDIT
## Clean-session verification of Content World Model + Narrative Intelligence

**RECOMMENDED MODEL:** Claude Fable
**SESSION:** NEW CLEAN SESSION
**MODE:** READ-ONLY FIRST
**EFFORT:** High / maximum practical reasoning

Independently determine whether P009C built a real semantic world model or only a label/graph facade.

Do not trust the implementation report.

Verify:
1. P009B lock preserved.
2. Episodes are temporal/revision-aware.
3. Topic graph supports multi-topic and shifts.
4. Entity graph never identifies real people from images or infers sensitive traits.
5. Intent graph preserves ambiguity.
6. Event graph avoids unsupported causality.
7. Narrative preserves historical strong-risk evidence.
8. Contradiction resolver distinguishes conflict from temporal change/quote/satire ambiguity.
9. Evidence weighting does not multiply correlated evidence as independent certainty.
10. Uncertainty can produce UNKNOWN.
11. ContentWorldModelV1 is actually built at runtime from P009B evidence.
12. ContentDNA finalization requires authoritative identity + adequate evidence.
13. DNA revision/invalidation works on split/merge/model/taxonomy changes.
14. Raw text/media cannot leak into durable DNA.
15. Graphs/caches are bounded.
16. Corpus splits are independent enough.
17. Annotation schema matches actual dimensions.
18. Device/in-app claims limited to exercised paths.
19. Score/glyph remain OFF.
20. H1/child blockers remain honest.

Fresh adversarial tests:
- simultaneous topics
- rapid topic shift
- entity ambiguity
- ambiguous intent
- sarcasm vs literal
- quote vs speaker stance
- benign caption + strong risk visual
- risky→benign
- benign→risky
- montage
- B-roll return
- repeated scene
- stale late episode
- provisional item DNA finalize attempt
- confirmed item splits after DNA
- taxonomy-version change
- unsupported language/OOD
- correlated evidence amplification
- raw transcript leakage
- unbounded episode spam
- source-mode mislabel

For each subsystem classify:
VERIFIED / VERIFIED_WITH_LIMITATIONS / PLAUSIBLE_NOT_PROVEN / UNSUPPORTED / CONTRADICTED / BLOCKED.

Required matrix:
Subsystem | Runtime wiring | Eval evidence | Device/in-app evidence | Privacy | Audit verdict

Include:
Episodes, TopicGraph, EntityGraph, IntentGraph, EventStateGraph, NarrativeTimeline, ContradictionResolver, EvidenceWeigher, Uncertainty, WorldModel, ContentDNAFinalizer, DNARevision, Cache, HUD.

Final report:
1. AUDITOR SESSION
2. REPO / BUILD INTEGRITY
3. P009B REGRESSION
4. EPISODES
5. TOPIC GRAPH
6. ENTITY GRAPH
7. INTENT GRAPH
8. EVENT / STATE GRAPH
9. NARRATIVE TIMELINE
10. CONTRADICTION RESOLUTION
11. EVIDENCE WEIGHTING
12. UNCERTAINTY / UNKNOWN
13. CONTENT WORLD MODEL
14. CONTENT DNA FINALIZATION / REVISION
15. PRIVACY / BOUNDEDNESS
16. CORPUS / ANNOTATION METHODOLOGY
17. AUDITOR ADVERSARIAL TESTS
18. DEVICE / IN-APP EVIDENCE
19. OPEN BLOCKERS
20. GO / NO-GO

Final verdict exactly one:
`PASS — P009C CONTENT WORLD MODEL LOCKED; GO TO P009D`
`FIX CRITICAL P009C FINDINGS`
`BLOCKED`

Then STOP.
Do not implement P009D in the audit session.
