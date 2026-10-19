# Runbooks

**Doc status:** `PLACEHOLDER` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §101, §124, §360, §555; Prompt 000 §35, §43.

Operational runbooks are authored as their systems come online (Phase 1+). They are intentionally **not fabricated** in Phase 0 (no services exist yet). Planned runbooks, each to follow the incident flow `PREVENT → DETECT → ISOLATE → DEGRADE SAFELY → RECOVER → VERIFY → LEARN`:

- `model-rollback.md` — bad model pack: QUARANTINE → ROUTER DISABLE → FALLBACK → INCIDENT → ROLLBACK (§35 P000, AI-001).
- `provider-outage.md` — social/billing/model provider down; isolate failure domain (REL-001).
- `wrong-account-or-duplicate-publish.md` — reconcile-before-retry; stop conditions (§520, PUB-001).
- `privacy-incident.md` — suspected raw-content retention/leak; containment + deletion propagation (PRI-001).
- `security-incident.md` — token/key compromise; rotation + kill switch (SEC-001).
- `family-abuse-report.md` — anti-coercion escalation; consent revoke (CHD-001, §548).
- `calibration-drift.md` — score drift sentinel trips; shadow/canary/rollback (§69, §272).
- `capability-regression.md` — platform update breaks a verified capability; re-verify + downgrade tier (§209, D-0004).

Each runbook will link its requirement ID(s), owner, detection signal (observability metric), and rollback.
