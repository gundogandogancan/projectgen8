# OBSERVABILITY SPEC

**Doc status:** `CANONICAL` (spec, no impl) · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** PROMPT 000A §7; Bible §102, §39(P000), §358, §648. **No raw private content in telemetry** (§102, §39 P000).

## Pillars
- **Traces:** correlation/trace id across observation → identity → cache → preflight → admission → presentation; model/version attribution on each span.
- **Metrics:** the P0-A SLO metrics (PRE_EXPOSURE_SLO) + P0-B device metrics (DEVICE_RESOURCE_BUDGETS) + score/calibration metrics (CALIBRATION_PLAN) + social reliability.
- **Logs:** structured, no PII, decision + reason-code + evidence ref + confidence + action (no chain-of-thought — §91).

## Privacy boundaries (hard)
No raw frames/audio/messages in telemetry. Only features/ids/metrics. Energy/cost attribution per decision. Sensitive-surface events recorded as class, not content.

## P0 dashboards
1. **Pre-Exposure (P0-A):** coverage rate, admission p50/p95/p99, cache-hit, first-frame fallback, false allow/hide, UNKNOWN, late-warning, wrong-skip, identity error, temporal alignment error, model disagreement.
2. **Device Health (P0-B):** idle/active CPU-GPU-NPU, memory, battery/hr, energy-per-decision, thermal events, wakeups, network bytes/decision, launch time, UI frame time.
3. **Score/Calibration:** confidence distribution, calibration error, false-warning rate, override rate, drift.
4. **Reliability/Social:** failure-domain health, outage events, publish reconciliation success, wrong-account incidents (0), duplicate incidents (0), entitlement failures, family pairing failures.

## Alert conditions (seed)
false PROTECTED incident (page immediately) · wrong-account publish risk · private-content-in-telemetry detector trip · calibration drift sentinel · thermal-critical sustained · entitlement cross-user anomaly · model rollback triggered.

## Attribution
Every decision carries: model ids+versions, score version, Personal Algorithm version, route decision, energy estimate, cost estimate — enabling reproducibility + cost/energy analysis.

## Phase-0 status
Spec only; no telemetry pipeline. Implemented/validated by OPS-003; feeds release gates.
