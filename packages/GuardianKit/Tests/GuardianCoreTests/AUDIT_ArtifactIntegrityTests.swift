//
//  AUDIT_ArtifactIntegrityTests.swift
//  AUDITOR-AUTHORED (independent red-team audit, 2026-10-19). NOT part of the project's own test suite design.
//  Purpose: recompute SHA-256 of the immutable device-log artifacts, verify the cumulative prefix-chain property,
//  and recompute percentile metrics from raw log lines — because the audit sandbox denied `shasum`/`openssl`/`awk`.
//  This file is READ-ONLY with respect to all artifacts and production code. Safe to delete after the audit.
//
import XCTest
import CryptoKit
import Foundation

final class AUDIT_ArtifactIntegrityTests: XCTestCase {
    private let dir = "/Users/dogancangundogan/PROJECTGEN8/Gen8/docs/evals/artifacts"
    private let files = [
        "P008A_BEFORE_crossapp_session.log",
        "P008A_R1_AFTER_crossapp_rerun.log",
        "P008A_R2_AFTER_crossapp_device_v3.log",
        "P008A_R3_AFTER_crossapp_device_v4.log",
        "P008A_R4_AFTER_crossapp_device_v5.log",
        "P009A_AFTER_crossapp_device_itemgroup.log",
        "P009A_R1_AFTER_crossapp_device_tier0.log",
    ]

    func testAUDIT_Sha256MatchesLockFiles() throws {
        for f in files {
            let data = try Data(contentsOf: URL(fileURLWithPath: dir + "/" + f))
            let hex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let lock = try String(contentsOfFile: dir + "/" + f + ".sha256", encoding: .utf8)
            let expected = lock.split(separator: " ").first.map(String.init) ?? ""
            print("AUDIT_SHA \(f) recomputed=\(hex) locked=\(expected) match=\(hex == expected)")
            XCTAssertEqual(hex, expected, "SHA-256 mismatch for \(f)")
        }
    }

    /// Each successive artifact should be a byte-prefix extension of the previous (cumulative device log).
    func testAUDIT_PrefixChainProperty() throws {
        var prev = Data()
        for f in files {
            let cur = try Data(contentsOf: URL(fileURLWithPath: dir + "/" + f))
            let isPrefix = cur.count >= prev.count && cur.prefix(prev.count) == prev
            print("AUDIT_PREFIX \(f) bytes=\(cur.count) extendsPrevious=\(isPrefix)")
            XCTAssertTrue(isPrefix, "\(f) does not extend the previous artifact — history rewritten?")
            prev = cur
        }
    }

    /// Recompute percentiles of firstTrustworthyMs over ITEM lines of the final (P009A-R1 Tier-0) session,
    /// and max memoryMB, straight from raw lines.
    func testAUDIT_RecomputeFinalSessionMetrics() throws {
        let all = try String(contentsOfFile: dir + "/P009A_R1_AFTER_crossapp_device_tier0.log", encoding: .utf8)
            .split(separator: "\n").map(String.init)
        // final session starts at the LAST BROADCAST_STARTED
        guard let startIdx = all.lastIndex(where: { $0.contains("BROADCAST_STARTED") }) else { return XCTFail() }
        let session = Array(all[startIdx...])
        func value(_ line: String, _ key: String) -> Double? {
            guard let r = line.range(of: key + "=") else { return nil }
            let tailStr = line[r.upperBound...]
            let token = tailStr.prefix(while: { !$0.isWhitespace })
            return Double(token)
        }
        let items = session.filter { $0.contains("GEN8_CA ITEM") }
        XCTAssertEqual(items.count, 73, "expected 73 ITEM decisions in final session")
        let ftm = items.compactMap { value($0, "firstTrustworthyMs") }.sorted()
        let mem = session.compactMap { value($0, "memoryMB") }.max() ?? 0
        let merges = items.compactMap { value($0, "merge") }.sorted()
        let news = items.compactMap { value($0, "new") }.sorted()
        func pct(_ a: [Double], _ p: Double) -> Double { a.isEmpty ? 0 : a[min(a.count - 1, Int(Double(a.count) * p))] }
        print("AUDIT_FINAL ftmP50=\(pct(ftm, 0.5)) ftmP95=\(pct(ftm, 0.95)) maxMemMB=\(mem)")
        print("AUDIT_FINAL mergeP50=\(pct(merges, 0.5)) mergeP75=\(pct(merges, 0.75)) mergeMax=\(merges.last ?? -1) newP50=\(pct(news, 0.5))")
        // cross-check the report's claims: S p50 0.21, p75 0.37, max 0.68, N p50 0.65
        XCTAssertEqual(pct(merges, 0.5), 0.21, accuracy: 0.001)
        XCTAssertEqual(pct(merges, 0.75), 0.37, accuracy: 0.001)
        XCTAssertEqual(merges.last ?? -1, 0.68, accuracy: 0.001)
        XCTAssertEqual(pct(news, 0.5), 0.65, accuracy: 0.001)
    }
}
