//
//  YouTubeMetadataConnectorV1.swift — R11-C P1: the NARROWLY-SCOPED, OFFLINE-FIRST, OFFICIAL-API-ONLY YouTube metadata
//  connector (mandate §7 / document-2 §3).
//
//  WHAT IT IS: a protocol-transport connector that, GIVEN a LAWFULLY-OBTAINED verified video id (from a user-provided
//  URL / share-extension contract / app-controlled player context), can retrieve the official `videos.list`
//  metadata and surface it as PLATFORM_METADATA_EVIDENCE. It is OFFLINE-FIRST: the transport is a protocol so tests
//  inject fixtures; the real live-network transport (app-layer) sits behind an API-key config that is ABSENT by default, so the
//  connector honestly reports UNAVAILABLE and makes NO network call unless a key is configured and consent is given.
//
//  THE HARD PROBLEM (mandate §7): the difficulty is NOT fetching metadata — it is reliably KNOWING the real id of the
//  video on screen. ReplayKit frames do NOT carry a YouTube id. So this connector accepts a VERIFIED_VIDEO_ID ONLY,
//  from a LAWFUL source. Screen-OCR title similarity is NEVER promoted to a verified id (pinned by test). No scraping,
//  no undocumented endpoints, no sandbox id-extraction.
//
//  METADATA ≠ VIDEO UNDERSTOOD (mandate §7.2): the retrieved snippet/contentDetails enter the world model as
//  PLATFORM_METADATA_EVIDENCE — a context hint, provenance-marked, coverage UNAFFECTED. A known duration is NOT known
//  content; a title is a hint (clickbait is possible). It can NEVER independently establish harm/learning/suitability.
//
//  PRIVACY (mandate §7.1): an external API call is a USER CONSENT GATE. Default: no key, no consent → UNAVAILABLE, no
//  network. HTTPS only, quota accounting, TTL cache, graceful unavailable/offline, wrong-id handling.
//
//  Pure value types + a protocol transport + an optional live-transport SHELL (contains no networking code; inert without a key).
//  Lives in GuardianMedia (GuardianCore frozen).
//
import Foundation

// MARK: - §7 verified-id intake (the ONLY legitimate source of an id)

/// R11 §7 — HOW an id became known. A verified id MUST originate from a lawful source; an OCR title guess is NOT one.
public enum YouTubeVideoIDSourceV1: String, Sendable, Equatable, Codable {
    case userProvidedURL   = "USER_PROVIDED_URL"     // the user pasted / shared a youtube URL
    case shareExtension    = "SHARE_EXTENSION"       // arrived via the share-extension contract
    case appControlledPlayer = "APP_CONTROLLED_PLAYER" // our own in-app player context knows the id
    case verifiedDeepLink  = "VERIFIED_DEEP_LINK"    // a legitimately resolved deep link
    // NOTE: there is DELIBERATELY no `.screenOCRGuess` case — an OCR title similarity can never be a verified id.
}

/// R11 §7 — a VERIFIED video id: the 11-char id + its lawful source. The only input the connector accepts. Minting one
/// requires passing through `YouTubeVideoIDParserV1`, which rejects malformed ids and non-URL inputs.
public struct VerifiedYouTubeVideoIDV1: Sendable, Equatable, Codable {
    public let videoID: String
    public let source: YouTubeVideoIDSourceV1
    public init(videoID: String, source: YouTubeVideoIDSourceV1) { self.videoID = videoID; self.source = source }
}

/// R11 §7 — parse + VALIDATE a user-provided URL / id string into a verified id. Supports the youtube.com watch,
/// youtu.be short, and shorts URL forms. Returns nil for anything that is not a well-formed youtube id (an 11-char
/// base64url-ish token). This is the gate: a title string or arbitrary text can NEVER produce a verified id.
public enum YouTubeVideoIDParserV1 {
    /// A YouTube video id is 11 characters of [A-Za-z0-9_-].
    public static func isWellFormedID(_ id: String) -> Bool {
        guard id.count == 11 else { return false }
        return id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }

    /// Parse a URL (or a bare 11-char id) into a verified id with the given lawful source. nil on any malformed input.
    public static func parse(_ raw: String, source: YouTubeVideoIDSourceV1) -> VerifiedYouTubeVideoIDV1? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Bare id form.
        if isWellFormedID(trimmed) { return VerifiedYouTubeVideoIDV1(videoID: trimmed, source: source) }
        guard let comps = URLComponents(string: trimmed), let host = comps.host?.lowercased() else { return nil }
        let candidate: String?
        if host.contains("youtu.be") {
            // youtu.be/<id>
            candidate = comps.path.split(separator: "/").first.map(String.init)
        } else if host.contains("youtube.com") || host.contains("youtube-nocookie.com") {
            if comps.path.hasPrefix("/watch") {
                candidate = comps.queryItems?.first(where: { $0.name == "v" })?.value
            } else if comps.path.hasPrefix("/shorts/") || comps.path.hasPrefix("/embed/") || comps.path.hasPrefix("/v/") {
                candidate = comps.path.split(separator: "/").dropFirst().first.map(String.init)
            } else {
                candidate = nil
            }
        } else {
            candidate = nil   // not a youtube host → never a verified id
        }
        guard let id = candidate, isWellFormedID(id) else { return nil }
        return VerifiedYouTubeVideoIDV1(videoID: id, source: source)
    }

    /// EXPLICIT anti-OCR guard (mandate §7): a screen-OCR title string is NEVER a verified id. Always nil, pinned by
    /// test. This exists so the contract is named + unavoidable at the call site.
    public static func parseFromScreenOCRTitle(_ title: String) -> VerifiedYouTubeVideoIDV1? { nil }
}

// MARK: - §7 the official videos.list response model (snippet + contentDetails)

/// R11 §7 — the official `videos.list(part=snippet,contentDetails)` response model, trimmed to the lawful public
/// fields. All optional (a field may be absent / restricted). `durationSeconds` is parsed from the ISO-8601 PT form.
public struct YouTubeVideoMetadataV1: Sendable, Equatable, Codable {
    public let videoID: String
    public let channelID: String?
    public let title: String?
    public let description: String?
    public let tags: [String]
    public let publishedAtEpoch: Double?
    public let durationSeconds: Double?
    public let captionsAvailable: Bool?
    /// Region/age restriction indicators (availability), when present — never a safety verdict, just platform facts.
    public let madeForKids: Bool?
    public let regionRestricted: Bool?
    public init(videoID: String, channelID: String? = nil, title: String? = nil, description: String? = nil,
                tags: [String] = [], publishedAtEpoch: Double? = nil, durationSeconds: Double? = nil,
                captionsAvailable: Bool? = nil, madeForKids: Bool? = nil, regionRestricted: Bool? = nil) {
        self.videoID = videoID; self.channelID = channelID; self.title = title; self.description = description
        self.tags = tags; self.publishedAtEpoch = publishedAtEpoch; self.durationSeconds = durationSeconds
        self.captionsAvailable = captionsAvailable; self.madeForKids = madeForKids; self.regionRestricted = regionRestricted
    }

    /// Parse an ISO-8601 duration (e.g. "PT1H2M3S", "PT45S") into seconds. nil on malformed.
    public static func parseISODuration(_ iso: String) -> Double? {
        guard iso.hasPrefix("PT") else { return nil }
        var seconds = 0.0; var num = ""
        for ch in iso.dropFirst(2) {
            if ch.isNumber { num.append(ch) }
            else {
                guard let v = Double(num) else { return nil }
                switch ch { case "H": seconds += v * 3600; case "M": seconds += v * 60; case "S": seconds += v
                default: return nil }
                num = ""
            }
        }
        return seconds
    }
}

// MARK: - §7 the connector outcome (honest availability)

public enum YouTubeMetadataOutcomeV1: Sendable, Equatable {
    case metadata(YouTubeVideoMetadataV1)
    case cached(YouTubeVideoMetadataV1)                 // served from the TTL cache (no network)
    case unavailableNoAPIKey                            // default: no key configured → no network, honest UNAVAILABLE
    case unavailableNoConsent                           // consent gate not granted → no network
    case unavailableOffline                             // transport reported no connectivity
    case unavailableQuotaExceeded                       // quota accounting blocked the call
    case videoNotFound                                  // wrong/deleted/private id (official 404/empty)
    case transportError(String)                         // any other transport failure (string, never a crash)
}

// MARK: - §7 the transport protocol (fixtures in tests; a live transport may exist only OUTSIDE GuardianKit (app layer))

/// R11 §7 — the transport abstraction. Tests inject a fixture transport; a real network transport must live in the APP layer (GuardianKit ships none)
/// (compiled but inert without an API key). The transport returns the RAW decoded metadata or an availability error —
/// it never decides evidence semantics (that is the bridge mapping, below).
public protocol YouTubeMetadataTransportV1: Sendable {
    func fetch(videoID: String) -> YouTubeMetadataOutcomeV1
}

/// R11 §7 — a configuration holder. `apiKey == nil` (the DEFAULT) means the connector is UNAVAILABLE and makes NO
/// network call. `consentGranted` is the explicit user consent gate for external calls.
public struct YouTubeConnectorConfigV1: Sendable, Equatable {
    public let apiKey: String?
    public let consentGranted: Bool
    public let cacheTTLSeconds: Double
    /// A coarse daily quota budget for accounting (the real API has unit costs; videos.list is ~1 unit/call).
    public let dailyQuotaUnits: Int
    public init(apiKey: String? = nil, consentGranted: Bool = false,
                cacheTTLSeconds: Double = 24 * 3600, dailyQuotaUnits: Int = 10_000) {
        self.apiKey = apiKey; self.consentGranted = consentGranted
        self.cacheTTLSeconds = max(0, cacheTTLSeconds); self.dailyQuotaUnits = max(0, dailyQuotaUnits)
    }
    /// The honest DEFAULT: no key, no consent → connector is inert.
    public static let absent = YouTubeConnectorConfigV1()
}

// MARK: - §7 the connector

/// R11 §7 — the connector. OFFLINE-FIRST: verified-id intake only, consent + key gated, TTL cache, quota accounting,
/// graceful unavailable. On a successful fetch it also produces the PLATFORM_METADATA_EVIDENCE provenance string for
/// the bridge mapping. Serial by NSLock for the in-memory cache + quota counter.
public final class YouTubeMetadataConnectorV1: @unchecked Sendable {
    public static let version = "youtube-metadata-connector-v1"

    private let transport: YouTubeMetadataTransportV1
    private let config: YouTubeConnectorConfigV1
    private let lock = NSLock()
    private var cache: [String: (metadata: YouTubeVideoMetadataV1, epoch: Double)] = [:]
    private var quotaUsedUnits = 0

    public init(transport: YouTubeMetadataTransportV1, config: YouTubeConnectorConfigV1 = .absent) {
        self.transport = transport; self.config = config
    }

    public var quotaUsed: Int { lock.lock(); defer { lock.unlock() }; return quotaUsedUnits }

    /// R11 §7 — fetch metadata for a VERIFIED id. Order of honest gates: consent → key → cache → quota → transport.
    /// A verified id is REQUIRED (the type system enforces lawful provenance). Returns an honest outcome, never a
    /// fabricated success.
    public func metadata(for verified: VerifiedYouTubeVideoIDV1, nowEpoch: Double) -> YouTubeMetadataOutcomeV1 {
        lock.lock(); defer { lock.unlock() }
        // CACHE first (served WITHOUT network / consent — it is derived data we already lawfully retrieved).
        if let hit = cache[verified.videoID], (nowEpoch - hit.epoch) < config.cacheTTLSeconds {
            return .cached(hit.metadata)
        }
        // CONSENT gate — an external call needs explicit consent (mandate §7.1).
        guard config.consentGranted else { return .unavailableNoConsent }
        // KEY gate — no key → no network (the honest default).
        guard config.apiKey != nil else { return .unavailableNoAPIKey }
        // QUOTA accounting (videos.list ≈ 1 unit).
        guard quotaUsedUnits < config.dailyQuotaUnits else { return .unavailableQuotaExceeded }
        quotaUsedUnits += 1
        let outcome = transport.fetch(videoID: verified.videoID)
        if case let .metadata(m) = outcome { cache[verified.videoID] = (m, nowEpoch) }
        return outcome
    }

    /// R11 §7.2 — the PLATFORM_METADATA_EVIDENCE provenance string for a retrieved metadata. Named so the bridge/proof
    /// log always marks platform metadata as a CONTEXT HINT, never a content analysis.
    public static func platformEvidenceProvenance(for m: YouTubeVideoMetadataV1, source: YouTubeVideoIDSourceV1) -> String {
        "\(version): PLATFORM_METADATA_EVIDENCE (videos.list snippet/contentDetails; verified-id source=\(source.rawValue); metadata is a CONTEXT HINT — title/duration known ≠ video understood; coverage UNAFFECTED; never a harm/suitability verdict)"
    }
}

// MARK: - §7 a fixture transport (tests) + a live-transport SHELL (no networking code; inert)

/// R11 §7 — the fixture transport for offline tests: a fixed map of id → outcome. No network. Default miss = notFound.
public struct YouTubeFixtureTransportV1: YouTubeMetadataTransportV1 {
    public let fixtures: [String: YouTubeMetadataOutcomeV1]
    public init(fixtures: [String: YouTubeMetadataOutcomeV1]) { self.fixtures = fixtures }
    public func fetch(videoID: String) -> YouTubeMetadataOutcomeV1 { fixtures[videoID] ?? .videoNotFound }
}

/// R11 §7 — the live-transport SHELL. Contains NO networking primitives (GuardianKit law: no telemetry/upload path); INERT without an API key: with no key it returns
/// `.unavailableNoAPIKey` and makes NO network call (so even if wired by mistake, nothing leaks). The actual HTTPS
/// request + JSON decoding are left as a thin, documented shell — this round ships NO live call (no key infra exists).
public struct YouTubeLiveTransportShellV1: YouTubeMetadataTransportV1 {
    public let apiKey: String?
    public init(apiKey: String? = nil) { self.apiKey = apiKey }
    public func fetch(videoID: String) -> YouTubeMetadataOutcomeV1 {
        // HONEST: no key → no network. A live call is OUT OF SCOPE this round (mandate: never fabricate live API
        // success). When a key infra genuinely exists, the HTTPS videos.list request + decode would go here, behind
        // the connector's consent/quota/TTL gates. We deliberately do not simulate a live success.
        guard apiKey != nil else { return .unavailableNoAPIKey }
        return .unavailableOffline
    }
}
