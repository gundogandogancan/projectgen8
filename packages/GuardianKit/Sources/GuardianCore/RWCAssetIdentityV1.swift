import Foundation

// MARK: - RWC-PRE-02 — CANONICAL OPAQUE ASSET-ID CONTRACT (closes BLK-A11-IDCHARSET + BLK-A11-COMPOSITE-ALIAS).
//
// LAW (frozen pre-data):
//  - Asset IDs are OPAQUE and NON-SEMANTIC: `rwc-asset-` + 8…32 chars of [a-z0-9] only.
//  - ASCII-ONLY, byte-validated. NO normalization is ever performed: input must already be canonical;
//    NFC/NFD variants, Cyrillic/Latin lookalikes, uppercase, whitespace (incl. newline/tab — the
//    A11-IDCHARSET class), control characters and over/under-length are all TYPED REFUSALS, never
//    silently fixed (fail closed — a validator that "repairs" IDs is an aliasing machine).
//  - `#` (the composite separator) is FORBIDDEN inside every component — aliasing via separator
//    injection (the A11-COMPOSITE-ALIAS class) is structurally impossible: a composite therefore
//    contains EXACTLY one `#`. No escaping scheme exists by design (forbidding is safer than escaping).
//  - Case law: lowercase-only grammar; comparison is byte-exact (case-sensitive by construction since
//    uppercase never validates). Serialization = the validated ASCII bytes, verbatim.
//  - Diagnostics carry index/character-class only — never raw content (IDs are non-semantic by law,
//    but the error channel still refuses to echo arbitrary junk bytes).

public enum RWCAssetIdentityErrorV1: Error, Equatable {
    case empty
    case nonASCII(index: Int)
    case controlOrWhitespace(index: Int)          // includes newline/tab/space — A11-IDCHARSET closure
    case separatorForbidden(index: Int)           // '#' inside a component — A11-COMPOSITE-ALIAS closure
    case badPrefix                                // asset IDs must start with "rwc-asset-"
    case forbiddenCharacter(index: Int)           // outside [a-z0-9] (assets) / [a-z0-9-] (profiles)
    case badLength(actual: Int, minimum: Int, maximum: Int)
    case compositeShape(separators: Int)          // composite must contain exactly one '#'
}

public enum RWCAssetIdentityV1 {
    public static let version = "rwc-asset-identity-v1"
    public static let assetPrefix = "rwc-asset-"
    public static let assetTokenLength = 8...32           // token after the prefix
    public static let profileLength = 3...40
    public static let separator: Character = "#"

    /// Byte-level screen shared by every component: ASCII-only, no control/whitespace, no '#'.
    static func screen(_ s: String) -> RWCAssetIdentityErrorV1? {
        if s.isEmpty { return .empty }
        for (i, u) in s.unicodeScalars.enumerated() {
            if !u.isASCII { return .nonASCII(index: i) }
            if u.value < 0x21 || u.value == 0x7F { return .controlOrWhitespace(index: i) }  // space, \n, \t, controls
            if u == "#" { return .separatorForbidden(index: i) }
        }
        return nil
    }

    /// Canonical RWC asset ID: `rwc-asset-` + [a-z0-9]{8,32}. Nil = valid.
    public static func validateAssetID(_ id: String) -> RWCAssetIdentityErrorV1? {
        if let e = screen(id) { return e }
        guard id.hasPrefix(assetPrefix) else { return .badPrefix }
        let token = String(id.dropFirst(assetPrefix.count))
        guard assetTokenLength.contains(token.count) else {
            return .badLength(actual: token.count, minimum: assetTokenLength.lowerBound, maximum: assetTokenLength.upperBound)
        }
        for (i, u) in token.unicodeScalars.enumerated() {
            let ok = (u >= "a" && u <= "z") || (u >= "0" && u <= "9")
            if !ok { return .forbiddenCharacter(index: assetPrefix.count + i) }   // uppercase/underscore/dash all refused
        }
        return nil
    }

    /// RWC profile ID: [a-z0-9-]{3,40}, no leading/trailing '-', no '--'. Nil = valid.
    public static func validateProfileID(_ id: String) -> RWCAssetIdentityErrorV1? {
        if let e = screen(id) { return e }
        guard profileLength.contains(id.count) else {
            return .badLength(actual: id.count, minimum: profileLength.lowerBound, maximum: profileLength.upperBound)
        }
        for (i, u) in id.unicodeScalars.enumerated() {
            let ok = (u >= "a" && u <= "z") || (u >= "0" && u <= "9") || u == "-"
            if !ok { return .forbiddenCharacter(index: i) }
        }
        if id.hasPrefix("-") || id.hasSuffix("-") || id.contains("--") { return .forbiddenCharacter(index: 0) }
        return nil
    }

    /// Collision-safe composite: components cannot contain the separator, so `asset#profile` is
    /// unambiguous and parse∘make is the identity. Exactly one '#' by construction and by validation.
    public static func composite(assetID: String, profileID: String) throws -> String {
        if let e = validateAssetID(assetID) { throw e }
        if let e = validateProfileID(profileID) { throw e }
        return assetID + String(separator) + profileID
    }

    public static func parseComposite(_ composite: String) throws -> (assetID: String, profileID: String) {
        let parts = composite.split(separator: separator, omittingEmptySubsequences: false)
        guard parts.count == 2 else { throw RWCAssetIdentityErrorV1.compositeShape(separators: parts.count - 1) }
        let a = String(parts[0]), p = String(parts[1])
        if let e = validateAssetID(a) { throw e }
        if let e = validateProfileID(p) { throw e }
        return (a, p)
    }
}
