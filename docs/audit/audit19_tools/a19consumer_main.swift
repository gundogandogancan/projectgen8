// AUDIT19 — NORMAL (non-@testable) CONSUMER of GuardianCore.
// Proves §6 (public mint(fromJSON:) self-root reachable without @testable) and §10
// (makeSyntheticTestRoot is `internal`, NOT reachable from a normal consumer).
import Foundation
import CryptoKit
import GuardianCore

// §6: ORDINARY CONSUMER self-mints a verified reviewer trust root from attacker JSON.
let attackerKey = Curve25519.Signing.PrivateKey()
let keyHex = attackerKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
let json = """
{"root_id":"rwc-root-consumer01","public_key_raw_hex":"\(keyHex)","algorithm":"ed25519",\
"status":"ACTIVE","activation_date":"2026-01-01","governance_record_id":"rwc-gov-consumer"}
"""
do {
    let root = try RWCReviewerTrustRootLoaderV1.mint(fromJSON: Data(json.utf8))
    print("A19_CONSUMER_SELFROOT_OK rootID=\(root.rootID)")
} catch {
    print("A19_CONSUMER_SELFROOT_REFUSED \(error)")
}

// §10: attempt to reach the SYNTHETIC factory from a normal consumer. This line is COMMENTED because
// it does NOT COMPILE from a non-@testable consumer (makeSyntheticTestRoot is `internal`). Proof of
// the access barrier is the compile failure when uncommented (verified separately by the auditor).
// _ = RWCReviewerTrustRootLoaderV1.makeSyntheticTestRoot()

print("A19_CONSUMER_DONE")
