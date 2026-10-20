import Foundation

// MARK: - R1 (A10-F2-WIRING) — the CANONICAL calibration-run preparation pipeline.
//
// LAW: NO REQUIRED CALIBRATION RECORD MAY BE SILENTLY DROPPED.
// This is the single lawful door between a DECLARED ledger and any fit/metric stage:
//
//   DECLARED (registry pairs)
//     ↓ resolve EVERY pair (caller-supplied resolver; nil = unresolved, recorded — never skipped)
//   RESOLUTION
//     ↓ CalibrationRunGuardV1.requireFullResolution (exact-identity + uniqueness, typed throws)
//   INTEGRITY GATE
//     ↓ only on success do resolved records EXIST for the caller
//   FIT → METRICS
//
// A caller cannot reconstruct the silent-drop shape (`guard … else { continue }`) through this API:
// records are returned ONLY after the integrity gate passes; any unresolved, duplicate, malformed or
// mismatched identity aborts the entire run with CalibrationIntegrityErrorV1 BEFORE fitting is
// reachable. Diagnostics carry only opaque composite IDs + counts + category (no content, no PII).

public enum CalibrationRunPreparationV1 {
    public static let version = "calibration-run-preparation-v1"

    /// Canonical composite identity of a calibration pair: item × profile (the registry's uniqueness
    /// unit — see CalibrationDatasetRegistryV2, which was authored to avoid item+profile duplicates).
    public static func compositeID(_ pair: CalibrationPairV1) -> String {
        pair.itemID + "#" + pair.profile.profileID
    }

    /// Resolve the FULL declared ledger or refuse the run. Returns one resolved record per declared
    /// pair, in declared order, iff EVERY pair resolved and identities match exactly.
    public static func prepare<Resolved>(declared: [CalibrationPairV1],
                                         category: String = "scenario-resolution",
                                         resolve: (CalibrationPairV1) -> Resolved?)
        throws -> [(pair: CalibrationPairV1, resolved: Resolved)] {
        let declaredIDs = declared.map(compositeID)
        var resolvedIDs: [String] = []
        var records: [(pair: CalibrationPairV1, resolved: Resolved)] = []
        for pair in declared {
            if let r = resolve(pair) {
                resolvedIDs.append(compositeID(pair))
                records.append((pair: pair, resolved: r))
            }
        }
        try CalibrationRunGuardV1.requireFullResolution(declaredIDs: declaredIDs,
                                                        resolvedIDs: resolvedIDs, category: category)
        return records
    }
}
