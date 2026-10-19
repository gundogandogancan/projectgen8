# P009B — Safety Evidence (`SafetyEvidenceExpertV1`) — EVIDENCE, NOT VERDICT

**Availability:** REAL_RUNTIME (lexical dimensions only) · **File:** ExpertArmsV1.swift

## Dimension status map (`SafetyEvidenceExpertV1.dimensionStatus` — single source of truth, test-asserted)

| Dimension | Status |
|---|---|
| sensitive-death-disease-news (TR+EN lexical) | IMPLEMENTED_UNCALIBRATED |
| fear-threat language | HEURISTIC_SUPPORT_ONLY |
| violence-injury-visual | **UNAVAILABLE (H1 — carried open blocker)** |
| explicit-sexual-visual | **UNAVAILABLE (H1)** |
| self-harm | UNAVAILABLE |
| drugs | UNAVAILABLE |
| gambling | UNAVAILABLE |
| dangerous-acts | UNAVAILABLE |
| profanity-context | UNAVAILABLE |

## Laws (all test-asserted)

1. Every evidence record appends `safety:H1-visual-dimensions:UNAVAILABLE` — the gap is visible in
   every output, not hidden in docs (`testSafetyDimensionTagsAndH1Open`).
2. No lexical signal → `safety:no-lexical-signal (NOT a safe verdict)` with confidence 0. Absence of
   weak evidence is never a safe conclusion.
3. In the cross-modal graph, safety-critical risk evidence DOMINATES positive evidence
   (`contradicts` edge, "no vote") — benefit evidence can never average away a safety signal.
4. Child policy remains contract-only; no child-specific inference exists in P009B.
5. No calibrated severity: everything is evidence strength, uncalibrated, score display structurally OFF.
