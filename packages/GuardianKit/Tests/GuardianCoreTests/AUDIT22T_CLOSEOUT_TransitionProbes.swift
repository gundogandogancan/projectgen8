import XCTest
import Foundation
@testable import GuardianCore
#if os(macOS)
@testable import RWCAcquisition
#endif

/// V10 CLOSEOUT TRANSITION PROBES (main session; post-audit allowance; NOT a new independent audit).
/// Asserts the lawful post-closeout state transition: the canonical lock now carries the V10
/// authority and RWCCorpusEntryVerifierV7.verify(realRepo) SUCCEEDS with the exact AUDIT22T
/// bindings, while all operational gates stay closed. Historical pre-closeout state reproducible
/// at c347ce016b3a2b1949b13f094dc61335b248ae41 and earlier.
final class AUDIT22T_CLOSEOUT_TransitionProbes: XCTestCase {
    #if os(macOS)
    private func repoRoot() -> URL {
        var u = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while !FileManager.default.fileExists(atPath: u.appendingPathComponent("docs/audit").path) {
            let p = u.deletingLastPathComponent()
            if p.path == u.path { break }
            u = p
        }
        return u
    }

    func test_CLOSEOUT_V7_Verify_RealRepo_Succeeds_WithExactBindings() throws {
        let entry = try RWCCorpusEntryVerifierV7.verify(repoRoot: repoRoot())
        XCTAssertEqual(entry.candidateCommit, "df952d260567c8ffcdde0fed83f8f36617b94c62")
        XCTAssertEqual(entry.candidateTagObjectSHA, "c3174ef4611c9b8e3c06ed73605d46f0787d29ea")
        XCTAssertEqual(entry.auditCommit, "c347ce016b3a2b1949b13f094dc61335b248ae41")
        XCTAssertEqual(entry.auditResultBlobSHA256,
            "c294310b4c61bf95ccd6f47c0fcd8d422f6140b3f0a24977bb7008a4e75b6ebb")
        XCTAssertEqual(entry.methodologyAnchorCommit, "6cdfb3ff23a51d799bb89a625c7f815a0f56f5f6")
        XCTAssertEqual(entry.freezeManifestSHA256,
            "1b5198de7637ebc1e520205e130d117f3c913eb73757b8dd76736b412d88a7b2")
        XCTAssertEqual(entry.frozenInventoryDigest,
            "464bffe815c041418c0176829fef555ffd005de748d1bf4ec0ac3b99a05295ba")
    }

    func test_CLOSEOUT_OperationalGates_StillClosed() throws {
        let root = repoRoot()
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json").path),
            "no operational root")
        XCTAssertThrowsError(try RWCReviewerTrustRootLoaderV2.loadProduction(repoRoot: root)) { e in
            XCTAssertEqual(e as? RWCReviewerTrustErrorV2, .noOperationalRoot)
        }
    }
    #endif
}
