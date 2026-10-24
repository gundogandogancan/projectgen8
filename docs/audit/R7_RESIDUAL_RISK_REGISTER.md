# GEN8 RWC PRE-14 R7 — RESIDUAL RISK REGISTER (post-closeout)

Location: `docs/audit/` (UNGOVERNED by freeze V8 — not a governed_root, not a frozen artifact; lawful to add).
Created by the PRE-14 PASS-lock closeout. This register does NOT close any finding; it records open residuals
and their targeted remediation so a later authorized lane can address them. The closeout PASS does NOT claim
A21-F5 is closed.

---

## A21-F5 — LOW (open, targeted, non-blocking) — report-fidelity gap in receipt finalization

- **Severity:** LOW (AUDIT21's single finding; did NOT block the security PASS).
- **Location:** `packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV5.swift`
  `ensureReceipt` (AUDIT21 report cites ~L181–197) / `reconcileV5`.
- **Exploit / behavior:** When the receipt directory write fails (disk full / read-only / IO error),
  `reconcileV5` can still append the session to the in-memory `finalizedReceipts` report via a `try?`-swallowed
  finalize, while the DURABLE receipt remains `.prepared`. The transient report line says "finalized"; durable
  state does not.
- **Why NOT a security bypass:** No unauthorized promotion occurs; the durable receipt is NEVER falsely marked
  `.completed`; there is no production consumer of this path yet (zero-data). It is a report↔durable-state
  fidelity gap, not an authority breach.
- **Minimum targeted fix (do NOT author a new architecture version):**
  1. Append to `finalizedReceipts` ONLY when `complete()` ACTUALLY succeeds — move the append out of the
     `try?` path into a non-`try?` do/catch, OR reload the receipt before the append and assert
     `state == .completed`.
  2. On a failed completion in the stored-asset path, report an explicit `receiptDeficit` (quarantine /
     retry / deficit) BEFORE any quarantine is deleted, so an incomplete receipt is surfaced, not silently lost.
- **Constraints:** `RWCCorpusAcquisitionRunnerV5.swift` is a FROZEN V8 production source (governed root
  `packages/GuardianKit/Sources/RWCAcquisition`). The fix is an in-place edit of the existing function — but
  because the file is frozen, it requires the narrow-scope V8 **supersession** process (new candidate +
  freeze re-census + fresh lock) under an authorized round. It MUST NOT be edited inside this closeout, and it
  does NOT by itself justify a general new audit cycle.
- **Scheduling:** Address BEFORE real operational ingress is enabled (lane B). Until then it is dormant
  (no durable corpus writes occur under zero-data).

---

## Accepted residual threats carried from AUDIT21 (documented, not newly opened)

| ID | Nature | Status |
|---|---|---|
| R-5 | Hostile-disk rollback window | Explicitly bounded; never silently promoted to PASS. Accepted residual. |
| in-package token construction | `RWCAcquisitionAuthorityTokenV1` init is `package`-scoped → unreachable by any external consumer (compile-negative proven). Production-unreachable residual, documented. |
| A21-F5 | Report-fidelity gap (above) | LOW, open, targeted pre-ingress. |

---

## Explicitly NOT residual-risk (closed / never-opened by design)

- Zero-data invariants (corpus/annotator/real_fit/heldout = 0; data_visibility=false) — enforced by
  VerifierV6 before minting and re-asserted by the closeout transition probe.
- Operational reviewer trust root — absent; `loadProduction` fails closed `.noOperationalRoot`.
- AUDIT20 root causes A20-F1..F4 — closed and independently re-verified by AUDIT21 (not residual).
