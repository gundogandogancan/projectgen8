import Foundation

// MARK: - Personal Algorithm v0, Semantic Shield v0, Positive Exposure v0, Spiritual Lens (contract only)
// Ref: Build Bible §46–§48, §161–§166, §9/§421, §425–§426; PROMPT 001 §19–§22. All inspectable/editable.

public enum GuardianMode: String, Sendable, CaseIterable {
    case learn = "LEARN", focus = "FOCUS", create = "CREATE", work = "WORK"
    case discover = "DISCOVER", relax = "RELAX", entertainment = "ENTERTAINMENT", balance = "BALANCE"
}

/// A Semantic Shield rule. Hard exclusions outrank the Personal Algorithm threshold (ADR-0007).
public struct SemanticShieldRule: Sendable, Equatable, Hashable {
    public enum Kind: String, Sendable { case concept, category, entity }
    public let kind: Kind
    public let value: String        // concept text / category raw / entity name
    public let hard: Bool           // hard exclusion vs soft down-rank
    public init(kind: Kind, value: String, hard: Bool) {
        self.kind = kind; self.value = value; self.hard = hard
    }
}

/// Positive Exposure policy — a PERSONAL/PRODUCT policy, NOT a statement about factual truth (§8 Prompt 000).
public struct PositiveExposurePolicy: Sendable, Equatable {
    /// Categories the user chooses to down-rank/avoid.
    public let avoid: Set<SensitiveCategory>
    public init(avoid: Set<SensitiveCategory>) { self.avoid = avoid }
}

/// Spiritual Wellbeing Lens — CONTRACT ONLY in P001. Must never affect the evidence/truth score,
/// never make medical claims, never emit a numeric "frequency" (Bible §425–§426, §547).
public struct SpiritualLensPreference: Sendable, Equatable {
    public let enabled: Bool
    public let note: String         // free-text interpretive preference; purely informational
    public init(enabled: Bool, note: String = "") { self.enabled = enabled; self.note = note }
}

/// Deterministic, inspectable, user-editable profile (natural-language setup would compile to this).
public struct PersonalAlgorithmProfile: Sendable, Equatable {
    public var version: String
    public var mode: GuardianMode
    public var minimumPersonalScore: Double          // e.g. 7.5
    public var preferredTopics: [String]
    public var shieldRules: [SemanticShieldRule]
    public var positiveExposure: PositiveExposurePolicy
    public var spiritualLens: SpiritualLensPreference
    /// Whether this device/session is a "controlled surface" (we can truly pre-filter/hide).
    public var controlledSurface: Bool

    public init(version: String = "pa-v0",
                mode: GuardianMode = .balance,
                minimumPersonalScore: Double = 7.5,
                preferredTopics: [String] = [],
                shieldRules: [SemanticShieldRule] = [],
                positiveExposure: PositiveExposurePolicy = .init(avoid: []),
                spiritualLens: SpiritualLensPreference = .init(enabled: false),
                controlledSurface: Bool = true) {
        self.version = version
        self.mode = mode
        self.minimumPersonalScore = minimumPersonalScore
        self.preferredTopics = preferredTopics
        self.shieldRules = shieldRules
        self.positiveExposure = positiveExposure
        self.spiritualLens = spiritualLens
        self.controlledSurface = controlledSurface
    }
}

/// A fixture "child safety floor" policy (contract-level) so precedence can be proven in tests.
public struct SafetyPolicy: Sendable, Equatable {
    public let childMode: Bool
    public let blockedCategoriesForChild: Set<SensitiveCategory>
    public init(childMode: Bool = false, blockedCategoriesForChild: Set<SensitiveCategory> = []) {
        self.childMode = childMode
        self.blockedCategoriesForChild = blockedCategoriesForChild
    }
}
