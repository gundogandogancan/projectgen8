# RWC-PRE-01 — RIGHTS / DATA GOVERNANCE FREEZE (governance only; ZERO assets)

Deliverables: machine schema `RWC_ASSET_RIGHTS_LEDGER_SCHEMA.yaml` + fail-closed code twin
`RWCAssetRightsLedgerV1.swift` (+ tests). Eligible source classes are EXACTLY PROJECT_OWNED_REAL and
LICENSED_RIGHTS_CLEAR; four refused classes are enumerated so refusal is an explicit state, never an
omission. Forbidden logic is codified (schema `forbidden_logic`), including the
"publicly visible = free to train" fallacy. Eligibility is FAIL-CLOSED per use ("training"/"evaluation";
UNKNOWN use never passes). Revocation is monotone (no un-revoke path; resurrection = new registration +
new evidence). Lifecycle and privacy/minimization laws are in the schema; diagnostics carry opaque IDs +
reason codes only. ZERO assets were acquired in this phase (manifest `corpus_count = 0` is load-bearing).
