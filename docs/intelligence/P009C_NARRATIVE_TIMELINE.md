# P009C — Narrative Timeline (`NarrativeTimelineV1`)

Handles: topic shifts (event-graph `event:topic-shift`), risk escalation (`registerRisk` — monotone,
includes the temporal expert's historical memory), recovery/de-escalation (observed via CURRENT-moment
risk < 0.2 while maxRiskSeen stays untouched), repeated motifs + scene returns (`motifs()`), montage
(rapid shifts + edit density), B-roll (interview→broll→interview topic script), CTA-near-end detection,
unresolved endings.

**Law (test: `testRiskyToBenignPersistence`, stress `sc-long-risk-tail` — 8 benign segments vs 1 strong
risk):** historical strong-risk evidence remains part of the narrative; later benign evidence cannot
erase it. Recovery is recorded as `narrative:recovery-observed (historical risk retained)`.

**Reinterpretation law (test: `testTemporalReinterpretationRequiresProvenanceAndAmbiguity`):** later
context may reinterpret earlier evidence ONLY when the earlier state was ambiguous-class AND explicit
provenance is supplied; strong earlier states are never reinterpretable away.

Design note: segment risk is split into CURRENT (non-temporal families) and HISTORICAL (temporal
expert's monotone max). Both escalate; only CURRENT can show recovery — this is what makes
"risky→benign" observable without ever weakening the escalation record.
