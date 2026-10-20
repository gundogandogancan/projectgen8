# RWC-PRE-04 — FUTURE EXECUTOR CANONICAL GATE (closes A11-F2-APIBYPASS / NT-APIBYPASS / FM-013)

Structure (not naming convention - Swift access control):
- `PreparedCalibrationDatasetV1`: fileprivate init inside CalibrationRunPreparationV1.swift; the ONLY
  door is `CalibrationRunPreparationV1.prepareDataset` which runs the full exact-identity gate
  (malformed/duplicate/missing/extra/multiset - guard v2) BEFORE the token exists. `@testable` exposes
  internal, NOT fileprivate - even in-module tests cannot forge the token.
- `RealWorldCalibrationExecutorV1.execute(_:)` accepts ONLY the prepared token. Raw records, pair
  arrays, partial ledgers and pilot types cannot enter: no conversion API exists.
- DOUBLE TYPED REFUSAL this round: (1) `preregistrationNotPassed(RWC-PRE-14)` while
  `preregistrationAuditPassed == false` (flippable only by a post-PRE-14 evidence-bearing commit with a
  resolution-ledger record - flipping without evidence is FM-003-class); (2) even past the flag,
  `fitPhaseNotAuthorized(RWC-FIT)` until the RWC-FIT packet lands the lawful strict-metrics body.
  ZERO fitting is reachable in this program by construction.
R1 CORRECTION (A14-F5): at candidate 1c4160b the door did NOT validate RWC grammar - exact-but-invalid
IDs minted tokens (AUDIT14 proof). FIXED: prepareDataset now runs RWCAssetIdentityV1.parseComposite on
EVERY declared and resolved composite BEFORE the exact-identity guard (typed invalidRWCCompositeIDs,
count/index-only diagnostics). Bypass matrix (tests): unresolved pair / duplicate / missing / extra /
bad asset ID / partial dataset / raw-record injection -> no PreparedCalibrationDatasetV1 ever exists ->
executor unreachable.
