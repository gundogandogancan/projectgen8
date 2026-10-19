# REAL-WORLD CALIBRATION — CONSTITUTION v1 (pre-entry; NO fitting yet) — 2026-10-20
Workstream branch: phase/real-world-calibration. Execution DAG (§35 constitution) has NO canonical next-phase ID for this program — ADR note: this is the temporary canonical WORKSTREAM branch; no invented P010 number.

## ENTRY GATE — A9-R1-F1/F2/F3 execution plans (close BEFORE any real-data fitting)
F1: LAW "UNAVAILABLE AGE EVIDENCE != AGE_ALIGNED". Plan: reuse ChildAgeOutcomeV1.unknownReview (no duplicate concept — existing enum scanned); extend fail-closed scope in ChildAgePolicyEngineV1: if an evidence-present dimension is UNBANDABLE for the profile band (e.g. violence class via strong-risk signals) OR TeenBandFailClosedPolicyV1 trigger beyond the sexual class -> outcome floor unknownReview. Strong-protection state untouched; zero safety loosening. Fresh tests: {teen13+, teen-strict, under-13, adult} x {violence/gore, sexual sentinel, fear/threat, H1-unavailable} + strong-risk universal protection.
F2: silent-drop FORBIDDEN. Plan: harness resolution returns typed outcome; declaredCount != resolvedCount -> typed INTEGRITY_FAILURE, fitting/eval REFUSES, zero metrics emitted. Test: inject 1 unresolved record -> hard refusal (no 58/59 silent metrics).
F3: metric domain contract. Plan: predictions must be finite in [0,1]; NaN/+inf/-inf/<0/>1 -> typed invalid-input REJECT (never silently clamped into the denominator); boundary semantics documented: bin = min(bins-1, floor(p*bins)). Tests: -0.001, 0, 0.1, 0.3, exact edges, 0.999999, 1, 1.001, NaN, +/-inf; no drop, no double count, no silent clamp.

## CORPUS POLICY (locked pre-data)
Only PROJECT_OWNED_REAL or LICENSED_RIGHTS_CLEAR. No scraping; no unauthorized platform capture; no user-private content repurposed. Asset ledger fields: assetID, source, owner, license, allowedUse, language, contentType, acquisitionDate, expiry, revocation, hash, derivativeRights.

## HUMAN ANNOTATION ARCHITECTURE
>=2 TRUE independent human annotators per item; mutual blindness (each other's labels+rationales, model predictions, final scores). Third adjudicator is not A or B. Versioned handbook with TR/EN semantic parity covering: every score dimension, ordinal labels, safety precedence, ambiguous cases, abstention, H1-unavailable handling, age interpretation, Shield interpretation, satire/sarcasm, mixed language, OCR/subtitle conflict, violence/gore, manipulation, fear, sexual/sensitive, educational, documentary/news.

## IRR (predeclared BEFORE any data result)
Ordinal suitability dimensions: Cohen's weighted kappa (quadratic), minimum 0.60 per dimension. Binary safety dimensions: Krippendorff alpha, minimum 0.67. Below threshold -> dimension/slice INSUFFICIENT_DATA (never aggregated away).

## SLICES (predeclared minimum n; underpowered -> UNKNOWN/INSUFFICIENT_DATA; never hidden behind aggregates)
TR, EN, child, teen, adult, Shield-ON, Shield-OFF, violence, sexual/sensitive, manipulation, fear/threat, benefit/educational, news/documentary, mixed-language, OOD, safety-sentinel, per content-type/modality.

## SPLIT ARCHITECTURE
TRAIN / CALIBRATION / HELD_OUT_FINAL / STRESS / OOD / SAFETY_SENTINEL. Item disjointness + semantic near-duplicate disjointness. HELD_OUT_FINAL: selected BEFORE fitting, manifest written, SHA-sealed. If after opening it any of {weights, thresholds, feature engineering, rubric, split policy} changes -> it is no longer final evidence; a NEW sealed final set is required.

## PREDECLARED GATES (methodology)
Candidate values from the audit plan (falseSafe=0; risk ECE <=0.05 overall; <=0.07 per sufficiently-powered slice) are NOT blindly adopted: finalize only after statistical feasibility analysis (sample sizes, confidence intervals, base-rate sensitivity, safety cost) and BEFORE seeing data results. Gates can never be relaxed after results. AUROC is never a substitute for ECE or false-safe.

## DEVICE EVIDENCE (separate classes, all required)
End-to-end on physical device: real rights-clear input -> perception -> identity -> cognition -> policy -> calibration -> admission -> explanation. Measured separately: CPU, memory, energy, thermal, latency, wakeups, battery impact, privacy leakage, logging.

## PRESENTATION
Production numeric score, glyph, motion, authoritative recommendation UI: BLOCKED until this program passes its gates + independent final audit. Debug/internal views must show epistemic status explicitly.

## RISK REGISTER / TRACEABILITY
Risks: annotator recruitment+cost; rights revocation; TR/EN parity drift; underpowered safety slices; sentinel-set sufficiency; device thermal unknowns; rollback = gen8-p009e-r1-locked-engineering-only. Traceability: this constitution -> ledgers -> tests -> independent audits.
