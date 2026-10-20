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

    // MARK: RWC-PRE-04 — the PREPARED-DATASET structural gate (closes A11-F2-APIBYPASS / FM-013).
    /// The ONLY constructor of PreparedCalibrationDatasetV1 lives here (fileprivate init, same file):
    /// a future real-world executor can obtain a dataset token EXCLUSIVELY through the canonical
    /// DECLARED → RESOLUTION → IDENTITY INTEGRITY door. Swift access control enforces this — it is
    /// not a naming convention (@testable exposes internal, NOT fileprivate).
    public static func prepareDataset(declaredIDs: [String], resolvedIDs: [String],
                                      category: String = "rwc-asset-resolution") throws -> PreparedCalibrationDatasetV1 {
        // PRE-14 R1 (A14-F5): RWC COMPOSITE GRAMMAR IS PART OF THE DOOR. Deterministic order:
        // (1) grammar on EVERY declared and resolved composite (RWCAssetIdentityV1.parseComposite),
        // (2) exact-identity guard (uniqueness / full resolution / extras), (3) token mint.
        // Exact-but-RWC-invalid identities can therefore NEVER mint a token. No raw echo in errors.
        for (collection, name) in [(declaredIDs, "declared"), (resolvedIDs, "resolved")] {
            var invalid = 0
            var first = -1
            for (i, id) in collection.enumerated() where (try? RWCAssetIdentityV1.parseComposite(id)) == nil {
                invalid += 1
                if first < 0 { first = i }
            }
            if invalid > 0 {
                throw CalibrationIntegrityErrorV1.invalidRWCCompositeIDs(count: invalid, firstIndex: first,
                                                                         category: category + ":" + name)
            }
        }
        try CalibrationRunGuardV1.requireFullResolution(declaredIDs: declaredIDs,
                                                        resolvedIDs: resolvedIDs, category: category)
        return PreparedCalibrationDatasetV1(compositeIDs: declaredIDs, category: category)
    }
}

/// RWC-PRE-04 — a dataset token that PROVES full-resolution integrity by construction.
/// No public/internal initializer exists: `fileprivate init` + same-file `prepareDataset` is the single
/// door. Carries only opaque composite IDs + provenance metadata (no content, no PII).
public struct PreparedCalibrationDatasetV1: Sendable {
    public let compositeIDs: [String]
    public let category: String
    public let guardRevision: String
    public var count: Int { compositeIDs.count }
    fileprivate init(compositeIDs: [String], category: String) {
        self.compositeIDs = compositeIDs
        self.category = category
        self.guardRevision = CalibrationRunGuardV1.revision
    }
}
