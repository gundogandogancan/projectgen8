# P007 — Device Resource Evidence

## No-material-degradation gate: **NOT_MEASURED** (device) / **LAB_NO_OBVIOUS_DEGRADATION** (lab logic)

Per §19/§20: real device CPU/memory/thermal/energy/UI-frame metrics require a provisioned on-device run, which is
blocked by the signing-team dependency (see P007_DEVICE_AND_SIGNING_ENVIRONMENT). **No physical-device metric is
fabricated.** All device budget fields remain UNSET in DEVICE_RESOURCE_BUDGETS.yaml.

| Metric | LAB (logic-level) | DEVICE |
|--------|-------------------|--------|
| idle_cpu | n/a (no idle loop; event-driven) | NOT_MEASURED |
| idle_wakeups | n/a | NOT_MEASURED |
| active_cpu | warm Shield decision ~0.2 ms compute; flat under churn | NOT_MEASURED |
| memory_high_water | task/media ledger returns to baseline after 5,000-swipe soak (no growth) | NOT_MEASURED |
| thermal_state | DeviceCapabilityProfile downgrades to eco on serious/critical (tested) | NOT_MEASURED |
| energy_impact | — ("no zero-battery" language; not claimable without device) | NOT_MEASURED |
| decision_latency | LAB full-pipeline p95 0.398 ms (modeled media) | NOT_MEASURED |
| ui_frame_time | — | NOT_MEASURED |
| decode_count / ocr_count / speech_windows | bounded by ComputeBudget plan | NOT_MEASURED |
| model_invocations | ModelLifecycleV2: ≤1 cold-load per model + warm reuse (soak: <20 cold-loads over 5,000 iters) | NOT_MEASURED |

## Gate verdict
- **LAB_NO_OBVIOUS_DEGRADATION** at the logic level: bounded per-item compute, warm model reuse, task/media ledger
  drains to baseline, no index/cache growth, Live Activity updates suppressed (no spam). (P007 soak + leak tests.)
- **DEVICE: NOT_MEASURED** — a real idle/short-form/long-form/audio/soak run on the connected iPhone 14 Pro Max is the
  next step once signing is wired. No `DEVICE_WITHIN_CURRENT_BUDGET` claim is made.
