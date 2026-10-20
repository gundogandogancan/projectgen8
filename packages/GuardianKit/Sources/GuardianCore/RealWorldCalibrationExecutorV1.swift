import Foundation

// MARK: - RWC-PRE-04 — REAL-WORLD CALIBRATION EXECUTOR (structural surface; EXECUTION FORBIDDEN).
//
// LAW:
//  - This is the ONLY lawful real-world calibration execution surface. It accepts EXCLUSIVELY
//    `PreparedCalibrationDatasetV1` — a token constructible only inside CalibrationRunPreparationV1
//    (fileprivate init). Raw records, partial ledgers, pair arrays, or pilot-era types CANNOT enter:
//    no API exists to convert them, and the token cannot be forged (A11-F2-APIBYPASS / FM-013 closure).
//  - The legacy P008 pilot surface (see PRE-03 retirement law in CalibrationPilot.swift) is a
//    different, ENGINEERING-ONLY type world: this executor references none of it, and no bridge exists.
//  - PREREGISTRATION REFUSAL: until the independent RWC-PRE-14 preregistration audit PASSES, execution
//    is a TYPED refusal. `preregistrationAuditPassed` may be flipped ONLY by a post-PRE-14
//    evidence-bearing commit (resolution-ledger record + audit ref) — flipping it without that evidence
//    is an FM-003-class violation the re-audit must catch.
//  - Even after PRE-14, the FIT body lands only with the RWC-FIT phase packet (strict typed metrics
//    only: eceAndBinsStrict / maeStrict / aurocStrict). Until then the second refusal holds.

public enum RWCExecutorErrorV1: Error, Equatable {
    case preregistrationNotPassed(requiredGate: String)
    case fitPhaseNotAuthorized(requiredNode: String)
    case emptyDataset
}

public enum RealWorldCalibrationExecutorV1 {
    public static let version = "rwc-executor-v1"
    /// Flipped ONLY by post-PRE-14 evidence (resolution ledger + independent audit ref).
    public static let preregistrationAuditPassed = false

    /// The single real-world execution entrypoint. Today: typed refusal, always.
    public static func execute(_ dataset: PreparedCalibrationDatasetV1) throws {
        guard !dataset.compositeIDs.isEmpty else { throw RWCExecutorErrorV1.emptyDataset }
        guard preregistrationAuditPassed else {
            throw RWCExecutorErrorV1.preregistrationNotPassed(requiredGate: "RWC-PRE-14")
        }
        // Structurally unreachable until PRE-14 PASS; kept as a second typed refusal so that flipping
        // the flag alone still cannot fit anything before the RWC-FIT packet lands the lawful body.
        throw RWCExecutorErrorV1.fitPhaseNotAuthorized(requiredNode: "RWC-FIT")
    }
}
