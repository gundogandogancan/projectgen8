# P009C-R1 — Leakage Auditor V2

`P009CLeakageAuditorV2` (V1 rules remain in force) adds: Unicode-normalized language-aware token
3-shingles (template-shingle leak at J>0.5 + same template fingerprint), authored-template fingerprints
(family + segment count + per-segment modality combo), **translation-equivalent template IDs**
(`P009CScenarioV1.templateID` — the same authored template may never appear in two splits, translated or
not; all current scenarios are independently authored ⇒ nil), phrase overlap via shingles, and
structural event-sequence fingerprints (risk/topic shape per segment; flagged when structure + template +
shingle overlap coincide). CAL_RESERVED (P009B bank) is consumed as fingerprint metadata only — unchanged.

Result on the current banks: **0 violations** (`testLeakageAuditorV2Clean`); detector sanity proven with
a planted equivalent (`testLeakageAuditorV2CatchesTranslationEquivalentTemplate`).

Declared limitation: cross-language SEMANTIC near-duplication (same meaning, fully different words) is
detectable only via templateID discipline — authored metadata, not text analysis. This is stated, not hidden.
