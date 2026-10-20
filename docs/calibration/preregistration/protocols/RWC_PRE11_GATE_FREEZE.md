# RWC-PRE-11 — METRIC/GATE FREEZE (feasibility -> FREEZE -> data visibility)

Canonical frozen registry: `RWC_FROZEN_GATES.yaml` (machine). Binding order honored: PRE-09 feasibility
and PRE-10 slice power preceded this freeze; data visibility is FALSE at freeze (declared in-file and in
the freeze manifest). Every gate carries threshold + scope + CI law. Rejected/modified candidate gates
are documented WITH reasons (AUROC hard gate rejected; all-slice ECE modified to powered-only; bare
zero-false-safe strengthened with rule-of-three UB; strong-protection alpha tightened to 0.80).
Post-result relaxation is forbidden forever; material post-result change triggers the invalidation law
(new prereg + new seal). ECE <= .05 remains the known-hard target (BLK-ECE-UNMET carries: engineering
value is .250 - the gate is honest, not optimistic).
