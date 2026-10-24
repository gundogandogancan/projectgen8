import Foundation
import CryptoKit

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC OPERATIONAL ROOT ONBOARDING V1 (LANE A; operational pre-activation engine).
//
// PURPOSE. Add a NEW, governed activation boundary ON TOP OF the AUDIT21-PASS trust core WITHOUT
// weakening R7's fail-closed PRE-activation world. `RWCReviewerTrustRootLoaderV2.loadProduction`
// (RWCRightsV6.swift) stays byte-identical: it throws `.noOperationalRoot` before any file read. This
// engine is the SEPARATE, auditable source of the `RWCReviewerRootOnboardingCapabilityV1` + the
// governed `RWCVerifiedReviewerTrustRootV2` that the existing registry chain already consumes.
//
// SECURITY PRINCIPLES.
//   • A18-F1 carried: SIGNATURE AUTHENTICITY ≠ TRUST AUTHORITY.
//   • NEW (this engine): FILE POSSESSION ≠ ROOT AUTHORITY. A caller-supplied root JSON file — even at
//     the canonical path — can NEVER activate a root on its own. Activation additionally requires
//       (1) a well-formed GOVERNANCE RECORD (authorizing identity, rwc-gov-* id, date, scope), and
//       (2) an OUT-OF-BAND FINGERPRINT (lowercase-hex SHA-256 of the RAW Ed25519 public key bytes)
//           that the human operator supplies from an INDEPENDENT channel and that must equal the
//           fingerprint recomputed from the candidate key.
//   • A19-F2 carried: the capability init stays `internal`; the capability-gated mint stays `internal`.
//     An ordinary EXTERNAL consumer of the exported `GuardianCore` library cannot construct the
//     capability nor call `activate` (which is `package`).
//
// SEPARATION (mandate §4.9): load / verify / activate / revoke / rotate are distinct steps.
//   load     (public)  : parse candidate root JSON → inert CandidateRootV1 (NOT trusted).
//   verify   (public)  : candidate + governance record + OOB fingerprint → VerifiedActivationRequestV1
//                        (still NOT a root — grants NO authority).
//   activate (package) : VerifiedActivationRequestV1 + durable store → mints the capability + the
//                        verified root V2, writes a durable hash-chained ACTIVATED event; refuses silent
//                        replacement of an already-ACTIVE different root.
//   revoke   (package) : append a durable REVOKED event.
//   rotate   (package) : REVOKE old + ACTIVATE new (two explicit, historical, chained events).
//
// HONEST LIMITS (mandate §3.8/§4.8). The durable store is a LOCAL hash chain: tamper-DETECTION under a
// NON-hostile-disk model (accidental corruption, truncation, out-of-order replay, old-file re-present,
// monotonic advance). It is NOT an absolute offline rollback proof against an adversary with write
// access to the store directory (the honest R-5 residual, carried). Absolute currentness needs an
// EXTERNAL monotonic authority — out of scope pre-data. Key custody technology is compared, not
// asserted, in docs/operations/rwc/RWC_GOVERNANCE_AND_KEY_MANAGEMENT_V1.md; Secure Enclave Ed25519
// support is UNKNOWN and NOT assumed here.
//
// ZERO-DATA / ACTIVATION-BLOCKED. This file mints a verified root ONLY from a caller-provided governed
// JSON + OOB fingerprint; it NEVER writes the canonical production root file, NEVER generates a key, and
// NEVER declares OPERATIONAL_ROOT_ACTIVE. Tests drive it with synthetic keys in isolated fixtures.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

// MARK: - Typed errors

public enum RWCOperationalOnboardingErrorV1: Error, Equatable, Sendable {
    // load / candidate
    case candidateMalformed(String)
    case candidateNotActive(status: String)
    case malformedRootID
    case malformedRootKey
    // governance record
    case governanceRecordMalformed(field: String)
    case governanceScopeUnacceptable(scope: String)
    // fingerprint (out-of-band)
    case fingerprintMismatch
    case malformedFingerprint
    // activation store
    case storeDirectoryExists
    case storeWitnessMissing
    case storeMalformed
    case storeLockedByAnotherWriter
    case storeIOFailure(String)
    // activation laws
    case alreadyActiveDifferentRoot(active: String, presented: String)
    case alreadyActiveSameRoot(rootID: String)
    case noActiveRoot
    case rootNotActiveForOperation(rootID: String)
    case rotateRetiringMismatch(active: String, retiring: String)
}

// MARK: - Governance record (schema GovernanceRecordV1)

/// A governance decision record. Opaque audit pointer to the real-world approval; the engine validates
/// grammar/shape only. The real decision linkage is the Governance authority's responsibility
/// (HUMAN ACTIVATION GATE). Fields map to RWC_GOVERNANCE_RECORD_TEMPLATE_V1.json.
public struct RWCGovernanceRecordV1: Equatable, Sendable {
    public let authorizingIdentity: String
    public let governanceRecordID: String      // rwc-gov-[a-z0-9-]{4,64}
    public let decisionDate: String            // YYYY-MM-DD (RWCDateV3-parseable)
    public let scope: String                   // RWCReviewerScopeV1 raw; rwc-governance for a gov decision

    public init(authorizingIdentity: String, governanceRecordID: String,
                decisionDate: String, scope: String) {
        self.authorizingIdentity = authorizingIdentity; self.governanceRecordID = governanceRecordID
        self.decisionDate = decisionDate; self.scope = scope
    }

    /// Parse from strict JSON bytes (matches the template file shape).
    public static func parse(fromJSON data: Data) throws -> RWCGovernanceRecordV1 {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RWCOperationalOnboardingErrorV1.governanceRecordMalformed(field: "json")
        }
        func str(_ k: String) throws -> String {
            guard let v = o[k] as? String, !v.isEmpty else {
                throw RWCOperationalOnboardingErrorV1.governanceRecordMalformed(field: k)
            }
            return v
        }
        return RWCGovernanceRecordV1(authorizingIdentity: try str("authorizing_identity"),
                                     governanceRecordID: try str("governance_record_id"),
                                     decisionDate: try str("decision_date"),
                                     scope: try str("scope"))
    }
}

// MARK: - Inert value types (load / verify outputs grant NO authority)

/// Parsed candidate root — NOT trusted. Produced by `loadCandidate`; carries the parsed fields and the
/// recomputed public-key fingerprint, but can mint NOTHING by itself.
public struct RWCCandidateRootV1: Sendable {
    public let rootID: String
    public let publicKeyRawHex: String
    public let governanceRecordID: String
    public let activationDate: String
    /// lowercase-hex SHA-256 of the RAW Ed25519 public-key bytes (what the OOB fingerprint must equal).
    public let publicKeyFingerprint: String
    fileprivate let rawJSON: Data
    fileprivate init(rootID: String, publicKeyRawHex: String, governanceRecordID: String,
                     activationDate: String, publicKeyFingerprint: String, rawJSON: Data) {
        self.rootID = rootID; self.publicKeyRawHex = publicKeyRawHex
        self.governanceRecordID = governanceRecordID; self.activationDate = activationDate
        self.publicKeyFingerprint = publicKeyFingerprint; self.rawJSON = rawJSON
    }
}

/// A verified activation REQUEST — fingerprint + governance record laws have passed, but this is STILL
/// NOT a root: it holds no capability and cannot mint. Only `activate` (package) turns it into a root.
public struct RWCVerifiedActivationRequestV1: Sendable {
    public let rootID: String
    public let governanceRecordID: String
    public let publicKeyFingerprint: String
    fileprivate let rawJSON: Data
    fileprivate init(rootID: String, governanceRecordID: String, publicKeyFingerprint: String,
                     rawJSON: Data) {
        self.rootID = rootID; self.governanceRecordID = governanceRecordID
        self.publicKeyFingerprint = publicKeyFingerprint; self.rawJSON = rawJSON
    }
}

/// Result of a successful activation: the verified root the registry chain consumes + the durable event
/// identity. The root is produced by the A19-F2 capability-gated mint — the engine holds the only
/// lawful source of the capability.
public struct RWCActivatedRootV1: Sendable {
    public let verifiedRoot: RWCVerifiedReviewerTrustRootV2
    public let rootID: String
    public let governanceRecordID: String
    public let activationChainDigest: String
    fileprivate init(verifiedRoot: RWCVerifiedReviewerTrustRootV2, rootID: String,
                     governanceRecordID: String, activationChainDigest: String) {
        self.verifiedRoot = verifiedRoot; self.rootID = rootID
        self.governanceRecordID = governanceRecordID; self.activationChainDigest = activationChainDigest
    }
}

// MARK: - The onboarding engine

public enum RWCOperationalRootOnboardingV1 {
    public static let version = "rwc-operational-root-onboarding-v1"
    /// Acceptable governance scopes for activating the corpus reviewer root. A governance DECISION is
    /// `rwc-governance`. A single-operator role-merge is recorded in the governance & key-management doc;
    /// if merged, a reviewer scope is accepted but MUST be acknowledged (G5 of the activation gate).
    public static let acceptableScopes: Set<String> = [RWCReviewerScopeV1.governance.rawValue]

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // ── STEP 1: load (public; grants no authority) ────────────────────────────────────────────────

    /// Parse candidate root JSON into an inert `RWCCandidateRootV1`. Enforces the same structural laws as
    /// the capability-gated mint (grammar, ed25519, ACTIVE, parseable key) so a malformed candidate is
    /// refused early — but produces NO trust (no capability, no verified root).
    public static func loadCandidate(rootJSON data: Data) throws -> RWCCandidateRootV1 {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RWCOperationalOnboardingErrorV1.candidateMalformed("not strict JSON")
        }
        func str(_ k: String) throws -> String {
            guard let v = o[k] as? String, !v.isEmpty else {
                throw RWCOperationalOnboardingErrorV1.candidateMalformed("missing \(k)")
            }
            return v
        }
        let rootID = try str("root_id")
        let keyHex = try str("public_key_raw_hex")
        let algorithm = try str("algorithm")
        let governanceRecordID = try str("governance_record_id")
        let statusRaw = try str("status")
        let activationDate = try str("activation_date")
        _ = try RWCDateV3.parse(activationDate, field: "activation_date")
        guard RWCRightsReviewAuthorityV1.isToken(rootID, prefix: "rwc-root-") else {
            throw RWCOperationalOnboardingErrorV1.malformedRootID
        }
        guard algorithm == "ed25519" else {
            throw RWCOperationalOnboardingErrorV1.candidateMalformed("algorithm")
        }
        guard statusRaw == "ACTIVE" else {
            throw RWCOperationalOnboardingErrorV1.candidateNotActive(status: statusRaw)
        }
        guard RWCTrustHex.isHex(keyHex, length: 64), let keyData = RWCTrustHex.hexToData(keyHex),
              (try? Curve25519.Signing.PublicKey(rawRepresentation: keyData)) != nil else {
            throw RWCOperationalOnboardingErrorV1.malformedRootKey
        }
        // Fingerprint is over the RAW public-key bytes (NOT the hex string).
        let fingerprint = sha256Hex(keyData)
        return RWCCandidateRootV1(rootID: rootID, publicKeyRawHex: keyHex,
                                  governanceRecordID: governanceRecordID, activationDate: activationDate,
                                  publicKeyFingerprint: fingerprint, rawJSON: data)
    }

    // ── STEP 2: verify (public; grants no authority) ──────────────────────────────────────────────

    /// Bind the candidate to a GOVERNANCE RECORD and an OUT-OF-BAND fingerprint. The caller-supplied file
    /// alone never suffices (mandate §3/§4.3). Refuses on: fingerprint mismatch, malformed/empty
    /// governance record, unacceptable governance scope, governance-record-id disagreement with the
    /// candidate file. Returns an inert `RWCVerifiedActivationRequestV1` (STILL not a root).
    public static func verifyCandidate(_ candidate: RWCCandidateRootV1,
                                       governanceRecord: RWCGovernanceRecordV1,
                                       expectedFingerprint: String) throws -> RWCVerifiedActivationRequestV1 {
        // out-of-band fingerprint law
        guard RWCTrustHex.isHex(expectedFingerprint, length: 64) else {
            throw RWCOperationalOnboardingErrorV1.malformedFingerprint
        }
        guard expectedFingerprint == candidate.publicKeyFingerprint else {
            throw RWCOperationalOnboardingErrorV1.fingerprintMismatch
        }
        // governance record grammar
        guard RWCRightsReviewAuthorityV1.isToken(governanceRecord.governanceRecordID,
                                                 prefix: "rwc-gov-") else {
            throw RWCOperationalOnboardingErrorV1.governanceRecordMalformed(field: "governance_record_id")
        }
        guard !governanceRecord.authorizingIdentity
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RWCOperationalOnboardingErrorV1.governanceRecordMalformed(field: "authorizing_identity")
        }
        _ = try RWCDateV3.parse(governanceRecord.decisionDate, field: "decision_date")
        guard RWCReviewerScopeV1(rawValue: governanceRecord.scope) != nil else {
            throw RWCOperationalOnboardingErrorV1.governanceRecordMalformed(field: "scope")
        }
        guard acceptableScopes.contains(governanceRecord.scope) else {
            throw RWCOperationalOnboardingErrorV1.governanceScopeUnacceptable(scope: governanceRecord.scope)
        }
        // the candidate file's governance_record_id must agree with the supplied governance record
        guard candidate.governanceRecordID == governanceRecord.governanceRecordID else {
            throw RWCOperationalOnboardingErrorV1.governanceRecordMalformed(field: "governance_record_id-mismatch")
        }
        return RWCVerifiedActivationRequestV1(rootID: candidate.rootID,
                                              governanceRecordID: governanceRecord.governanceRecordID,
                                              publicKeyFingerprint: candidate.publicKeyFingerprint,
                                              rawJSON: candidate.rawJSON)
    }

    // ── STEP 3: activate (package; the ONLY lawful source of the capability + verified root) ────────

    /// Activate a verified request into a governed `RWCVerifiedReviewerTrustRootV2`, writing a durable
    /// hash-chained ACTIVATED event. `package` so an ordinary external consumer of GuardianCore cannot
    /// activate. Refuses: a DIFFERENT rootID while one is ACTIVE (silent replacement — mandate §4.6); a
    /// duplicate activation of the same ACTIVE root. The capability is minted HERE (its init is internal)
    /// and consumed immediately by the A19-F2 capability-gated mint; it never escapes as a mintable
    /// object to callers.
    @discardableResult
    package static func activate(request: RWCVerifiedActivationRequestV1,
                                 store: RWCOperationalRootActivationStoreV1,
                                 clock: RWCRightsClockV3) throws -> RWCActivatedRootV1 {
        if let head = store.currentHead {
            if head.status == RWCOperationalRootActivationStoreV1.statusActive {
                if head.rootID == request.rootID {
                    throw RWCOperationalOnboardingErrorV1.alreadyActiveSameRoot(rootID: head.rootID)
                }
                throw RWCOperationalOnboardingErrorV1.alreadyActiveDifferentRoot(active: head.rootID,
                                                                                 presented: request.rootID)
            }
        }
        // Mint the capability (internal init) and the verified root via the A19-F2 capability-gated mint.
        let capability = RWCReviewerRootOnboardingCapabilityV1(
            onboardingRecordID: request.governanceRecordID)
        let verifiedRoot: RWCVerifiedReviewerTrustRootV2
        do {
            verifiedRoot = try RWCReviewerTrustRootLoaderV2.mint(fromJSON: request.rawJSON,
                                                                 capability: capability)
        } catch let e as RWCReviewerTrustErrorV2 {
            // map the mint's structural refusals back to onboarding errors (defense in depth).
            switch e {
            case .malformedRootID: throw RWCOperationalOnboardingErrorV1.malformedRootID
            case .malformedRootKey: throw RWCOperationalOnboardingErrorV1.malformedRootKey
            case .rootNotActive(let s): throw RWCOperationalOnboardingErrorV1.candidateNotActive(status: s)
            default: throw RWCOperationalOnboardingErrorV1.candidateMalformed("\(e)")
            }
        }
        let digest = try store.append(eventKind: RWCOperationalRootActivationStoreV1.kindActivated,
                                      rootID: request.rootID,
                                      governanceRecordID: request.governanceRecordID,
                                      publicKeyFingerprint: request.publicKeyFingerprint,
                                      reason: "",
                                      clock: clock)
        return RWCActivatedRootV1(verifiedRoot: verifiedRoot, rootID: request.rootID,
                                  governanceRecordID: request.governanceRecordID,
                                  activationChainDigest: digest)
    }

    // ── STEP 4: revoke (package) ────────────────────────────────────────────────────────────────

    /// Revoke the currently ACTIVE root. `package`. Appends a durable REVOKED event; after this the root
    /// no longer activates/mints. Refuses if no root is ACTIVE or the rootID does not match the head.
    package static func revoke(rootID: String, reason: String,
                               store: RWCOperationalRootActivationStoreV1,
                               clock: RWCRightsClockV3) throws {
        guard let head = store.currentHead,
              head.status == RWCOperationalRootActivationStoreV1.statusActive else {
            throw RWCOperationalOnboardingErrorV1.noActiveRoot
        }
        guard head.rootID == rootID else {
            throw RWCOperationalOnboardingErrorV1.rootNotActiveForOperation(rootID: rootID)
        }
        _ = try store.append(eventKind: RWCOperationalRootActivationStoreV1.kindRevoked,
                             rootID: rootID, governanceRecordID: head.governanceRecordID,
                             publicKeyFingerprint: head.publicKeyFingerprint,
                             reason: reason, clock: clock)
    }

    // ── STEP 5: rotate (package) — REVOKE old + ACTIVATE new, explicit + historical ───────────────

    /// Governed root rotation: retire the ACTIVE root and activate a NEW root identity. Two explicit,
    /// durable, chained events (ROTATED_OUT then ROTATED_IN). There is NO in-place key swap. Refuses if
    /// the retiring rootID is not the ACTIVE head, or the new request equals the retiring rootID.
    @discardableResult
    package static func rotate(retiring retiringRootID: String,
                               request: RWCVerifiedActivationRequestV1,
                               store: RWCOperationalRootActivationStoreV1,
                               clock: RWCRightsClockV3) throws -> RWCActivatedRootV1 {
        guard let head = store.currentHead,
              head.status == RWCOperationalRootActivationStoreV1.statusActive else {
            throw RWCOperationalOnboardingErrorV1.noActiveRoot
        }
        guard head.rootID == retiringRootID else {
            throw RWCOperationalOnboardingErrorV1.rotateRetiringMismatch(active: head.rootID,
                                                                         retiring: retiringRootID)
        }
        guard request.rootID != retiringRootID else {
            throw RWCOperationalOnboardingErrorV1.alreadyActiveSameRoot(rootID: retiringRootID)
        }
        _ = try store.append(eventKind: RWCOperationalRootActivationStoreV1.kindRotatedOut,
                             rootID: retiringRootID, governanceRecordID: head.governanceRecordID,
                             publicKeyFingerprint: head.publicKeyFingerprint,
                             reason: "rotate", clock: clock)
        // Mint the new root (same capability-gated path) and record ROTATED_IN.
        let capability = RWCReviewerRootOnboardingCapabilityV1(
            onboardingRecordID: request.governanceRecordID)
        let verifiedRoot = try RWCReviewerTrustRootLoaderV2.mint(fromJSON: request.rawJSON,
                                                                 capability: capability)
        let digest = try store.append(eventKind: RWCOperationalRootActivationStoreV1.kindRotatedIn,
                                      rootID: request.rootID,
                                      governanceRecordID: request.governanceRecordID,
                                      publicKeyFingerprint: request.publicKeyFingerprint,
                                      reason: "rotate", clock: clock)
        return RWCActivatedRootV1(verifiedRoot: verifiedRoot, rootID: request.rootID,
                                  governanceRecordID: request.governanceRecordID,
                                  activationChainDigest: digest)
    }
}

// MARK: - Durable, single-writer, append-only, hash-chained ACTIVATION-EVENT store

/// Reuses the proven RWCReviewerRegistryCurrentnessStoreV1 durability pattern (flock single-writer for
/// life; atomic temp+rename head witness; SHA-256-chained JSONL journal; crash roll-forward that refuses
/// any chain break / digest mismatch / sequence gap). It records the ACTIVE reviewer-root authority as a
/// monotonic sequence of events. HONEST LIMIT: tamper-DETECTION only, non-hostile-disk model (see the
/// file header). There is NO rewind API.
public final class RWCOperationalRootActivationStoreV1 {
    public static let version = "rwc-operational-root-activation-store-v1"
    static let journalName = "root-activation-v1.jsonl"
    static let witnessName = "root-activation-head-v1.json"
    static let lockName = "root-activation-v1.lock"

    public static let kindActivated = "ACTIVATED"
    public static let kindRevoked = "REVOKED"
    public static let kindRotatedOut = "ROTATED_OUT"
    public static let kindRotatedIn = "ROTATED_IN"
    public static let statusActive = "ACTIVE"
    public static let statusRevoked = "REVOKED"

    public struct HeadV1: Equatable, Sendable {
        public let rootID: String
        public let status: String            // ACTIVE | REVOKED (derived from the last event kind)
        public let governanceRecordID: String
        public let publicKeyFingerprint: String
        public let chainDigest: String
    }

    public struct EventV1: Equatable, Sendable {
        public let seq: Int
        public let previousDigest: String
        public let kind: String
        public let rootID: String
        public let governanceRecordID: String
        public let publicKeyFingerprint: String
        public let reason: String
        public let recordedDate: String
        public let chainDigest: String
    }

    public let directory: URL
    public private(set) var events: [EventV1] = []
    private var lockFD: Int32 = -1

    private var journalURL: URL { directory.appendingPathComponent(Self.journalName) }
    private var witnessURL: URL { directory.appendingPathComponent(Self.witnessName) }
    private var lockURL: URL { directory.appendingPathComponent(Self.lockName) }

    public static let genesisDigest =
        SHA256.hash(data: Data("GEN8-RWC-ROOT-ACTIVATION-V1-GENESIS".utf8))
            .map { String(format: "%02x", $0) }.joined()

    /// The current head, derived from the last event. ACTIVATED/ROTATED_IN ⇒ ACTIVE; REVOKED/ROTATED_OUT
    /// ⇒ REVOKED (no active root).
    public var currentHead: HeadV1? {
        guard let last = events.last else { return nil }
        let status = (last.kind == Self.kindActivated || last.kind == Self.kindRotatedIn)
            ? Self.statusActive : Self.statusRevoked
        return HeadV1(rootID: last.rootID, status: status, governanceRecordID: last.governanceRecordID,
                      publicKeyFingerprint: last.publicKeyFingerprint, chainDigest: last.chainDigest)
    }
    public var headChainDigest: String { events.last?.chainDigest ?? Self.genesisDigest }

    private init(directory: URL) { self.directory = directory }
    deinit { if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD) } }
    public func closeStore() { if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD); lockFD = -1 } }

    private static func sha256Hex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func acquireWriterLock() throws {
        let fd = open(lockURL.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { throw RWCOperationalOnboardingErrorV1.storeIOFailure("open lock failed") }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd); throw RWCOperationalOnboardingErrorV1.storeLockedByAnotherWriter
        }
        lockFD = fd
    }

    static func entryChainDigest(previous: String, kind: String, rootID: String,
                                 governanceRecordID: String, publicKeyFingerprint: String,
                                 reason: String, recordedDate: String, seq: Int) -> String {
        var out = Data()
        for field in ["rwc-root-activation-v1", String(seq), previous, kind, rootID,
                      governanceRecordID, publicKeyFingerprint, reason, recordedDate] {
            let bytes = Data(field.utf8)
            var len = UInt32(bytes.count).bigEndian
            withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
            out.append(bytes)
        }
        return SHA256.hash(data: out).map { String(format: "%02x", $0) }.joined()
    }

    static func journalLine(_ e: EventV1) -> String {
        "{\"v\":\"rwc-root-activation-v1\",\"seq\":\(e.seq),\"prev\":\"\(esc(e.previousDigest))\"," +
        "\"kind\":\"\(esc(e.kind))\",\"root\":\"\(esc(e.rootID))\"," +
        "\"gov\":\"\(esc(e.governanceRecordID))\",\"fp\":\"\(esc(e.publicKeyFingerprint))\"," +
        "\"reason\":\"\(esc(e.reason))\",\"rec\":\"\(esc(e.recordedDate))\"," +
        "\"digest\":\"\(esc(e.chainDigest))\"}\n"
    }

    private func writeWitness() throws {
        let head = currentHead
        let json = "{\"v\":\"\(Self.version)\",\"count\":\(events.count)," +
            "\"root\":\"\(Self.esc(head?.rootID ?? ""))\"," +
            "\"status\":\"\(Self.esc(head?.status ?? ""))\"," +
            "\"gov\":\"\(Self.esc(head?.governanceRecordID ?? ""))\"," +
            "\"fp\":\"\(Self.esc(head?.publicKeyFingerprint ?? ""))\"," +
            "\"head\":\"\(headChainDigest)\"}\n"
        let tmp = directory.appendingPathComponent(Self.witnessName + ".tmp")
        do {
            try Data(json.utf8).write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: witnessURL.path) {
                _ = try FileManager.default.replaceItemAt(witnessURL, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: witnessURL)
            }
        } catch { throw RWCOperationalOnboardingErrorV1.storeIOFailure("witness write: \(error)") }
    }

    public static func create(directory: URL) throws -> RWCOperationalRootActivationStoreV1 {
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent(witnessName).path) {
            throw RWCOperationalOnboardingErrorV1.storeDirectoryExists
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = RWCOperationalRootActivationStoreV1(directory: directory)
        try store.acquireWriterLock()
        guard FileManager.default.createFile(atPath: store.journalURL.path, contents: nil) else {
            throw RWCOperationalOnboardingErrorV1.storeIOFailure("journal create failed")
        }
        try store.writeWitness()
        return store
    }

    public static func openExisting(directory: URL) throws -> RWCOperationalRootActivationStoreV1 {
        let store = RWCOperationalRootActivationStoreV1(directory: directory)
        guard FileManager.default.fileExists(atPath: store.witnessURL.path) else {
            throw RWCOperationalOnboardingErrorV1.storeWitnessMissing
        }
        try store.acquireWriterLock()
        guard let raw = try? String(contentsOf: store.journalURL, encoding: .utf8) else {
            throw RWCOperationalOnboardingErrorV1.storeIOFailure("journal read failed")
        }
        var parsed: [EventV1] = []
        var prev = genesisDigest
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        for (i, line) in lines.enumerated() {
            guard let o = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  o["v"] as? String == "rwc-root-activation-v1",
                  let seq = o["seq"] as? Int, let p = o["prev"] as? String,
                  let kind = o["kind"] as? String, let root = o["root"] as? String,
                  let gov = o["gov"] as? String, let fp = o["fp"] as? String,
                  let reason = o["reason"] as? String, let rec = o["rec"] as? String,
                  let digest = o["digest"] as? String else {
                throw RWCOperationalOnboardingErrorV1.storeMalformed
            }
            guard seq == i, p == prev else { throw RWCOperationalOnboardingErrorV1.storeMalformed }
            let rebuilt = entryChainDigest(previous: p, kind: kind, rootID: root,
                                           governanceRecordID: gov, publicKeyFingerprint: fp,
                                           reason: reason, recordedDate: rec, seq: seq)
            guard rebuilt == digest else { throw RWCOperationalOnboardingErrorV1.storeMalformed }
            parsed.append(EventV1(seq: seq, previousDigest: p, kind: kind, rootID: root,
                                  governanceRecordID: gov, publicKeyFingerprint: fp, reason: reason,
                                  recordedDate: rec, chainDigest: digest))
            prev = digest
        }
        store.events = parsed
        return store
    }

    /// Append one durable, chained event. Called ONLY by the onboarding engine (package-scoped
    /// activate/revoke/rotate). Returns the new chain digest.
    @discardableResult
    func append(eventKind kind: String, rootID: String, governanceRecordID: String,
                publicKeyFingerprint: String, reason: String, clock: RWCRightsClockV3) throws -> String {
        let recordedDate = clock.today().isoString
        let seq = events.count
        let chain = Self.entryChainDigest(previous: headChainDigest, kind: kind, rootID: rootID,
                                          governanceRecordID: governanceRecordID,
                                          publicKeyFingerprint: publicKeyFingerprint, reason: reason,
                                          recordedDate: recordedDate, seq: seq)
        let e = EventV1(seq: seq, previousDigest: headChainDigest, kind: kind, rootID: rootID,
                        governanceRecordID: governanceRecordID, publicKeyFingerprint: publicKeyFingerprint,
                        reason: reason, recordedDate: recordedDate, chainDigest: chain)
        guard let handle = try? FileHandle(forWritingTo: journalURL) else {
            throw RWCOperationalOnboardingErrorV1.storeIOFailure("journal open failed")
        }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(Self.journalLine(e).utf8))
            try handle.synchronize()
        } catch { throw RWCOperationalOnboardingErrorV1.storeIOFailure("journal append: \(error)") }
        events.append(e)
        try writeWitness()
        return chain
    }
}
