import Foundation

// MARK: - Multimodal Personal Shield (PROMPT 006A §2–§17, corrected by 006B §1–§4,§9)
// Personal preference ≠ global truth. UNKNOWN IS NOT A MATCH. UNAVAILABLE IS NOT A MATCH.
// Matchers emit signal; the controller may abstain (NO_SHIELD_DECISION); STRICT HOLD belongs to global Admission.

public enum ShieldInputType: String, Sendable, Codable, CaseIterable {
    case textExact = "TEXT_EXACT", textPhrase = "TEXT_PHRASE", semanticConcept = "SEMANTIC_CONCEPT"
    case entity = "ENTITY", source = "SOURCE", imageReference = "IMAGE_REFERENCE", logoReference = "LOGO_REFERENCE"
    case audioReference = "AUDIO_REFERENCE", spokenReference = "SPOKEN_REFERENCE", musicTrack = "MUSIC_TRACK"
    case musicArtist = "MUSIC_ARTIST", soundClass = "SOUND_CLASS", customMultimodal = "CUSTOM_MULTIMODAL"
}
public enum ShieldAuthority: String, Sendable, Codable { case user = "USER", guardian = "GUARDIAN", systemSafetyFloor = "SYSTEM_SAFETY_FLOOR" }

public enum ShieldAction: String, Sendable, Codable {
    case allow = "ALLOW", allowWithNote = "ALLOW_WITH_NOTE", warn = "WARN", ask = "ASK"
    case hideIfControlled = "HIDE_IF_CONTROLLED", blurIfControlled = "BLUR_IF_CONTROLLED"
    case muteIfControlled = "MUTE_IF_CONTROLLED", skipIfControlledAndAligned = "SKIP_IF_CONTROLLED_AND_ALIGNED"
}

/// 006B §1 — the Shield distinguishes ACTUAL matches from "I cannot determine". The latter is NOT a match.
public enum ShieldMatchState: String, Sendable, Codable {
    // Determinable outcomes
    case noMatch = "NO_MATCH"
    case matchLow = "MATCH_LOW", matchMedium = "MATCH_MEDIUM", matchHigh = "MATCH_HIGH", matchExact = "MATCH_EXACT"
    // Non-determinable: the Shield itself cannot tell whether the rule matches. NOT safe, NOT matched, NOT auto-hold.
    case matchabilityUnknown = "MATCHABILITY_UNKNOWN"
    case matcherUnavailable = "MATCHER_UNAVAILABLE"
    case evidenceConflict = "EVIDENCE_CONFLICT"

    /// True only for an actual positive match tier.
    public var isMatch: Bool { self == .matchLow || self == .matchMedium || self == .matchHigh || self == .matchExact }
    /// True when the Shield could not determine matchability (never equals "safe").
    public var isNonDeterminable: Bool { self == .matchabilityUnknown || self == .matcherUnavailable || self == .evidenceConflict }
    /// Rank used ONLY to select the strongest actual match; non-determinable states never outrank a real match.
    public var matchRank: Int {
        switch self {
        case .matchExact: return 5; case .matchHigh: return 4; case .matchMedium: return 3; case .matchLow: return 2
        case .noMatch: return 1
        case .matchabilityUnknown, .matcherUnavailable, .evidenceConflict: return 0
        }
    }
}

public enum ShieldReasonCode: String, Sendable, Codable {
    case exactText = "SHIELD_EXACT_TEXT_MATCH", alias = "SHIELD_ALIAS_MATCH", semantic = "SHIELD_SEMANTIC_CONCEPT_MATCH"
    case ocr = "SHIELD_OCR_MATCH", transcript = "SHIELD_TRANSCRIPT_MATCH", visualReference = "SHIELD_VISUAL_REFERENCE_MATCH"
    case logo = "SHIELD_LOGO_MATCH", audioClass = "SHIELD_AUDIO_CLASS_MATCH", musicIdentity = "SHIELD_MUSIC_IDENTITY_MATCH"
    case sourceMatch = "SHIELD_SOURCE_MATCH"
    case crossLanguageVerified = "SHIELD_CROSS_LANGUAGE_VERIFIED", crossLanguageDowngraded = "SHIELD_CROSS_LANGUAGE_DOWNGRADED"
    case lowConfidence = "SHIELD_LOW_CONFIDENCE", conflicting = "SHIELD_CONFLICTING_EVIDENCE", none = "SHIELD_NO_MATCH"
    case matcherUnavailable = "SHIELD_MATCHER_UNAVAILABLE", matchabilityUnknown = "SHIELD_MATCHABILITY_UNKNOWN"
    case referenceReauthoring = "SHIELD_REFERENCE_REAUTHORING_REQUIRED"
}

/// Stable matcher identifiers used for rule-specific routing (006B §3).
public enum ShieldMatcherID: String, Sendable, Codable, CaseIterable {
    case exactText = "exact-text", alias = "alias-entity", source = "source", soundClass = "sound-class"
    case semantic = "semantic-text", visualReference = "visual-reference", musicIdentity = "music-identity"
    case spokenPhrase = "spoken-phrase"
}

public struct ShieldRuleV2: Sendable, Codable, Equatable {
    public static let schemaVersion = "shield-rule-v2"
    public var ruleID: String
    public var ownerScope: String
    public var authority: ShieldAuthority
    public var inputType: ShieldInputType
    public var rawUserLabel: String
    public var canonicalConceptID: String?
    public var locale: String
    public var aliases: [String]
    public var referenceFeatureIDs: [String]      // derived fingerprints (NO raw media)
    public var allowedMatchers: [String]          // rule-specific routing; empty → defaults from inputType
    public var action: ShieldAction
    public var sourceScope: String?
    public var enabled: Bool
    public var privacyClass: String
    public var version: String
    // 006B durability fields
    public var createdAtEpoch: Double
    public var updatedAtEpoch: Double
    public var expiresAtEpoch: Double?
    public var referenceReauthoringRequired: Bool
    // 006C functional-state fields
    public var corrupt: Bool
    public var migrating: Bool

    public init(ruleID: String, ownerScope: String = "self", authority: ShieldAuthority = .user,
                inputType: ShieldInputType, rawUserLabel: String, canonicalConceptID: String? = nil,
                locale: String = "en", aliases: [String] = [], referenceFeatureIDs: [String] = [],
                allowedMatchers: [String] = [], action: ShieldAction = .warn, sourceScope: String? = nil,
                enabled: Bool = true, privacyClass: String = "sensitive-personal", version: String = schemaVersion,
                createdAtEpoch: Double = 0, updatedAtEpoch: Double = 0, expiresAtEpoch: Double? = nil,
                referenceReauthoringRequired: Bool = false, corrupt: Bool = false, migrating: Bool = false) {
        self.ruleID = ruleID; self.ownerScope = ownerScope; self.authority = authority; self.inputType = inputType
        self.rawUserLabel = rawUserLabel; self.canonicalConceptID = canonicalConceptID; self.locale = locale
        self.aliases = aliases; self.referenceFeatureIDs = referenceFeatureIDs; self.allowedMatchers = allowedMatchers
        self.action = action; self.sourceScope = sourceScope; self.enabled = enabled; self.privacyClass = privacyClass
        self.version = version; self.createdAtEpoch = createdAtEpoch; self.updatedAtEpoch = updatedAtEpoch
        self.expiresAtEpoch = expiresAtEpoch; self.referenceReauthoringRequired = referenceReauthoringRequired
        self.corrupt = corrupt; self.migrating = migrating
    }

    /// Default matchers for a rule's input type (006B §3) when `allowedMatchers` is not explicitly set.
    public static func defaultMatchers(for inputType: ShieldInputType) -> [ShieldMatcherID] {
        switch inputType {
        case .textExact, .textPhrase: return [.exactText, .alias]
        case .entity: return [.alias, .exactText]
        case .semanticConcept: return [.semantic, .exactText]
        case .source: return [.source]
        case .soundClass: return [.soundClass]
        case .imageReference, .logoReference: return [.visualReference]
        case .musicTrack, .musicArtist: return [.musicIdentity]
        case .audioReference: return [.soundClass]
        case .spokenReference: return [.spokenPhrase, .exactText]
        case .customMultimodal: return ShieldMatcherID.allCases
        }
    }
    /// Effective routing set: explicit allowedMatchers if present, else the input-type default.
    public var effectiveMatchers: Set<String> {
        allowedMatchers.isEmpty ? Set(Self.defaultMatchers(for: inputType).map { $0.rawValue }) : Set(allowedMatchers)
    }
    /// 006C §8 — explicit functional state. A non-functional durable record must NEVER appear active/protected.
    public func functionalState(nowEpoch: Double) -> ShieldRuleFunctionalState {
        if corrupt { return .corrupt }
        if migrating { return .migrating }
        if !enabled { return .paused }
        if let exp = expiresAtEpoch, exp <= nowEpoch { return .expired }
        if referenceReauthoringRequired { return .referenceReauthoringRequired }
        return .active
    }
    public func isActive(nowEpoch: Double) -> Bool { functionalState(nowEpoch: nowEpoch) == .active }
}

/// 006C §8 — the functional states a durable Shield record can be in. MATCHER_UNAVAILABLE is runtime-derived at eval.
public enum ShieldRuleFunctionalState: String, Sendable, Codable {
    case active = "ACTIVE", paused = "PAUSED", expired = "EXPIRED"
    case referenceReauthoringRequired = "REFERENCE_REAUTHORING_REQUIRED", matcherUnavailable = "MATCHER_UNAVAILABLE"
    case corrupt = "CORRUPT", migrating = "MIGRATING"
    /// States in which the rule still EXISTS but cannot currently protect — UI must say so, not claim active.
    public var isProtectingNow: Bool { self == .active }
}

/// 006C §11 — truthful classification of how durable each audio-input rule actually is. No implied parity with visual.
public enum AudioReferenceDurability: String, Sendable, Codable {
    case functionallyDurable = "FUNCTIONALLY_DURABLE"   // label-based; survives relaunch and matches live
    case metadataOnly = "METADATA_ONLY"                 // the rule persists but there is no durable acoustic matcher
    case matcherUnavailable = "MATCHER_UNAVAILABLE"     // the matcher does not exist on-device (e.g. music identity)
    case notImplemented = "NOT_IMPLEMENTED"
    public static func classify(_ inputType: ShieldInputType) -> AudioReferenceDurability {
        switch inputType {
        case .soundClass:       return .functionallyDurable   // SoundAnalysis class label persists & matches live events
        case .audioReference:   return .metadataOnly          // no stored acoustic fingerprint matcher this phase
        case .musicTrack, .musicArtist: return .matcherUnavailable   // ShazamKit identity UNAVAILABLE in lab
        case .spokenReference:  return .metadataOnly          // text-of-speech only; no acoustic/voice fingerprint (by design)
        default:                return .notImplemented
        }
    }
}

public struct ShieldMatchResult: Sendable, Equatable {
    public let ruleID: String
    public let matcherID: String
    public let state: ShieldMatchState
    public let rawConfidence: Double?
    public let calibratedConfidence: Double?
    public let reason: ShieldReasonCode
    public let modality: String
    public let engineVersion: String
    public init(ruleID: String, matcherID: String, state: ShieldMatchState, rawConfidence: Double?,
                calibratedConfidence: Double? = nil, reason: ShieldReasonCode, modality: String, engineVersion: String) {
        self.ruleID = ruleID; self.matcherID = matcherID; self.state = state; self.rawConfidence = rawConfidence
        self.calibratedConfidence = calibratedConfidence; self.reason = reason; self.modality = modality; self.engineVersion = engineVersion
    }
    public static func noMatch(_ id: String, matcherID: String) -> ShieldMatchResult {
        .init(ruleID: id, matcherID: matcherID, state: .noMatch, rawConfidence: nil, reason: .none, modality: "none", engineVersion: "shield-v2")
    }
}

// Matcher protocol — core stays dependency-free; semantic distance / bridges are injected.
public protocol ShieldMatcher: Sendable {
    var id: ShieldMatcherID { get }
    func handles(_ inputType: ShieldInputType) -> Bool
    func match(rule: ShieldRuleV2, envelope: ContentObservationEnvelope) -> ShieldMatchResult
}

private func norm(_ s: String) -> String { s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil) }

public struct ExactTextMatcher: ShieldMatcher {
    public init() {}
    public let id = ShieldMatcherID.exactText
    public func handles(_ t: ShieldInputType) -> Bool { [.textExact, .textPhrase, .entity, .semanticConcept, .spokenReference].contains(t) }
    public func match(rule: ShieldRuleV2, envelope: ContentObservationEnvelope) -> ShieldMatchResult {
        let needle = norm(rule.rawUserLabel)
        guard !needle.isEmpty else { return .noMatch(rule.ruleID, matcherID: id.rawValue) }
        for src in envelope.structuredText + envelope.captions + envelope.transcript + envelope.ocrText {
            if norm(src.text).contains(needle) {
                let reason: ShieldReasonCode = src.origin == .ocr ? .ocr : (src.origin == .transcript ? .transcript : .exactText)
                return ShieldMatchResult(ruleID: rule.ruleID, matcherID: id.rawValue, state: .matchExact, rawConfidence: 0.98,
                                         reason: reason, modality: "text", engineVersion: "exact-text-v1")
            }
        }
        return .noMatch(rule.ruleID, matcherID: id.rawValue)
    }
}

public struct AliasEntityMatcher: ShieldMatcher {
    public init() {}
    public let id = ShieldMatcherID.alias
    public func handles(_ t: ShieldInputType) -> Bool { [.entity, .textExact, .textPhrase].contains(t) }
    public func match(rule: ShieldRuleV2, envelope: ContentObservationEnvelope) -> ShieldMatchResult {
        let hay = (envelope.structuredText + envelope.captions + envelope.transcript + envelope.ocrText).map { norm($0.text) }.joined(separator: " ")
        for alias in ([rule.rawUserLabel] + rule.aliases) where !alias.isEmpty && hay.contains(norm(alias)) {
            return ShieldMatchResult(ruleID: rule.ruleID, matcherID: id.rawValue, state: .matchHigh,
                                     rawConfidence: 0.9, reason: .alias, modality: "text", engineVersion: "alias-v1")
        }
        return .noMatch(rule.ruleID, matcherID: id.rawValue)
    }
}

public struct SourceMatcher: ShieldMatcher {
    public init() {}
    public let id = ShieldMatcherID.source
    public func handles(_ t: ShieldInputType) -> Bool { t == .source }
    public func match(rule: ShieldRuleV2, envelope: ContentObservationEnvelope) -> ShieldMatchResult {
        guard let scope = rule.sourceScope?.lowercased() else { return .noMatch(rule.ruleID, matcherID: id.rawValue) }
        if let cid = envelope.contentID?.raw.lowercased(), cid.contains(scope) {
            return ShieldMatchResult(ruleID: rule.ruleID, matcherID: id.rawValue, state: .matchExact, rawConfidence: 0.97,
                                     reason: .sourceMatch, modality: "source", engineVersion: "source-v1")
        }
        return .noMatch(rule.ruleID, matcherID: id.rawValue)
    }
}

public struct SoundClassMatcher: ShieldMatcher {
    public init() {}
    public let id = ShieldMatcherID.soundClass
    public func handles(_ t: ShieldInputType) -> Bool { t == .soundClass || t == .audioReference }
    public func match(rule: ShieldRuleV2, envelope: ContentObservationEnvelope) -> ShieldMatchResult {
        // If there is no audio track at all, the matcher cannot determine → MATCHER_UNAVAILABLE (not NO_MATCH, not match).
        guard !envelope.soundEvents.isEmpty else {
            return ShieldMatchResult(ruleID: rule.ruleID, matcherID: id.rawValue, state: .matcherUnavailable, rawConfidence: nil,
                                     reason: .matcherUnavailable, modality: "audio", engineVersion: "sound-class-v1")
        }
        let needle = rule.rawUserLabel.lowercased()
        if envelope.soundEvents.contains(where: { $0.lowercased().contains(needle) }) {
            return ShieldMatchResult(ruleID: rule.ruleID, matcherID: id.rawValue, state: .matchHigh, rawConfidence: 0.85,
                                     reason: .audioClass, modality: "audio", engineVersion: "sound-class-v1")
        }
        return .noMatch(rule.ruleID, matcherID: id.rawValue)
    }
}

/// Verdict from a cross-language concept bridge (006B §9) — certification/concept-driven, not locale-string-driven.
public enum CrossLanguageVerdict: Sendable, Equatable {
    case sameLanguage                 // content and rule share locale — no bridge needed
    case verifiedCanonicalBridge      // both locales certified + canonical concept verified + calibrated → may stay HIGH
    case unverifiedBridge             // translation-only / uncertified / weak embedding → downgrade
    case unavailable                  // no bridge at all → non-determinable
}
public protocol CrossLanguageConceptBridge: Sendable {
    func verdict(ruleLocale: String, contentLocale: String, concept: String, canonicalConceptID: String?) -> CrossLanguageVerdict
}
/// Default bridge: same locale passes; any cross-locale is treated as UNVERIFIED (conservative) — never upgraded by MT.
public struct DefaultCrossLanguageBridge: CrossLanguageConceptBridge {
    public init() {}
    public func verdict(ruleLocale: String, contentLocale: String, concept: String, canonicalConceptID: String?) -> CrossLanguageVerdict {
        ruleLocale.lowercased() == contentLocale.lowercased() ? .sameLanguage : .unverifiedBridge
    }
}

/// Semantic matcher using an injected distance (0=identical..large=different) + an injected cross-language bridge.
public struct SemanticTextMatcher: ShieldMatcher {
    public let id = ShieldMatcherID.semantic
    public let distance: @Sendable (_ text: String, _ concept: String, _ locale: String) -> Double?
    public let bridge: CrossLanguageConceptBridge
    public init(distance: @escaping @Sendable (String, String, String) -> Double?, bridge: CrossLanguageConceptBridge = DefaultCrossLanguageBridge()) {
        self.distance = distance; self.bridge = bridge
    }
    public func handles(_ t: ShieldInputType) -> Bool { t == .semanticConcept }
    public func match(rule: ShieldRuleV2, envelope: ContentObservationEnvelope) -> ShieldMatchResult {
        let text = (envelope.structuredText + envelope.captions + envelope.transcript + envelope.ocrText).map { $0.text }.joined(separator: " ")
        // No embedding / no text → the matcher cannot determine. This is NOT a match and NOT safe.
        guard !text.isEmpty, let d = distance(text, rule.rawUserLabel, rule.locale) else {
            return ShieldMatchResult(ruleID: rule.ruleID, matcherID: id.rawValue, state: .matcherUnavailable, rawConfidence: nil,
                                     reason: .matcherUnavailable, modality: "text", engineVersion: "semantic-v1")
        }
        var state: ShieldMatchState = d < 0.85 ? .matchHigh : d < 1.05 ? .matchMedium : (d < 1.3 ? .matchLow : .noMatch)
        var reason: ShieldReasonCode = state == .noMatch ? .none : .semantic

        // 006B §9 — cross-language is governed by concept certification, not by locale strings differing.
        let contentLocale = envelope.languageSignals.first ?? rule.locale
        switch bridge.verdict(ruleLocale: rule.locale, contentLocale: contentLocale, concept: rule.rawUserLabel, canonicalConceptID: rule.canonicalConceptID) {
        case .sameLanguage, .verifiedCanonicalBridge:
            if state.isMatch, bridge.verdict(ruleLocale: rule.locale, contentLocale: contentLocale, concept: rule.rawUserLabel, canonicalConceptID: rule.canonicalConceptID) == .verifiedCanonicalBridge {
                reason = .crossLanguageVerified          // verified bridge keeps strength (may stay HIGH)
            }
        case .unverifiedBridge:
            if state == .matchHigh { state = .matchMedium; reason = .crossLanguageDowngraded }
            else if state == .matchMedium { state = .matchLow; reason = .crossLanguageDowngraded }
        case .unavailable:
            if state.isMatch { state = .matchabilityUnknown; reason = .matchabilityUnknown }
        }
        return ShieldMatchResult(ruleID: rule.ruleID, matcherID: id.rawValue, state: state,
                                 rawConfidence: max(0, 1 - d/2), reason: reason, modality: "text", engineVersion: "semantic-v1")
    }
}

// 006B §1/§2 — the Shield layer's own decision. It MAY ABSTAIN. Strict HOLD is NOT its job.
public enum ShieldLayerDecision: String, Sendable, Codable {
    case noShieldAction = "NO_SHIELD_ACTION"           // nothing to do (no match)
    case note = "NOTE"                                 // low-confidence: optional note, never a silent hide
    case warn = "WARN"
    case ask = "ASK"
    case execute = "EXECUTE"                           // configured action may run (high/exact)
    case noShieldDecision = "NO_SHIELD_DECISION"       // matchability unknown / matcher unavailable — Shield abstains
}

public struct ShieldActionControllerV2: Sendable {
    public init() {}
    /// Map a best MATCH state to the Shield layer's own decision. UNKNOWN/UNAVAILABLE → ABSTAIN (never auto warn/hold).
    public func decide(rule: ShieldRuleV2, match: ShieldMatchState) -> (decision: ShieldLayerDecision, action: ShieldAction?) {
        switch match {
        case .matchExact, .matchHigh:
            return (.execute, rule.action)                                  // configured action may execute if capability allows
        case .matchMedium:
            // destructive configured action is softened to ASK; otherwise WARN per user policy
            let destructive = rule.action == .hideIfControlled || rule.action == .skipIfControlledAndAligned || rule.action == .blurIfControlled
            return destructive ? (.ask, .ask) : (.warn, .warn)
        case .evidenceConflict:
            return (.ask, .ask)
        case .matchLow:
            return (.note, .allowWithNote)                                  // no silent hide
        case .noMatch:
            return (.noShieldAction, nil)
        case .matchabilityUnknown, .matcherUnavailable:
            return (.noShieldDecision, nil)                                 // ABSTAIN — global Admission decides, not the Shield
        }
    }
}
