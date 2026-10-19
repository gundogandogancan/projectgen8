# P007B — Device Soak Test

## Status: NOT RUN (requires a ~30-min human-operated / instrumented on-device session)
A 30–60 min device soak (short-form churn + cache reuse + long-form + audio/speech + Shield lookups + Control ON/OFF +
background/foreground) requires either a human operating GuardianLab on the device for 30 minutes with Instruments
attached, or an automated UI-test soak harness. Neither is available to a headless agent in this environment.

- The **LAB logic soak** (5,000-swipe churn → return-to-baseline, no leak, <20 cold-loads, no index growth, Live
  Activity spam suppressed) remains green (P007 `P007SoakTests`). It is necessary-not-sufficient; it is NOT device
  energy/thermal/memory-trend evidence.

## Status
`DEVICE_SOAK_PENDING_MANUAL_OR_UITEST_HARNESS; LAB logic soak green`.
