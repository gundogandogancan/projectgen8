# FAILURE TAXONOMY

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §58(P000), §101, §124, §360; Prompt 000 §58. Rule: **FAIL SAFE + FAIL HONEST.** Every user-visible failure has a defined safe UX state; never show a stale safe/green state (Bible §14 anticipatory, §101).

| Code | Meaning | Default safe behavior | User-visible state | Owner |
|---|---|---|---|---|
| `CAPABILITY_FAILURE` | platform can't do what a tier claims | downgrade tier; never show PROTECTED | "Limited coverage on this surface" | capability |
| `PERMISSION_FAILURE` | required permission missing/revoked | pause capture; request/explain | "Guardian paused — permission needed" | perception/privacy |
| `IDENTITY_FAILURE` | content identity unknown/conflicting | no high-impact action; mark UNKNOWN | grey `?` | identity |
| `CACHE_FAILURE` | cache miss/corrupt | rebuild; fall back to fresh/deterministic | transparent (slower) | content-intelligence |
| `MODEL_FAILURE` | model error/unavailable | router fallback; QUARANTINE→DISABLE→ROLLBACK | lower confidence / "analyzing" | model-router |
| `CONFIDENCE_FAILURE` | below threshold | abstain; show `?` / "insufficient evidence" | `?` | score-kernel |
| `PRIVACY_FAILURE` | sensitive surface / redaction risk | deny/pause processing; discard raw | "Protected area — not analyzed" | privacy |
| `SECURITY_FAILURE` | token/auth/signature anomaly | revoke/short-circuit; incident | "Reconnect needed" / block | security |
| `TEMPORAL_ALIGNMENT_FAILURE` | timeline/segment mismatch | downgrade skip→WARN/ASK; no blind seek | "Can't verify this timestamp" | temporal |
| `ENTITLEMENT_FAILURE` | entitlement check fails | grace per policy; never cross-user leak | "Checking subscription…" | entitlement |
| `FAMILY_AUTHORITY_FAILURE` | guardian authority unverified | deny child-mode change; escalate | "Guardian approval required" | family |
| `PROVIDER_API_FAILURE` | social/provider API down/changed | mark UNAVAILABLE; open-in-platform fallback | "Platform unavailable" | social |
| `RECONCILIATION_FAILURE` | publish state unknown after send | reconcile before any retry; no dup | "Confirming publish…" | publishing |
| `BATTERY_THERMAL_LIMIT` | thermal/battery budget exceeded | downgrade to ECO; event-driven only | "Guardian in battery-saver" | resource-governor |
| `NETWORK_FAILURE` | offline/degraded | local Guardian mode | "Offline — local protection active" | reliability |
| `OUTAGE` | one failure domain down | isolate; degrade safely | domain-specific safe state | reliability |
| `DATA_RIGHTS_BLOCK` | reuse not permitted | deny global reuse; local-only | transparent | data-rights |
| `UNKNOWN` | unclassified | safest default; log for failure memory | `?` | all |

## Compound/disaster scenarios (Bible §124)
Test combinations, e.g.: capture corruption + wrong identity + stale cache; prompt injection + weak evidence + high-risk health claim; cloud outage + local model regression; revoked permission + stale score; compromised family account + visibility bug; model release + calibration drift; provider shutdown + schema change. Flow: `PREVENT → DETECT → ISOLATE → DEGRADE SAFELY → RECOVER → VERIFY → LEARN`. Every significant failure becomes a `FailureCase` with a regression test (Bible §66) and is re-run on new releases.

## Hard stop conditions (Bible §125, §520) — do NOT release if present
raw sensitive screen retention uncontrolled · content identity wrong at unsafe rate · score not reproducible · confidence hidden · unsupported health/finance certainty · family-abuse path unresolved · platform policy violation · uncontrolled self-modification · severe calibration failure · delete/revoke incomplete · wrong-account publish risk · duplicate-publish risk · **false PROTECTED state**.
