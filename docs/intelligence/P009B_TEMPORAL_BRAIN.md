# P009B — Temporal Brain (`TemporalExpertV1`)

**Availability:** REAL_RUNTIME · **Cost:** 1 · **File:** ExpertArmsV1.swift (class — stateful across observations)

- **What:** narrative risk memory across an item's timeline. `observe(riskLevel:topicLabels:)` feeds it
  per-segment; risk is **monotone-max** (`maxRiskSeen`).
- **Escalation law (tested `testTemporalEscalationLaw`):** benign → risky → benign emits
  `temporal:risk-escalated` (threshold 0.6) and the later benign segment can NEVER suppress the earlier
  risk. Risky evidence survives recovery; recovery is additional evidence, not an eraser.
- **Provisional identity:** works on provisional items (`temporal:identity-provisional` marker) — this
  is the ONLY expert domain permitted in `EXTENSION_FAST_TIER0`, consistent with the P009A measured
  truth that extension Tier-0 has temporal-interaction evidence but no reliable semantic channels.
- **No fabrication:** with no observations it reports zero risk with full uncertainty, not "safe".
