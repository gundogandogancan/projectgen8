import Foundation

// MARK: - Shield index + exceptions + corrections (PROMPT 006A §13,§14,§15,§16,§40)
// Bounded layered index — do NOT iterate every rule × every item. Cheap retrieval → shortlist → expensive matchers.

public struct ShieldIndex: Sendable {
    public static let indexVersion = "shield-index-v2"
    public private(set) var rules: [String: ShieldRuleV2] = [:]
    private var textTokenIndex: [String: Set<String>] = [:]   // normalized token → ruleIDs
    private var sourceIndex: [String: Set<String>] = [:]
    private var semanticRuleIDs: Set<String> = []
    // Reverse maps so remove() is O(tokens-of-rule), not O(all keys) — keeps rebuild/startup bounded (006B §16).
    private var ruleTokens: [String: Set<String>] = [:]
    private var ruleSource: [String: String] = [:]
    public init() {}

    /// Crash-safe deterministic rebuild from the durable rule set (the index is always derivable — never authoritative).
    public static func rebuilt(from rules: [ShieldRuleV2]) -> ShieldIndex {
        var idx = ShieldIndex()
        for r in rules { idx.insertFresh(r) }               // O(tokens) per rule → O(total tokens), not O(N²)
        return idx
    }

    private mutating func insertFresh(_ rule: ShieldRuleV2) {
        rules[rule.ruleID] = rule
        if rule.inputType == .semanticConcept { semanticRuleIDs.insert(rule.ruleID) }
        var toks = Set<String>()
        for tok in tokens(rule.rawUserLabel) + rule.aliases.flatMap(tokens) { textTokenIndex[tok, default: []].insert(rule.ruleID); toks.insert(tok) }
        ruleTokens[rule.ruleID] = toks
        if let s = rule.sourceScope?.lowercased() { sourceIndex[s, default: []].insert(rule.ruleID); ruleSource[rule.ruleID] = s }
    }

    public mutating func upsert(_ rule: ShieldRuleV2) {
        remove(rule.ruleID)                                   // incremental: drop stale entries before re-adding
        insertFresh(rule)
    }
    /// Delete removes the rule AND every stale index entry — a deleted rule can never match from cache (006B §8).
    public mutating func remove(_ ruleID: String) {
        guard rules[ruleID] != nil || ruleTokens[ruleID] != nil else { return }
        rules[ruleID] = nil; semanticRuleIDs.remove(ruleID)
        for tok in ruleTokens[ruleID] ?? [] { textTokenIndex[tok]?.remove(ruleID); if textTokenIndex[tok]?.isEmpty == true { textTokenIndex[tok] = nil } }
        ruleTokens[ruleID] = nil
        if let s = ruleSource[ruleID] { sourceIndex[s]?.remove(ruleID); if sourceIndex[s]?.isEmpty == true { sourceIndex[s] = nil }; ruleSource[ruleID] = nil }
    }
    public var count: Int { rules.count }

    /// Cheap shortlist of ACTIVE rules only (paused/expired/reauthoring excluded). NOT O(all rules × tokens).
    public func shortlist(envelope: ContentObservationEnvelope, nowEpoch: Double = 0, maxSemantic: Int = 32) -> [ShieldRuleV2] {
        var ids = Set<String>()
        let text = (envelope.structuredText + envelope.captions + envelope.transcript + envelope.ocrText).map { $0.text }.joined(separator: " ")
        for tok in tokens(text) { if let s = textTokenIndex[tok] { ids.formUnion(s) } }
        if let cid = envelope.contentID?.raw.lowercased() { for (src, s) in sourceIndex where cid.contains(src) { ids.formUnion(s) } }
        ids.formUnion(semanticRuleIDs.prefix(maxSemantic))   // semantic rules shortlisted (bounded)
        return ids.compactMap { rules[$0] }.filter { $0.isActive(nowEpoch: nowEpoch) }
    }

    private func tokens(_ s: String) -> [String] {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
         .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 3 }
    }
}

// §14 Exceptions / allowlist with explicit precedence.
public struct ShieldException: Sendable, Equatable, Codable {
    public enum Scope: String, Sendable, Codable { case item, source, account, session, time, category, userInitiated }
    public let scope: Scope
    public let value: String
    public let allowsOverrideOfGuardianRule: Bool
    public init(scope: Scope, value: String, allowsOverrideOfGuardianRule: Bool = false) {
        self.scope = scope; self.value = value; self.allowsOverrideOfGuardianRule = allowsOverrideOfGuardianRule
    }
}

public struct ShieldExceptionEngine: Sendable {
    public init() {}
    /// Returns true if an exception allows this content past the rule. Guardian/system-floor rules are NOT overridable
    /// by a user exception (child safety precedence) unless explicitly guardian-authorized.
    public func allows(rule: ShieldRuleV2, exceptions: [ShieldException], matchedSource: String?, userInitiated: Bool) -> Bool {
        if rule.authority == .systemSafetyFloor { return false }
        for ex in exceptions {
            if rule.authority == .guardian && !ex.allowsOverrideOfGuardianRule { continue }   // child/guardian precedence
            switch ex.scope {
            case .source: if let s = matchedSource?.lowercased(), s.contains(ex.value.lowercased()) { return true }
            case .userInitiated: if userInitiated { return true }
            case .session, .account, .item, .time, .category:
                if ex.value.lowercased() == rule.rawUserLabel.lowercased() || ex.value == rule.ruleID { return true }
            }
        }
        return false
    }
}

// §13 Personal correction loop — local only; never retrains global models.
public enum ShieldCorrection: Sendable {
    case notWhatIMeant, alwaysBlock, allowSource(String), allowItem, allowSession, makeNarrower, makeBroader, pause, delete
}
public struct ShieldCorrectionApplier: Sendable {
    public init() {}
    /// Apply a correction to a rule; returns the updated rule (nil = delete). Local personal state only.
    public func apply(_ c: ShieldCorrection, to rule: ShieldRuleV2) -> ShieldRuleV2? {
        var r = rule
        switch c {
        case .delete: return nil
        case .pause: r.enabled = false
        case .makeNarrower: r.inputType = .textExact; r.aliases = []
        case .makeBroader: if r.inputType == .textExact { r.inputType = .semanticConcept }
        case .alwaysBlock: r.action = .hideIfControlled
        case .notWhatIMeant: r.enabled = false        // disable until user re-specifies
        case .allowSource, .allowItem, .allowSession: break   // handled via ShieldException, not rule mutation
        }
        return r
    }
}
