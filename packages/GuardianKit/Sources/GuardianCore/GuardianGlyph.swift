import Foundation

// MARK: - Guardian Glyph Engine (PROMPT 006A §18–§25, corrected by 006B §10,§11,§12)
// TWO SEPARATE AXES. A positive content glyph can NEVER override a protection/admission signal.
// Precedence: STRONG_PROTECTION > SHIELD_MATCH > CAUTION/CONFLICT > UNKNOWN/ANALYZING > CONTENT CHARACTER.

/// Axis 1 — what the content IS (never a safety claim).
public enum GlyphContentCharacter: String, Sendable, Codable {
    case humor, learning, music, calm, creativity, entertainment, neutral, none
}
/// Axis 2 — the Guardian / admission state (safety-bearing).
public enum GlyphGuardianState: String, Sendable, Codable {
    case strongProtection = "STRONG_PROTECTION", shieldMatch = "SHIELD_MATCH", cautionConflict = "CAUTION_CONFLICT"
    case unknown = "UNKNOWN", analyzing = "ANALYZING", aligned = "ALIGNED"
}

public enum GlyphFamily: String, Sendable, Codable {
    case analyzing = "ANALYZING", neutral = "NEUTRAL", unknown = "UNKNOWN"
    case learning = "LEARNING", humorPositive = "HUMOR_POSITIVE", creativity = "CREATIVITY"
    case calmNature = "CALM_NATURE", music = "MUSIC", entertainment = "ENTERTAINMENT"
    case caution = "CAUTION", shieldMatch = "SHIELD_MATCH", strongProtection = "STRONG_PROTECTION"
}

public enum GlyphStyle: String, Sendable, Codable { case minimalSymbols = "MINIMAL", emoji = "EMOJI", off = "OFF", auto = "AUTO" }

public struct GlyphToken: Sendable, Equatable {
    public let family: GlyphFamily
    public let symbolName: String
    public let emoji: String
    public let label: String
    public let isTruthfulSafeClaim: Bool   // false when state is unknown/stale → UI must not render "safe"
    public let isProtectionSignal: Bool    // true for guardian-state families (outranks content character)
}

public struct GlyphInputs: Sendable {
    public var shieldState: ShieldMatchState
    public var strongProtection: Bool
    public var coverageUnknown: Bool
    public var analyzing: Bool
    public var contentCharacter: GlyphContentCharacter
    public var minConfidence: Double
    public init(shieldState: ShieldMatchState = .noMatch, strongProtection: Bool = false, coverageUnknown: Bool = false,
                analyzing: Bool = false, contentCharacter: GlyphContentCharacter = .neutral, minConfidence: Double = 1.0) {
        self.shieldState = shieldState; self.strongProtection = strongProtection; self.coverageUnknown = coverageUnknown
        self.analyzing = analyzing; self.contentCharacter = contentCharacter; self.minConfidence = minConfidence
    }
}

public struct GuardianGlyphEngine: Sendable {
    public init() {}

    /// Derive the safety-bearing guardian axis from the Shield match state (006B §1 semantics respected).
    public func guardianState(for i: GlyphInputs) -> GlyphGuardianState {
        if i.strongProtection { return .strongProtection }
        switch i.shieldState {
        case .matchExact, .matchHigh, .matchMedium: return .shieldMatch
        case .evidenceConflict: return .cautionConflict
        case .matchabilityUnknown, .matcherUnavailable: return .unknown
        case .matchLow, .noMatch:
            if i.coverageUnknown || i.minConfidence < 0.45 { return .unknown }
            if i.analyzing { return .analyzing }
            return .aligned
        }
    }

    /// 006B §10 FIREWALL — guardian state outranks content character. Returns the PRIMARY family to display.
    public func primaryFamily(content: GlyphContentCharacter, guardian: GlyphGuardianState) -> GlyphFamily {
        switch guardian {
        case .strongProtection: return .strongProtection
        case .shieldMatch:       return .shieldMatch
        case .cautionConflict:   return .caution
        case .unknown:           return .unknown
        case .analyzing:         return .analyzing
        case .aligned:
            switch content {
            case .humor: return .humorPositive
            case .learning: return .learning
            case .music: return .music
            case .calm: return .calmNature
            case .creativity: return .creativity
            case .entertainment: return .entertainment
            case .neutral, .none: return .neutral
            }
        }
    }

    public func family(for i: GlyphInputs) -> GlyphFamily {
        primaryFamily(content: i.contentCharacter, guardian: guardianState(for: i))
    }

    public func token(for i: GlyphInputs, style: GlyphStyle) -> GlyphToken? {
        style == .off ? nil : token(for: family(for: i), style: style)
    }

    public func token(for f: GlyphFamily, style: GlyphStyle) -> GlyphToken {
        let truthfulSafe = !(f == .unknown || f == .analyzing)
        let isProtection = (f == .strongProtection || f == .shieldMatch || f == .caution)
        // 006B §11 wording — plain, non-diagnostic, no "healthy" claim.
        let (sym, emo, label): (String, String, String)
        switch f {
        case .analyzing:        (sym, emo, label) = ("ellipsis.circle", "⏳", "Analyzing")
        case .neutral:          (sym, emo, label) = ("circle", "⚪️", "Neutral")
        case .unknown:          (sym, emo, label) = ("questionmark.circle", "❓", "Unknown")
        case .learning:         (sym, emo, label) = ("book", "📘", "Learning")
        case .humorPositive:    (sym, emo, label) = ("face.smiling", "🙂", "Humor")
        case .creativity:       (sym, emo, label) = ("paintpalette", "🎨", "Creativity")
        case .calmNature:       (sym, emo, label) = ("leaf", "🌿", "Calm")
        case .music:            (sym, emo, label) = ("music.note", "🎵", "Music")
        case .entertainment:    (sym, emo, label) = ("play.circle", "🎬", "Entertainment")
        case .caution:          (sym, emo, label) = ("exclamationmark.triangle", "⚠️", "Caution")
        case .shieldMatch:      (sym, emo, label) = ("eye.slash", "🛡️", "Matches your Shield")
        case .strongProtection: (sym, emo, label) = ("shield.lefthalf.filled", "🛡️", "Strong protection")
        }
        return GlyphToken(family: f, symbolName: sym, emoji: style == .emoji ? emo : "",
                          label: label, isTruthfulSafeClaim: truthfulSafe, isProtectionSignal: isProtection)
    }
}

// §22 Stabilization — no jitter. Safety families commit immediately; positive families must be stable first.
public final class GuardianGlyphStabilizer: @unchecked Sendable {
    private let lock = NSLock()
    private var currentContentID: String?
    private var candidate: GlyphFamily?
    private var candidateStreak = 0
    private var committed: GlyphFamily = .analyzing
    private let requiredStreak: Int
    private let minConfidence: Double
    public init(requiredStreak: Int = 2, minConfidence: Double = 0.45) {
        self.requiredStreak = requiredStreak; self.minConfidence = minConfidence
    }
    public func observe(contentID: String, raw: GlyphFamily, confidence: Double) -> GlyphFamily {
        lock.lock(); defer { lock.unlock() }
        if contentID != currentContentID {
            currentContentID = contentID; candidate = raw; candidateStreak = 1; committed = .analyzing
            return .analyzing
        }
        if raw == .strongProtection || raw == .shieldMatch || raw == .caution {   // protection must not lag
            committed = raw; candidate = raw; candidateStreak = requiredStreak; return raw
        }
        if confidence < minConfidence { return committed == .analyzing ? .unknown : committed }
        if raw == candidate { candidateStreak += 1 } else { candidate = raw; candidateStreak = 1 }
        if candidateStreak >= requiredStreak { committed = raw }
        return committed == .analyzing ? .analyzing : committed
    }
    public func reset() { lock.lock(); currentContentID = nil; candidate = nil; candidateStreak = 0; committed = .analyzing; lock.unlock() }
}

// §24 / 006B §12 — surface state carries content identity + monotonic sequence. Stale OR out-of-order → never safe.
public struct GlyphSurfaceState: Sendable {
    public let token: GlyphToken
    public let contentID: String
    public let sequence: UInt64
    public let computedAtNanos: UInt64
    public let staleAfterNanos: UInt64
    public init(token: GlyphToken, contentID: String, sequence: UInt64, computedAtNanos: UInt64, staleAfterNanos: UInt64) {
        self.token = token; self.contentID = contentID; self.sequence = sequence
        self.computedAtNanos = computedAtNanos; self.staleAfterNanos = staleAfterNanos
    }
    public func render(nowNanos: UInt64, engine: GuardianGlyphEngine = GuardianGlyphEngine(), style: GlyphStyle) -> GlyphToken {
        let age = nowNanos >= computedAtNanos ? nowNanos - computedAtNanos : 0
        if age > staleAfterNanos { return engine.token(for: .unknown, style: style) }   // never stale-green
        return token
    }
}

/// 006B §12 — enforces content-identity + ordering so a delayed update for old content can't show a stale positive glyph.
public final class GlyphSurfaceController: @unchecked Sendable {
    private let lock = NSLock()
    private let engine = GuardianGlyphEngine()
    private var current: GlyphSurfaceState?
    public init() {}

    /// Apply an update. Rejected (returns neutral/unknown of the CURRENT truth) if it is out-of-order or for old content.
    @discardableResult
    public func apply(_ update: GlyphSurfaceState, style: GlyphStyle) -> GlyphToken {
        lock.lock(); defer { lock.unlock() }
        if let cur = current {
            if update.contentID == cur.contentID && update.sequence < cur.sequence {
                return cur.token                                  // out-of-order late update → reject, keep current
            }
            if update.contentID != cur.contentID && update.sequence < cur.sequence {
                return engine.token(for: .unknown, style: style)  // stale update for different/old content → never positive
            }
        }
        current = update
        return update.token
    }

    /// App-controlled truth: a content change invalidates the prior glyph IMMEDIATELY (shows analyzing, not stale positive).
    public func contentChanged(to contentID: String, sequence: UInt64, style: GlyphStyle) -> GlyphToken {
        lock.lock(); defer { lock.unlock() }
        let analyzing = engine.token(for: .analyzing, style: style)
        current = GlyphSurfaceState(token: analyzing, contentID: contentID, sequence: sequence, computedAtNanos: 0, staleAfterNanos: .max)
        return analyzing
    }

    /// App paused / Guardian off: never keep a positive glyph alive.
    public func invalidate(style: GlyphStyle) -> GlyphToken {
        lock.lock(); defer { lock.unlock() }
        current = nil
        return engine.token(for: .unknown, style: style)
    }
    public func currentToken() -> GlyphToken? { lock.lock(); defer { lock.unlock() }; return current?.token }
}
