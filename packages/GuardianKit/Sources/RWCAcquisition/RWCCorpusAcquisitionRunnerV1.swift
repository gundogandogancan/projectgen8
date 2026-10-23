#if os(macOS)
import Foundation
import CryptoKit
import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC CORPUS ACQUISITION RUNNER V1 (A16-F21/§40-§44) — the ONLY lawful future first-asset path.
//
// FIRST-ASSET ORDERING LAW (frozen; enforced by control flow AND by types):
//   1. global authority    — requires RWCVerifiedCorpusEntryV3 (unforgeable; §52 verifier) — the
//                            function cannot even be CALLED without it (type-level gate).
//   2. legal grant         — requires RWCVerifiedRightsGrantV1 (review-boundary minted) matching
//                            the intended record; validated BEFORE any byte moves.
//   3. asset identity      — opaque asset ID validated BEFORE any byte moves.
//   4. acquisition session — created; receipt pre-binds all authority identities.
//   5. ONLY THEN           — the acquirer callback may run; raw bytes land in an EPHEMERAL
//                            QUARANTINE directory, never in the corpus store.
//   6. content hash        — SHA-256 of quarantined bytes must equal the declared record hash.
//   7. rights commit       — atomic durable commit to RWCAssetRightsLedgerStoreV3 (journal+witness).
//   8. promote             — only AFTER a successful rights commit is the asset promoted from
//                            quarantine into the corpus store.
//   9. receipt             — immutable acquisition receipt referencing PASS-lock/audit/freeze/grant
//                            identities, asset ID, content hash and the rights-ledger head.
//   Any failure at any stage: quarantine is DESTROYED; nothing is promoted.
//
// TRANSACTION / RECONCILIATION LAW (§43):
//   • fetch fails / hash mismatch / rights refusal  → quarantine destroyed, no corpus asset,
//     no rights event beyond what atomically committed (refusals commit nothing).
//   • rights committed but promote fails/crashes    → the asset is rights-registered and the
//     corpus store lacks it: `reconcile` detects registered-but-unpromoted assets deterministically
//     from (ledger state, corpus store listing, surviving quarantine) and either re-promotes a
//     hash-verified quarantined payload or reports an explicit unpromoted deficit. NO orphan raw
//     media can exist without an authoritative rights record (bytes only ever live in quarantine
//     before the rights commit, and quarantine is destroyed on failure).
//
// NO PRE-AUTH ACQUISITION (§42): there is no code path to the acquirer callback before stages 1-4.
// ZERO-DATA: R3 exercises this with synthetic fixtures only; no network type is defined here.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

public enum RWCAcquisitionErrorV1: Error, Equatable, Sendable {
    case grantRecordMismatch
    case contentHashMismatch(expected: String, actual: String)
    case quarantineFailure(String)
    case promoteFailure(String)
    case corpusStoreFailure(String)
}

/// Raw-byte source boundary (future: licensed download/copy tooling; tests: spies/fixtures).
public protocol RWCAssetAcquirerV1 {
    func fetch(sourceReference: String) throws -> Data
}

/// Corpus persistence boundary (future: sealed corpus store; tests: temp-dir fixture).
public protocol RWCCorpusStoreV1 {
    func promote(assetID: String, contentHash: String, payload: Data) throws
    func storedAssetIDs() throws -> [String]
}

/// Immutable acquisition receipt (§44). Opaque identities and digests only — no raw content.
public struct RWCAcquisitionReceiptV1: Equatable, Sendable {
    public let sessionID: String
    public let assetID: String
    public let contentHash: String
    public let legalGrantID: String
    public let grantRevision: Int
    public let reviewRecordID: String
    public let rightsLedgerHeadDigest: String
    public let rightsEventCount: Int
    public let passLockCandidateCommit: String
    public let passLockTagObjectSHA: String
    public let auditResultBlobSHA256: String
    public let freezeManifestSHA256: String
    public let methodologyAnchorCommit: String
    public let acquisitionDate: String
}

public final class RWCCorpusAcquisitionRunnerV1 {
    public static let version = "rwc-corpus-acquisition-runner-v1"

    private let quarantineRoot: URL
    public init(quarantineRoot: URL) { self.quarantineRoot = quarantineRoot }

    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// THE first-asset path. Stage order is the law; see header.
    public func acquire(proof: RWCVerifiedCorpusEntryV3,
                        record: RWCAssetRightsRecordV3,
                        verifiedGrant: RWCVerifiedRightsGrantV1,
                        rightsStore: RWCAssetRightsLedgerStoreV3,
                        corpusStore: RWCCorpusStoreV1,
                        acquirer: RWCAssetAcquirerV1,
                        clock: RWCRightsClockV3,
                        sessionID: String) throws -> RWCAcquisitionReceiptV1 {
        // stages 1-2: global proof is the parameter type; grant must match the record BEFORE bytes.
        guard verifiedGrant.grant == record.grant else { throw RWCAcquisitionErrorV1.grantRecordMismatch }
        try RWCRightsReviewAuthorityV1.validateGrant(record.grant)
        // stage 3: asset identity before bytes.
        if let e = RWCAssetIdentityV1.validateAssetID(record.assetID) {
            throw RWCRightsErrorV3.invalidAssetID("\(e)")
        }
        // stage 4: session quarantine directory.
        let quarantine = quarantineRoot.appendingPathComponent("rwc-quarantine-\(sessionID)")
        do {
            try FileManager.default.createDirectory(at: quarantine, withIntermediateDirectories: true)
        } catch { throw RWCAcquisitionErrorV1.quarantineFailure("\(error)") }
        var promoted = false
        defer {
            // any non-promoted outcome destroys the quarantine — no orphan raw media.
            if !promoted { try? FileManager.default.removeItem(at: quarantine) }
        }
        // stage 5: ONLY NOW may raw bytes enter (ephemeral quarantine).
        let payload = try acquirer.fetch(sourceReference: record.sourceReference)
        let payloadURL = quarantine.appendingPathComponent("payload")
        do { try payload.write(to: payloadURL, options: .atomic) }
        catch { throw RWCAcquisitionErrorV1.quarantineFailure("\(error)") }
        // stage 6: content-hash law.
        let actual = Self.sha256Hex(payload)
        guard actual == record.contentHash else {
            throw RWCAcquisitionErrorV1.contentHashMismatch(expected: record.contentHash, actual: actual)
        }
        // stage 7: atomic durable rights commit (journal + witness; single-writer store).
        try rightsStore.register(record, verifiedGrant: verifiedGrant, clock: clock)
        // stage 8: promote only after the rights commit.
        do { try corpusStore.promote(assetID: record.assetID, contentHash: record.contentHash,
                                     payload: payload) }
        catch {
            // rights are committed; promotion failed → explicit deficit for reconcile (quarantine
            // is preserved for deterministic recovery).
            promoted = true   // keep quarantine for reconciliation
            throw RWCAcquisitionErrorV1.promoteFailure("\(error)")
        }
        promoted = true
        try? FileManager.default.removeItem(at: quarantine)
        // stage 9: receipt.
        return RWCAcquisitionReceiptV1(
            sessionID: sessionID, assetID: record.assetID, contentHash: record.contentHash,
            legalGrantID: record.grant.grantID, grantRevision: record.grant.grantRevision,
            reviewRecordID: verifiedGrant.reviewRecordID,
            rightsLedgerHeadDigest: rightsStore.headDigest, rightsEventCount: rightsStore.eventCount,
            passLockCandidateCommit: proof.candidateCommit,
            passLockTagObjectSHA: proof.candidateTagObjectSHA,
            auditResultBlobSHA256: proof.auditResultBlobSHA256,
            freezeManifestSHA256: proof.freezeManifestSHA256,
            methodologyAnchorCommit: proof.methodologyAnchorCommit,
            acquisitionDate: clock.today().isoString)
    }

    public struct ReconciliationReportV1: Equatable, Sendable {
        public let registeredButUnpromoted: [String]       // rights exist, corpus payload absent
        public let recoveredFromQuarantine: [String]       // re-promoted hash-verified payloads
        public let destroyedOrphanQuarantines: [String]    // quarantines without rights records
    }

    /// Startup/crash reconciliation (§43): deterministic recovery between the rights ledger and the
    /// corpus store. NO orphan raw media survives; registered-but-unpromoted assets are either
    /// recovered from a hash-verified quarantine or reported as an explicit deficit.
    public func reconcile(rightsStore: RWCAssetRightsLedgerStoreV3,
                          corpusStore: RWCCorpusStoreV1) throws -> ReconciliationReportV1 {
        let stored = Set(try corpusStore.storedAssetIDs())
        var unpromoted: [String] = []
        var recovered: [String] = []
        var destroyed: [String] = []
        // scan surviving quarantines
        var quarantinePayloads: [String: URL] = [:]   // sessionID -> payload
        if let names = try? FileManager.default.contentsOfDirectory(atPath: quarantineRoot.path) {
            for name in names where name.hasPrefix("rwc-quarantine-") {
                quarantinePayloads[String(name.dropFirst("rwc-quarantine-".count))] =
                    quarantineRoot.appendingPathComponent(name).appendingPathComponent("payload")
            }
        }
        var consumedSessions = Set<String>()
        for e in rightsStore.events where e.kind == "registered" || e.kind == "reauthorized" {
            let assetID = e.assetID
            guard !rightsStore.isTombstoned(assetID), !stored.contains(assetID),
                  let record = rightsStore.record(for: assetID) else { continue }
            // registered but unpromoted: try hash-verified quarantine recovery
            var recoveredThis = false
            for (session, payloadURL) in quarantinePayloads where !consumedSessions.contains(session) {
                guard let data = try? Data(contentsOf: payloadURL),
                      Self.sha256Hex(data) == record.contentHash else { continue }
                try corpusStore.promote(assetID: assetID, contentHash: record.contentHash, payload: data)
                try? FileManager.default.removeItem(at: payloadURL.deletingLastPathComponent())
                consumedSessions.insert(session)
                recovered.append(assetID)
                recoveredThis = true
                break
            }
            if !recoveredThis { unpromoted.append(assetID) }
        }
        // destroy quarantines that match no rights record (orphan raw media is forbidden)
        for (session, payloadURL) in quarantinePayloads where !consumedSessions.contains(session) {
            try? FileManager.default.removeItem(at: payloadURL.deletingLastPathComponent())
            destroyed.append(session)
        }
        return ReconciliationReportV1(registeredButUnpromoted: unpromoted.sorted(),
                                      recoveredFromQuarantine: recovered.sorted(),
                                      destroyedOrphanQuarantines: destroyed.sorted())
    }
}
#endif
