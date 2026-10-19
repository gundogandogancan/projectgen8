# P008 — Personal Algorithm V2 + ContentDNA V5 + Correction Loop
ContentDNA V5 (§36) stores NON-PERSONAL understanding only: identity, multimodal topics, scene timeline, safety signals,
attention signals, learning/utility evidence, model revisions, evidence coverage. It must NOT store the user's Shield
rules, personal suitability score, or profile. Personal score is projected LOCALLY: `ContentDNA + PersonalPolicy →
PersonalSuitability`. Moat: ONE expensive content understanding, MANY cheap personal decisions.
Personal Algorithm V2 (§37) inputs ONLY from explicit user settings / My Shield / explicit positive-exposure mode /
explicit goals / user-permitted corrections. **Never silently infers religion, politics, health, sexual orientation,
or other sensitive identity.** Correction loop (§38) mutates LOCAL policy/calibration-preference only; no uncontrolled
self-rewriting; no automatic global training from private corrections.
