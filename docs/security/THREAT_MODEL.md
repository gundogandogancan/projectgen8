# THREAT MODEL

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §99–§100, §359, §366, §67; Prompt 000 §38.

## Assets to protect
User identity/accounts · OAuth tokens · personal profile/Growth Twin · raw screen/audio (ephemeral) · family relationships & child data · entitlement state · model packs · evidence/cache integrity · publish pipeline (external side effects).

## Threats (STRIDE-ish, from Bible §99, §366)
| Threat | Vector | Primary mitigation |
|---|---|---|
| Account takeover | credential/token theft | OAuth/PKCE, short-lived tokens, MFA for admin, device trust |
| Token theft | insecure storage | hardware-backed keychain/keystore vault; no secrets in repo |
| Screen-data leakage | capture pipeline | ephemeral frames, on-device features, no default archive, redaction |
| Prompt injection | malicious content as instruction | **external content = DATA, never instruction** (§67); Prompt Defense Baseline on every agent |
| Content/model poisoning | adversarial inputs / bad packs | data-poisoning defense (§269), signed packs + checksum + eval gate (§35 P000) |
| Score gaming / feedback fraud | keyword stuffing, coordinated feedback | adversarial immune system (§67), feedback = evidence not truth |
| Family abuse / coercion | false guardian, covert monitoring | AntiCoercionGuardian (§548), explicit adult consent, revoke |
| Supply-chain compromise | dependency / build | SBOM, dependency scanning, signed builds |
| Cache corruption | integrity | checksums, rebuild on corruption (CACHE_FAILURE) |
| Malicious update | model/app update | signed manifests, rollback artifact, canary |
| Provider API compromise | social/billing provider | webhook signature + replay defense, isolate failure domain |
| Insider access | privileged misuse | least privilege, immutable security audit, key rotation |
| Wrong-account / duplicate publish | publish pipeline | account identity firewall, idempotency, reconcile-before-retry (§326) |
| Entitlement leak | cross-user | account-level entitlement, no cross-user leak (hard stop §520) |

## Security design requirements (SEC-001)
OAuth/PKCE + state/nonce · secure token vault · hardware-backed keys where available · least privilege · webhook signature/replay defense · device trust · signed models + SBOM + dependency scanning · admin MFA · immutable security audit · key rotation · kill switches · rollback. **Crypto-agility** (§100): replaceable crypto suites + migration strategy; never promise "quantum-proof forever"; don't hardcode one primitive across all persisted formats.

## Adversarial test obligations (Bible §67, §122)
prompt injection · hidden text/instructions · keyword stuffing · fake citations · source laundering · misleading thumbnail · adversarial imagery · fake transcript · deepfake · score gaming · coordinated feedback manipulation · data/model poisoning. Each becomes a regression case in Failure Memory (§66).

## Hard stops (subset of §520)
security incident + high traffic unhandled · token/key compromise unmitigated · wrong-account publish risk · uncontrolled self-modification · entitlement leak. Any present ⇒ **no release**.

## Phase-0 status
Design baseline only. Secrets management policy: **no secrets in repo** (enforced from day one). Mitigations proven by SEC-001, PUB-001, FAM-001/CHD-001, AI-001 in later phases.
