# RWC-PRE-10 — SLICES + MINIMUM POWER

Canonical machine registry: `RWC_SLICE_DEFINITIONS.yaml` (21 slices; overlapping membership expected
and lawful). Per slice: inclusion rule, min n (default 60), min positive/negative where class-relevant
(default 15/15), reported metrics, safety metric, CI method. TRI-STATE POWER LAW (v2, A14-F8): REPORTABLE = min_n met (metrics + debiased gap + CI,
NO pass/fail authority); GATE_POWERED = slice n >= 800 per the frozen power law (hard calibration
gate applies; initially NO slice qualifies - honest); UNDERPOWERED -> metrics reported as UNKNOWN/INSUFFICIENT_DATA with observed n; a gate can NEVER pass on
an underpowered slice and an underpowered slice can NEVER be hidden inside an aggregate (aggregate rows
always list which member slices were underpowered). Sentinel slice carries the strictest law
(n >= 150, falseSafe zero-observed + UB <= 2%). Mixed-language is pre-declared scarce: expected
UNDERPOWERED initially - honest UNKNOWN rather than silent pooling.

V2 ADDENDUM: per-slice decision_coverage is reported; multiplicity classes live in the gate
registry (safety-sentinel = SAFETY_HARD_GATE; others DIAGNOSTIC until gate-powered).
