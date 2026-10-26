//
//  Tier1IdentityResolutionV1.swift — P1 (PRODUCT): Tier-1 verdict RESOLVES the content identity that the
//  Guardian evaluates against — BEFORE evidence binding, not a post-hoc log line.
//
//  WHY THIS EXISTS (product mandate P1):
//  Previously the broadcast path ran Guardian evaluation against the TIER-0 proposed identity
//  ("item-<tier0.itemID>") and only AFTERWARD ran Tier1ItemIdentityV1 — whose SAME/NEW/UNKNOWN verdict was
//  merely logged. That means a Tier-0 false-merge (two different videos grouped as one item — the measured
//  Outcome C failure) could let the Guardian keep evaluating against — or worse, REUSE a safe/protective
//  decision for — a DIFFERENT piece of content. That is false safe-state inheritance across items (constitution
//  rule 7: UNKNOWN ≠ BAD; rule: no stale Protected state). This resolver closes that gap:
//
//    Tier-0 PROPOSES an item id  →  Tier-1 CONFIRMS/OVERRIDES  →  RESOLVED identity  →  Guardian binds evidence
//                                                                    to the RESOLVED id.
//
//  SAFETY LAWS encoded here (headless-testable; pure; no Vision / no GuardianCore import needed — Tier-0 and
//  Tier-1 context enter as plain values):
//   L1  Tier-1 NEW overrides a Tier-0 SAME  → a FRESH identity id is minted; the Guardian never reuses the
//       prior item's decision/evidence for it.
//   L2  Strong SAME-vs-NEW CONTRADICTION (Tier-0 opened a new item, Tier-1 says SAME with real confidence, OR
//       Tier-0 said same but Tier-1 says NEW) is NEVER silently resolved to a protective/safe reuse: the
//       contradiction forces a NEW, UNKNOWN identity that must be RE-EVALUATED from scratch (safe-by-isolation).
//   L3  Tier-1 UNKNOWN (honest abstention) DEFERS to the Tier-0 proposal — it neither invents a new split nor
//       forces a merge. (Matches Tier1ItemIdentityV1's own abstention law.)
//   L4  A capture GENERATION token travels with every resolution. An ASYNC result (e.g. OCR / feature print that
//       completes late) carries the generation that was current WHEN THE FRAME WAS CAPTURED; if the live
//       generation has advanced (the item changed underneath it), the stale result is DROPPED, never attached to
//       whatever item happens to be current now. This is the cross-item stale-evidence firewall.
//
//  This type mints product-facing content ids and revisions in the extension/orchestration layer; it does NOT
//  reach into GuardianCore's ContentItemGroupingEngineV2 identity (frozen). Tier-0's own itemID/itemRevision are
//  carried as provenance so the derived proof log can still line the two up.
//
import Foundation

// MARK: - Capture generation token (the stale-evidence firewall)

/// Monotonic per-session token. One generation = "the identity the Guardian is currently bound to". It advances
/// whenever the resolved identity changes (new/contradiction). Async work stamps the generation it was STARTED
/// under; `isStale(_:)` drops anything whose generation the live resolver has already moved past.
public struct CaptureGenerationV1: Sendable, Codable, Equatable, Comparable {
    public let value: UInt64
    public init(_ value: UInt64) { self.value = value }
    public static func < (a: CaptureGenerationV1, b: CaptureGenerationV1) -> Bool { a.value < b.value }
    public static let zero = CaptureGenerationV1(0)
    public func next() -> CaptureGenerationV1 { CaptureGenerationV1(value &+ 1) }
}

// MARK: - Capture token (A1 FIX: SOURCE CORRELATION, not pre-resolution generation guessing)
//
// WHY (A1 — the measured defect): the previous firewall stamped OCR with `liveGeneration` BEFORE resolve() ran.
// But resolving a SAME-FRAME new item ADVANCES the generation — so the OCR that belongs EXACTLY to the item just
// minted was dropped as "stale". A pre-resolution generation cannot distinguish "same-frame evidence for the new
// id" from "late evidence that arrived from an earlier item". Only the SOURCE the evidence was captured from can.
//
// FIX: every piece of evidence carries the SHOT it was captured from (`CaptureTokenV1.shotID`). The resolver records
// the shot that MINTED (or continues) the current identity. Evidence is accepted iff it was captured from the SAME
// shot that the current identity is bound to; evidence from an EARLIER shot is rejected. Same-frame OCR for a
// freshly minted id now correlates correctly; genuinely late OCR from a prior shot/item is still refused.

/// A capture-moment token: which SESSION + committed SHOT an async result was produced from, plus the live
/// generation at capture time (kept only for the legacy ordering check / diagnostics — correlation is by shot
/// identity within the session).
///
/// A2 (cross-session firewall): the token now carries the SESSION id it was captured under. A new broadcast
/// session mints shot ids starting from 1 again, so a bare shotID=1 from a PREVIOUS session could otherwise be
/// mistaken for this session's shot 1 and accepted. Binding the session id makes a stale token from an old
/// session REJECTED even when the shot id repeats.
public struct CaptureTokenV1: Sendable, Equatable {
    public let sessionID: String
    public let shotID: UInt64
    public let generation: CaptureGenerationV1
    public init(sessionID: String, shotID: UInt64, generation: CaptureGenerationV1) {
        self.sessionID = sessionID; self.shotID = shotID; self.generation = generation
    }
    /// Back-compat initializer (no session scoping — used by pure unit tests that only assert shot/generation
    /// algebra). Session defaults to empty, which the resolver treats as "unscoped": it matches any session id.
    public init(shotID: UInt64, generation: CaptureGenerationV1) {
        self.sessionID = ""; self.shotID = shotID; self.generation = generation
    }
}

// MARK: - Reason codes (B3 "Neden?" — REAL engine facts → short Turkish user strings)
//
// WHY (B3): the user-facing "Neden?" explanation must be generated from REAL engine facts, never fabricated.
// This enum is the single mapping from decision-path facts to short, jargon-free Turkish strings. Categories we
// cannot substantiate are shown HONESTLY (no invented reason). Lives in GuardianMedia (ungoverned) and is
// dual-compiled into the app + extension exactly like the resolver.

public enum GuardianReasonCodeV1: String, Sendable, Equatable, Codable {
    case textEvidenceMatchedShield   // OCR text matched a personal shield term
    case textEvidenceBenign          // OCR text present, no shield/caution signal
    case contentChangedReset         // content changed → prior decision invalidated
    case newIdentityUnconfirmed      // new content whose identity is not yet confirmed
    case visualEvidenceInsufficient  // visual (Tier-1) signal not yet sufficient
    case textEvidenceUnavailable     // OCR did not run / produced nothing for this item
    case observingNoDecisionYet      // session active, no per-content decision produced yet
    case sessionNotObserving         // broadcast not active / IPC unavailable → cannot claim protection
    case observingIdle               // §5.4 — broadcast live but USER-CONTROLLED IDLE: heavy analysis paused, no claim
    case guardianOff                 // Guardian disabled by the user
    // §A — Guardian is OFF but the OS broadcast is STILL physically live (the red bar keeps running — we never claim
    // we stopped it; iOS owns that). Heavy analysis is short-circuited; no new decision is produced. Distinct from
    // `guardianOff` (which implies nothing about the OS feed) so the surface copy can say the OS feed continues.
    case guardianOffBroadcastContinuing
    // B4 — personal filters. The warning case is the HONEST copy for a 3rd-party (uncontrolled) app: we WARN, we do
    // NOT hide/skip. `preferenceAppliedWarnOnly` is the applied-preference reason on an uncontrolled surface.
    case personalShieldWarnOnly      // a personal shield rule matched; on a 3rd-party app we can only WARN, not hide
    // R2 §B/§C — a PERSONAL PHOTO (visual reference) matched the live frame. KEPT DISTINCT from the text shield reason
    // so the surface never conflates a VISUAL personal match with a text/wellbeing signal: a perceptual match is a
    // PERSONAL MATCH ("you asked not to see this image"), never a claim about what the image means (§C). WARN-only on
    // a 3rd-party app (rule 18) — we cannot hide another app's screen.
    case personalPhotoMatchWarnOnly
    // R3 §1 — GENERAL CONTENT-CHARACTER CAUTION. The MAIN wellbeing intelligence (NOT the personal shield): the OCTOPUS
    // language/OCR expert found a SUPPORTED sensitive-content MARKER ("işaret") in the on-screen text. KEPT DISTINCT
    // from every personal-shield reason so a general wellbeing caution is NEVER conflated with a user avoidance match
    // (§3/§5). A lexicon marker is a RISK MARKER, never a certainty of psychological harm — the copy says "işaret".
    case generalContentCaution
    // R3 §1 — general character EXAMINED, no supported marker. Honest benign (evidence examined), never "safe".
    case generalContentExaminedNoMarker
    // C1 — DISTINCT applied-action reasons on OUR controlled player. Each is the honest copy for the real action the
    // ONE policy decision asked for (blur / mute / warn / skip / ask), never a HIDE disguise.
    case shieldBlurApplied           // BLUR_IF_CONTROLLED: a match → the video keeps playing under a blur overlay
    case shieldMuteApplied           // MUTE_IF_CONTROLLED: a match → audio muted, image per policy
    case shieldWarnApplied           // WARN: a medium/low match → a visible warning, content still plays
    case shieldAskApproval           // ASK: a match requires the user's explicit approval before exposure
    case shieldSkipApplied           // SKIP_IF_CONTROLLED_AND_ALIGNED: a match → a real transition past this item
    // R3 §1 — the general brain could not analyze content character (no OCR text / unsupported language). UNKNOWN ≠ safe.
    case generalContentNotAnalyzed
    // R4 §4 — CONTEXT-ASSESSED: a sensitive marker fired AND the Context Evidence Adapter inferred the SPEAKER'S
    // STANCE from linguistic structure (negation / quotation / subject-action-object role). Two DISTINCT outcomes,
    // both DISTINCT from the plain `generalContentCaution` so the user can see that context was actually read:
    //  • `generalContentContextCaution` — the stance is ADVOCACY (the content promotes/endorses the harm). The
    //    caution is KEPT (and conceptually raised): a real risk signal with context backing it, never dropped.
    case generalContentContextCaution
    //  • `generalContentContextSoftened` — the stance is REPORTING / CRITICISM / VICTIM-SUPPORT. The marker is STILL
    //    present (we examined WITH context) but it is no longer a plain alarm — an examined-with-context NOTE. This is
    //    explicitly NOT a "safe" claim; it says "the marker is here, but the content reports/criticizes the harm".
    case generalContentContextSoftened
    // R5 §5 — EMOTIONAL REGISTER pressure (fear-pressure / coercive threat / sensational panic / urgency-via-fear).
    // A SEPARATE dimension from stance: a REPORTS stance NEVER clears this signal (the adjudicator law). The copy is
    // honest: a structural delivery-register finding, never a measured psychological-harm verdict.
    case emotionalRegisterPressureCaution
    // R5 §3 — CHILD/FAMILY policy outcomes from the REAL frozen ChildAgePolicyEngineV1 on the live path. Each is a
    // DEVELOPMENTAL policy outcome (source class carried by the engine) — never presented as a legal rating.
    case childAgeUnknownReview       // evidence insufficient for the child band → fail-closed review (NOT "unsafe")
    case childAgeCaution             // evidence-backed caution for the entered age band
    case childAgeRestricted          // strong evidence under the restricted age band (or parent block preference)
    // R5 §2 — the shared family profile could not be read as CURRENT (missing-after-active / stale / corrupt) while a
    // child/teen mode was last known active. Fail-closed: the old child policy is NEVER shown as current.
    case familyProfileUnavailable
    // R6 §4 + ADDENDUM — TARGETED PRESSURE / COVERT MANIPULATION caution. A structural TARGET/ACT/MECHANISM finding
    // (a directed personal demeaning/threat, or a covert influence mechanism — guilt/shame coercion, provocation
    // incitement, fear→action, social-comparison, deceptive urgency) in the viewer-directed text. DISTINCT from the
    // generic register caution so the user sees WHICH structural pressure was found. A heuristic/structural signal —
    // never an "abuse detector" verdict, never a measured psychological-harm claim.
    case targetedPressureCaution
    // R6 §3.2 — a SECONDARY safety evidence preserved alongside the primary (dual-evidence): the content both matched
    // a personal avoidance rule AND is age-restricted for the child. The primary reason follows canonical precedence
    // (child floor first); this records that the OTHER evidence was NOT erased (surfaced in provenance/timeline).
    case dualEvidenceChildPlusPersonal

    /// Short, jargon-free Turkish explanation. NEVER invents a conclusion: unsupported categories are explicit.
    public var turkishExplanation: String {
        switch self {
        case .textEvidenceMatchedShield:  return "Ekrandaki metinde kişisel kalkanınla eşleşen bir ifade algılandı."
        case .textEvidenceBenign:         return "Ekrandaki metin incelendi; kalkanınla eşleşen bir ifade bulunmadı."
        case .contentChangedReset:        return "İçerik değiştiği için önceki değerlendirme sıfırlandı."
        case .newIdentityUnconfirmed:     return "Yeni içeriğin kimliği henüz doğrulanamadı."
        case .visualEvidenceInsufficient: return "Görsel kanıt henüz yeterli değil."
        case .textEvidenceUnavailable:    return "Bu içerik için metin kanıtı henüz elde edilemedi."
        case .observingNoDecisionYet:     return "Gözlem sürüyor; bu içerik için henüz bir karar oluşmadı."
        case .sessionNotObserving:        return "Yayın etkin değil; koruma şu an doğrulanamıyor."
        case .observingIdle:              return "Rölantidesin: ağır analizi sen duraklattın. Yayın sürüyor ama şu an içerik incelenmiyor."
        case .guardianOff:                return "Guardian kapalı."
        case .guardianOffBroadcastContinuing: return "Guardian kapalı: içerik analizi durdu. Sistem ekran yayını (kırmızı çubuk) iOS tarafından hâlâ sürüyor; onu durdurmak için yayını kendin kapat."
        case .personalShieldWarnOnly:     return "Kişisel kalkanınla eşleşen bir ifade algılandı. Bu başka bir uygulama olduğu için içeriği gizleyemeyiz; yalnızca uyarıyoruz."
        case .personalPhotoMatchWarnOnly: return "Görmek istemediğin bir fotoğraf referansınla görsel olarak eşleşen bir içerik algılandı. Bu başka bir uygulama olduğu için içeriği gizleyemeyiz; yalnızca uyarıyoruz. (Bu yalnızca görsel benzerliktir; içeriğin anlamı hakkında bir iddia değildir.)"
        case .generalContentCaution:      return "Dikkat — hassas içerik işaretleri. Ekrandaki metinde hassas içerik işaretleri (örn. ölüm, felaket, manipülasyon dili) bulundu. Bu bir işarettir; içeriğin kesin olarak zararlı olduğu anlamına gelmez. Eğitici bir içerik de aynı işaretleri taşıyabilir."
        case .generalContentExaminedNoMarker: return "Ekrandaki metin incelendi; hassas içerik işareti bulunmadı. Bu 'güvenli' güvencesi değil; yalnızca bu metinde bir işaret görülmediği anlamına gelir."
        case .generalContentNotAnalyzed:  return "Genel içerik karakteri incelenemedi: metin kanıtı yok ya da dili desteklenmiyor. Bu 'güvenli' anlamına gelmez."
        case .generalContentContextCaution: return "Dikkat — bağlam analizi yapıldı. Ekrandaki metinde hassas içerik işareti var ve dil yapısı (kim, ne diyor) bu zararı destekler/teşvik eder gibi görünüyor. Bu bir işarettir; yine de kesin bir zarar hükmü değildir."
        case .generalContentContextSoftened: return "Bağlamıyla incelendi. Ekrandaki metinde hassas bir işaret var, ancak dil yapısı bunun bir haber/eleştiri/mağdur desteği olduğunu gösteriyor. İşaret hâlâ mevcut; bu 'güvenli' güvencesi değildir, yalnızca bağlamın alarm olmadığıdır."
        case .shieldBlurApplied:          return "Kişisel tercihinle eşleşti. Tercihin 'bulanıklaştır' olduğu için görüntü bulanık gösteriliyor; video sürüyor."
        case .shieldMuteApplied:          return "Kişisel tercihinle eşleşti. Tercihin 'sesi kıs' olduğu için ses kapatıldı; görüntü sürüyor."
        case .shieldWarnApplied:          return "Kişisel tercihinle olası bir eşleşme var. Bu bir uyarı; içerik oynatılıyor."
        case .shieldAskApproval:          return "Kişisel tercihinle eşleşti. Göstermeden önce onayını istiyoruz."
        case .shieldSkipApplied:          return "Kişisel tercihinle eşleşti. Tercihin 'atla' olduğu için bu içerik geçildi."
        case .emotionalRegisterPressureCaution: return "Dikkat — duygusal baskı işaretleri. Metnin anlatım biçimi yapısal olarak korku/aciliyet baskısı taşıyor (izleyiciye doğrudan hitap, koşullu tehdit veya korku→eylem bağlantısı). Haber/eleştiri tutumu bu işareti otomatik temizlemez. Bu bir işarettir; ölçülmüş bir psikolojik etki iddiası değildir."
        case .childAgeUnknownReview:      return "Aile profili etkin: bu içeriğin yaş uygunluğu mevcut kanıtla belirlenemedi (görsel yüksek-risk taraması bu sürümde yok). İnceleme önerilir — bu 'güvenli' anlamına gelmez, 'zararlı' anlamına da gelmez."
        case .childAgeCaution:            return "Aile profili etkin: içerikte, girilen yaş bandı için dikkat gerektiren işaretler var (gelişimsel politika — yasal bir derecelendirme değildir)."
        case .childAgeRestricted:         return "Aile profili etkin: içerik işaretleri bu yaş bandı için kısıtlı düzeyde (gelişimsel politika — yasal bir derecelendirme değildir)."
        case .familyProfileUnavailable:   return "Aile profili okunamadı veya güncel değil; çocuk koruması şu an doğrulanamıyor. Eski profil güncelmiş gibi gösterilmez — profil ekranından kontrol et."
        case .targetedPressureCaution:    return "Dikkat — hedefli baskı işaretleri. Metnin yapısı izleyiciye yönelik bir baskı mekanizması taşıyor (ör. kişiye yönelik aşağılama/tehdit, ya da suçluluk/utanç, tahrik, korku→eylem, sahte aciliyet gibi örtülü yönlendirme). Bu yapısal bir işarettir; bir kişiyi/kurumu eleştirmek tek başına buna girmez ve bu ölçülmüş bir zarar iddiası değildir."
        case .dualEvidenceChildPlusPersonal: return "Bu içerik hem kişisel kaçınma kuralınla eşleşiyor hem de aile profili için yaşa uygun değil. Birincil neden çocuk güvenlik önceliğiyle seçildi; kişisel eşleşme kanıtı silinmedi, kayıtlarda tutuluyor."
        }
    }
}

// MARK: - Resolved identity (what the Guardian binds evidence to)

/// How the resolved identity relates to the immediately prior resolved identity — drives whether the Guardian may
/// reuse a prior decision at all.
public enum ResolvedIdentityRelationV1: String, Sendable, Codable {
    case continuation = "CONTINUATION"          // same content item as before → prior decision context may continue
    case newConfirmed = "NEW_CONFIRMED"         // a new item both tiers agree on → fresh evaluation
    case newContradiction = "NEW_CONTRADICTION" // tiers disagreed strongly → fresh evaluation, UNKNOWN, isolated
    case unknownDeferred = "UNKNOWN_DEFERRED"   // Tier-1 abstained → kept Tier-0's proposal (may be same or new)
}

public struct ResolvedContentIdentityV1: Sendable, Equatable {
    /// The id the Guardian MUST bind evidence to (e.g. passed as CrossAppObservation contentID).
    public let contentID: String
    /// Monotonic revision of the RESOLVED identity (distinct from Tier-0's itemRevision; increments on every new id).
    public let revision: Int
    /// Live capture generation after this resolution (stamp async work with this).
    public let generation: CaptureGenerationV1
    public let relation: ResolvedIdentityRelationV1
    /// True only when the Guardian may legitimately CONTINUE a prior decision against this id. False on every new
    /// item/contradiction/abstention-into-new — forcing a from-scratch evaluation (no safe-state inheritance).
    public let mayReusePriorDecision: Bool
    /// Compact derived reason (never raw content).
    public let reason: String
    /// Provenance: the Tier-0 ids this resolution was derived from (for the proof log; never authoritative alone).
    public let tier0ItemID: UInt64
    public let tier0ItemRevision: Int
    public let tier1Verdict: Tier1IdentityVerdictV1?
    public let tier1Confidence: Double
    /// B3/C-lane: the user-facing reason code for THIS resolution (identity-level — "why is there a new/continued
    /// decision context"). Bound to the SAME resolved identity so the "Neden?" string can never drift to another
    /// item. The Guardian evaluation refines this with an evidence-level code once text/visual evidence is known.
    public let reasonCode: GuardianReasonCodeV1

    public init(contentID: String, revision: Int, generation: CaptureGenerationV1,
                relation: ResolvedIdentityRelationV1, mayReusePriorDecision: Bool, reason: String,
                tier0ItemID: UInt64, tier0ItemRevision: Int,
                tier1Verdict: Tier1IdentityVerdictV1?, tier1Confidence: Double,
                reasonCode: GuardianReasonCodeV1) {
        self.contentID = contentID; self.revision = revision; self.generation = generation
        self.relation = relation; self.mayReusePriorDecision = mayReusePriorDecision; self.reason = reason
        self.tier0ItemID = tier0ItemID; self.tier0ItemRevision = tier0ItemRevision
        self.tier1Verdict = tier1Verdict; self.tier1Confidence = tier1Confidence
        self.reasonCode = reasonCode
    }
}

// MARK: - Tier-0 proposal (plain scalars — mirrors ContentItemGroupingEngineV2's decision, no Core import)

public struct Tier0IdentityProposalV1: Sendable, Equatable {
    public let itemID: UInt64
    public let itemRevision: Int
    public let openedNewItem: Bool
    public init(itemID: UInt64, itemRevision: Int, openedNewItem: Bool) {
        self.itemID = itemID; self.itemRevision = itemRevision; self.openedNewItem = openedNewItem
    }
}

// MARK: - The resolver (stateful per session; serial by contract, same as the Tier-1 tracker)

/// Resolves the identity the Guardian evaluates against by fusing the Tier-0 proposal with the Tier-1 verdict.
/// One instance per broadcast session. Pure/headless (no Vision, no Core).
public final class Tier1IdentityResolverV1 {
    /// Minimum Tier-1 confidence for a contradiction (Tier-1 SAME against a Tier-0 NEW, or Tier-1 NEW against a
    /// Tier-0 SAME) to be treated as STRONG — below this the verdict is demoted to a deferral (honest, not forced).
    public let strongContradictionMinConfidence: Double

    /// A2 — the broadcast session this resolver belongs to. Evidence tokens stamped with a DIFFERENT session id are
    /// rejected even if the shot id repeats across sessions. Empty when the resolver is session-agnostic (unit tests
    /// that only assert the identity algebra); in that mode session scoping is a no-op and shot/generation rules apply.
    public let sessionID: String

    private var currentContentID: String?
    private var currentRevision = 0
    private var currentTier0ItemID: UInt64?
    private var generation = CaptureGenerationV1.zero
    /// A1 SOURCE CORRELATION: the SHOT the current resolved identity is bound to. Evidence captured from this exact
    /// shot is valid for the current identity (even if it was minted this very frame); evidence from an EARLIER
    /// shot is stale. nil until the first resolve() sets it.
    private var currentBindingShotID: UInt64?
    // Bounded derived counters for the finish-line summary.
    private(set) public var resolvedCount = 0
    private(set) public var newConfirmedCount = 0
    private(set) public var contradictionCount = 0
    private(set) public var overrodeTier0Count = 0        // resolution id differs from what Tier-0 alone would bind

    public init(strongContradictionMinConfidence: Double = 0.60, sessionID: String = "") {
        self.strongContradictionMinConfidence = max(0, strongContradictionMinConfidence)
        self.sessionID = sessionID
    }

    public var liveGeneration: CaptureGenerationV1 { generation }
    /// The shot the current resolved identity is bound to (A1 correlation key). nil before the first resolve().
    public var bindingShotID: UInt64? { currentBindingShotID }

    /// LEGACY generation-only firewall (kept for source + test compatibility). An async result is stale iff the
    /// live generation has advanced past the generation it was started under. NOTE: this CANNOT tell same-frame
    /// evidence for a freshly minted id apart from genuinely late evidence — use `accepts(_:)` for that (A1).
    public func isStale(_ startedUnder: CaptureGenerationV1) -> Bool { startedUnder < generation }

    /// A1 FIX — SOURCE-CORRELATED acceptance. Evidence is valid for the current identity iff it was captured from
    /// the SHOT the current identity is bound to. This accepts same-frame OCR for an id minted THIS frame (the
    /// defect) while still rejecting evidence captured from an EARLIER shot (a different item). Falls back to the
    /// generation ordering only when no binding shot is known yet (pre-first-resolve).
    public func accepts(_ token: CaptureTokenV1) -> Bool {
        // A2 cross-session firewall: when BOTH the resolver and the token are session-scoped, the session ids must
        // match. A token from a previous session (whose shot ids restart at 1) is rejected even if the shot id
        // collides. An unscoped resolver or an unscoped token (empty session) skips this check (pure-algebra tests).
        if !sessionID.isEmpty, !token.sessionID.isEmpty, token.sessionID != sessionID { return false }
        guard let boundShot = currentBindingShotID else { return !isStale(token.generation) }
        return token.shotID == boundShot
    }
    /// Inverse of `accepts` — convenience for the drop path (reads naturally at call sites).
    public func rejects(_ token: CaptureTokenV1) -> Bool { !accepts(token) }

    /// Resolve the identity to bind the Guardian to. Call this BEFORE Guardian evaluation.
    /// - tier0: the Tier-0 provisional proposal (itemID / revision / openedNewItem).
    /// - tier1: the Tier-1 verdict for this committed shot, or nil when Tier-1 was dropped (throttle/in-flight).
    /// - shotID: the committed SHOT this resolution is driven by (A1 source-correlation key). The resolved
    ///   identity becomes BOUND to this shot so same-frame evidence correlates correctly.
    @discardableResult
    public func resolve(tier0: Tier0IdentityProposalV1, tier1: (verdict: Tier1IdentityVerdictV1, confidence: Double)?,
                        shotID: UInt64) -> ResolvedContentIdentityV1 {
        currentBindingShotID = shotID
        return resolveCore(tier0: tier0, tier1: tier1)
    }

    /// Back-compatible overload (no shot correlation — used by pure resolution unit tests that only assert the
    /// identity algebra). Does NOT bind a shot, so `accepts(_:)` falls back to the generation ordering.
    @discardableResult
    public func resolve(tier0: Tier0IdentityProposalV1, tier1: (verdict: Tier1IdentityVerdictV1, confidence: Double)?) -> ResolvedContentIdentityV1 {
        resolveCore(tier0: tier0, tier1: tier1)
    }

    private func resolveCore(tier0: Tier0IdentityProposalV1, tier1: (verdict: Tier1IdentityVerdictV1, confidence: Double)?) -> ResolvedContentIdentityV1 {
        resolvedCount += 1
        let v = tier1?.verdict
        let conf = tier1?.confidence ?? 0

        // What the Tier-0 proposal alone would have bound (the OLD behaviour) — for the override counter.
        let tier0WouldOpenNew = tier0.openedNewItem || currentTier0ItemID != tier0.itemID

        // Decide the relation.
        let relation: ResolvedIdentityRelationV1
        switch v {
        case .newItem:
            // L1: Tier-1 NEW always means a fresh item (whether or not Tier-0 agreed).
            relation = (tier0.openedNewItem) ? .newConfirmed : .newContradiction
        case .sameItem where conf >= strongContradictionMinConfidence && tier0.openedNewItem:
            // L2: Tier-1 SAME with real confidence vs a Tier-0 NEW is a STRONG contradiction. We do NOT merge back
            // into the prior item (that would risk inheriting its safe/protective decision onto possibly-different
            // content); we isolate into a NEW, UNKNOWN identity requiring fresh evaluation.
            relation = .newContradiction
        case .sameItem:
            // Tier-1 SAME agreeing with Tier-0 (or low-confidence against a new) → continuation of the current id,
            // but only if we actually have one and Tier-0 did not open a new item.
            relation = (currentContentID != nil && !tier0.openedNewItem) ? .continuation : .unknownDeferred
        case .unknown, .none:
            // L3: Tier-1 abstained (or was dropped) → keep the Tier-0 proposal.
            relation = tier0WouldOpenNew ? .unknownDeferred : .continuation
        }

        switch relation {
        case .continuation:
            // Keep the current resolved id. (currentContentID is guaranteed non-nil on this path.)
            let id = currentContentID ?? mintID(tier0: tier0)
            currentContentID = id; currentTier0ItemID = tier0.itemID
            return record(id: id, revision: currentRevision, relation: relation, mayReuse: true,
                          reason: reasonFor(relation, v, conf), tier0: tier0, v: v, conf: conf,
                          overrode: false)

        case .newConfirmed, .newContradiction, .unknownDeferred:
            // Any path that is NOT a pure continuation mints a fresh identity when the underlying item actually
            // changed; a pure deferral on an unchanged item keeps the current id.
            if relation == .unknownDeferred && !tier0WouldOpenNew, let id = currentContentID {
                currentTier0ItemID = tier0.itemID
                return record(id: id, revision: currentRevision, relation: .continuation, mayReuse: true,
                              reason: reasonFor(.continuation, v, conf), tier0: tier0, v: v, conf: conf,
                              overrode: false)
            }
            // Mint a NEW resolved identity and ADVANCE the generation (stale-evidence firewall).
            currentRevision += 1
            generation = generation.next()
            let id = mintID(tier0: tier0)
            currentContentID = id; currentTier0ItemID = tier0.itemID
            if relation == .newConfirmed { newConfirmedCount += 1 }
            if relation == .newContradiction { contradictionCount += 1 }
            // A contradiction or a Tier-1-driven new (that Tier-0 alone would NOT have opened) is an override.
            let overrode = (relation == .newContradiction) || (v == .newItem && !tier0.openedNewItem)
            if overrode { overrodeTier0Count += 1 }
            // mayReuse is FALSE for every fresh identity: the Guardian must evaluate from scratch, never inherit.
            return record(id: id, revision: currentRevision, relation: relation, mayReuse: false,
                          reason: reasonFor(relation, v, conf), tier0: tier0, v: v, conf: conf,
                          overrode: overrode)
        }
    }

    // MARK: helpers

    /// Product-facing content id. Includes the resolved revision so two DIFFERENT resolved items can never collide
    /// on the same string even if Tier-0 reused an item id (the measured false-merge case).
    private func mintID(tier0: Tier0IdentityProposalV1) -> String {
        "rc-\(currentRevision)-t0item-\(tier0.itemID)"
    }

    private func reasonFor(_ r: ResolvedIdentityRelationV1, _ v: Tier1IdentityVerdictV1?, _ conf: Double) -> String {
        let t1 = v?.rawValue ?? "NONE"
        switch r {
        case .continuation:      return "continue(tier1=\(t1))"
        case .newConfirmed:      return "new-confirmed(tier0+tier1)"
        case .newContradiction:  return "new-contradiction(tier1=\(t1),conf=\(String(format: "%.2f", conf)))->isolate+reeval"
        case .unknownDeferred:   return "unknown-deferred(tier1=\(t1))->keep-tier0"
        }
    }

    private func record(id: String, revision: Int, relation: ResolvedIdentityRelationV1, mayReuse: Bool,
                        reason: String, tier0: Tier0IdentityProposalV1, v: Tier1IdentityVerdictV1?, conf: Double,
                        overrode: Bool) -> ResolvedContentIdentityV1 {
        ResolvedContentIdentityV1(contentID: id, revision: revision, generation: generation, relation: relation,
                                  mayReusePriorDecision: mayReuse, reason: reason,
                                  tier0ItemID: tier0.itemID, tier0ItemRevision: tier0.itemRevision,
                                  tier1Verdict: v, tier1Confidence: conf,
                                  reasonCode: Self.identityReasonCode(relation: relation, verdict: v))
    }

    /// Identity-level reason code (B3). A continuation carries no "why changed" signal (observing); a fresh id
    /// carries the real cause — content changed/reset, or a new-but-unconfirmed identity. Evidence-level refinement
    /// (text matched/benign, visual insufficient) happens in the Guardian pass, not here.
    static func identityReasonCode(relation: ResolvedIdentityRelationV1, verdict: Tier1IdentityVerdictV1?) -> GuardianReasonCodeV1 {
        switch relation {
        case .continuation:      return .observingNoDecisionYet
        case .newConfirmed:      return .contentChangedReset
        case .newContradiction:  return .newIdentityUnconfirmed
        case .unknownDeferred:   return (verdict == nil || verdict == .unknown) ? .newIdentityUnconfirmed : .contentChangedReset
        }
    }
}
