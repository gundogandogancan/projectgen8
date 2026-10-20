# RWC-PRE-10 — SLICES + MINIMUM POWER

Canonical machine registry: `RWC_SLICE_DEFINITIONS.yaml` (21 slices; overlapping membership expected
and lawful). Per slice: inclusion rule, min n (default 60), min positive/negative where class-relevant
(default 15/15), reported metrics, safety metric, CI method. POWERED = all minimums met; otherwise
UNDERPOWERED -> metrics reported as UNKNOWN/INSUFFICIENT_DATA with observed n; a gate can NEVER pass on
an underpowered slice and an underpowered slice can NEVER be hidden inside an aggregate (aggregate rows
always list which member slices were underpowered). Sentinel slice carries the strictest law
(n >= 150, falseSafe zero-observed + UB <= 2%). Mixed-language is pre-declared scarce: expected
UNDERPOWERED initially - honest UNKNOWN rather than silent pooling.
