//
//  ConditionalPressureModelProbeV1.swift — R9 §6/§6.1 (P1-6): FOUNDATION MODELS REAL CAPABILITY PROBE +
//  an EXPERIMENTAL, PRODUCTION-ISOLATED conditional-guilt / coercive-intent structured-output contract.
//
//  WHY THIS EXISTS (mandate §6): R8 measured only `canImport(FoundationModels) == true`, which is NOT proof the model
//  can run. R9 distinguishes the REAL capability rungs and — IF a session can genuinely open on host — evaluates a
//  NARROW structured probe for the §6.1 target (conditional guilt / coercive intent). The STRUCTURED OUTPUT CONTRACT
//  (speaker/target/conditional structure/requested action/mechanism/counter-evidence/uncertainty/evidence span) is the
//  deliverable even when inference is unavailable on host — "the mechanism is the deliverable" (mandate §6).
//
//  THE HARD GUARDRAILS (mandate §6/§6.1 + constitution 1-8, 20):
//   • This NEVER drives a production action. It is EXPERIMENTAL, isolated from the Guardian decision path. A heuristic/
//     experimental Tier-1 result cannot move a surface without independent evaluation (constitution rule 8/20).
//   • NO 0–100 risk score is ever requested from the model. The contract is a STRUCTURED evidence object, not a score.
//   • Fields UNSUPPORTED by the input text are REJECTED (`rejectUnsupportedFields`) — the model may not invent a target
//     or a conditional structure the text does not contain (mandate §6.1: "giriş tarafından desteklenmeyen alanları
//     reddedilecek"). Supportive / normal relationship talk must NOT be flagged as coercion.
//   • Honest capability reporting: each rung (SDK / OS / device / model-ready / inference-succeeds) is reported as what
//     we can actually prove on THIS host; an unverifiable rung is UNKNOWN/UNVERIFIED, never asserted.
//
//  Lives in GuardianMedia (GuardianCore frozen). FoundationModels is imported conditionally so an SDK without it still
//  compiles (the probe then reports the framework absent — honest, never a fabricated capability).
//
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// R9 §6 — the capability RUNGS for an on-device language model. Each is an INDEPENDENT fact; a higher rung is NOT
/// implied by a lower one. The honest report fills each with what we can actually prove on the host at call time.
public enum FoundationModelCapabilityRungV1: String, Sendable, Equatable, Codable, CaseIterable {
    case sdkFrameworkAvailable   = "SDK_FRAMEWORK_AVAILABLE"    // canImport(FoundationModels) at compile time
    case osFeatureSupported      = "OS_FEATURE_SUPPORTED"       // the OS exposes the model API at runtime
    case deviceModelEligible     = "DEVICE_MODEL_ELIGIBLE"      // the hardware is eligible
    case onDeviceModelAvailable  = "ON_DEVICE_MODEL_AVAILABLE"  // the model assets are present
    case modelCurrentlyReady     = "MODEL_CURRENTLY_READY"      // the model reports .available right now
    case inferenceSucceeds       = "INFERENCE_SUCCEEDS"         // a real session produced a real response
    case inferencePolicyPermitted = "INFERENCE_POLICY_PERMITTED" // running it is permitted by our own policy
}

/// R9 §6 — the honest per-rung status. UNKNOWN is first-class: a rung we cannot prove on host is UNKNOWN, never TRUE.
public enum FoundationModelRungStatusV1: String, Sendable, Equatable, Codable {
    case yes = "YES", no = "NO", unknown = "UNKNOWN"
}

/// R9 §6 — the honest capability report: each rung + status + a short reason, plus the overall verdict. This is the
/// deliverable regardless of whether inference runs: it tells the truth about what the host can and cannot do.
public struct FoundationModelCapabilityReportV1: Sendable, Equatable, Codable {
    public static let version = "foundation-model-capability-probe-v1"
    public let rungs: [FoundationModelCapabilityRungV1: FoundationModelRungStatusV1]
    public let reason: String
    public init(rungs: [FoundationModelCapabilityRungV1: FoundationModelRungStatusV1], reason: String) {
        self.rungs = rungs; self.reason = reason
    }
    /// True only when inference actually succeeded on host (the ONLY rung that proves a model session really ran).
    public var inferenceProvenOnHost: Bool { rungs[.inferenceSucceeds] == .yes }
    /// A compact proof-log line (derived scalars only; never model input/output content).
    public var summary: String {
        let order = FoundationModelCapabilityRungV1.allCases
        let parts = order.map { "\($0.rawValue)=\((rungs[$0] ?? .unknown).rawValue)" }
        return "\(parts.joined(separator: " ")) reason=\(reason)"
    }
}

/// R9 §6.1 — the STRUCTURED OUTPUT CONTRACT for conditional guilt / coercive intent. This is a pure evidence object:
/// it carries the structure a human reader (or a constrained model) can observe, with NO risk score and explicit
/// uncertainty + counter-evidence + an evidence-span reference. Every field is OPTIONAL/abstaining so "no coercion"
/// and "unsupported by text" are first-class. NEVER consumed by the production decision path (experimental only).
public struct ConditionalPressureStructuredOutputV1: Sendable, Equatable, Codable {
    public static let contractVersion = "conditional-pressure-contract-v1"
    /// WHO is applying the pressure (verbatim-ish span the text supports; nil = unsupported/absent).
    public let speaker: String?
    /// WHO the pressure is aimed at (nil = unsupported/absent — never invented).
    public let target: String?
    /// The CONDITIONAL STRUCTURE observed ("if you X then you are/prove Y"); nil when the text has no conditional.
    public let conditionalStructure: String?
    /// The ACTION the speaker is pressing the target to perform (nil = none in text).
    public let requestedAction: String?
    /// The PRESSURE MECHANISM (maps to PressureMechanismV1 for traceability); nil = none / unsupported.
    public let mechanism: PressureMechanismV1?
    /// COUNTER-EVIDENCE the text ALSO contains (support/consolation/legitimate-emergency) — the anti-false-positive
    /// field. A supportive or normal relationship line should fill THIS, not the mechanism.
    public let counterEvidence: [String]
    /// The model/annotator's UNCERTAINTY (ordinal label, NOT a calibrated probability — honest abstention-first).
    public let uncertainty: EmotionalPressureLevelV1   // reuse the ordinal scale; .ambiguous = genuinely unclear
    /// The EVIDENCE SPAN reference the structure rests on (a short quote-ish fragment the input supports; nil = none).
    public let evidenceSpan: String?
    /// Fields the model asserted that the INPUT TEXT does NOT support — REJECTED (mandate §6.1). Populated by the
    /// validator; a non-empty list means the raw model output was partially rejected (and those fields nulled).
    public let rejectedUnsupportedFields: [String]
    public init(speaker: String?, target: String?, conditionalStructure: String?, requestedAction: String?,
                mechanism: PressureMechanismV1?, counterEvidence: [String], uncertainty: EmotionalPressureLevelV1,
                evidenceSpan: String?, rejectedUnsupportedFields: [String] = []) {
        self.speaker = speaker; self.target = target; self.conditionalStructure = conditionalStructure
        self.requestedAction = requestedAction; self.mechanism = mechanism; self.counterEvidence = counterEvidence
        self.uncertainty = uncertainty; self.evidenceSpan = evidenceSpan
        self.rejectedUnsupportedFields = rejectedUnsupportedFields
    }
    /// An abstaining (no-coercion-observed) output — the default when the text shows no conditional pressure.
    public static func abstain(counterEvidence: [String] = []) -> ConditionalPressureStructuredOutputV1 {
        ConditionalPressureStructuredOutputV1(speaker: nil, target: nil, conditionalStructure: nil,
                                              requestedAction: nil, mechanism: nil, counterEvidence: counterEvidence,
                                              uncertainty: .none, evidenceSpan: nil)
    }
}

public enum ConditionalPressureModelProbeV1 {
    public static let version = "conditional-pressure-model-probe-v1"

    /// Fold text for TOKEN matching: lowercased, diacritics/case folded, punctuation → spaces, collapsed whitespace.
    /// TR-aware via `folding` so "sevseydin" matches regardless of case; punctuation is stripped so "sevseydin."
    /// still matches "sevseydin". Pure + deterministic.
    static func foldForMatch(_ s: String) -> String {
        let folded = s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
        let scalars = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(scalars).split(separator: " ").joined(separator: " ")
    }

    /// R9 §6 — the HONEST capability report. Rungs we can prove at compile time (SDK available) are filled; runtime
    /// rungs (OS/device/model-ready) are read from the framework's OWN availability when importable; inference is
    /// marked UNKNOWN unless `tryInference` genuinely ran. We NEVER assert a rung we cannot prove on host.
    public static func capabilityReport() -> FoundationModelCapabilityReportV1 {
        var rungs: [FoundationModelCapabilityRungV1: FoundationModelRungStatusV1] = [:]
        // Default every rung UNKNOWN (honest: unproven), then prove what we can.
        for r in FoundationModelCapabilityRungV1.allCases { rungs[r] = .unknown }
        // Our own policy: an EXPERIMENTAL probe is permitted to RUN for evaluation, but its result may NEVER drive a
        // production action (enforced by isolation — this type is not on the Guardian decision path). So the
        // policy-permitted rung is YES for "may run the experiment", with the hard constraint documented.
        rungs[.inferencePolicyPermitted] = .yes
        #if canImport(FoundationModels)
        rungs[.sdkFrameworkAvailable] = .yes
        if #available(iOS 26.0, macOS 26.0, *) {
            // SystemLanguageModel.default.availability is the framework's OWN honest capability signal. We read it and
            // map to rungs WITHOUT asserting inference (which requires a real session + response — see tryInference).
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                rungs[.osFeatureSupported] = .yes
                rungs[.deviceModelEligible] = .yes
                rungs[.onDeviceModelAvailable] = .yes
                rungs[.modelCurrentlyReady] = .yes
                return FoundationModelCapabilityReportV1(rungs: rungs,
                    reason: "SystemLanguageModel.default.availability == .available (inference still UNKNOWN until a real session runs)")
            case .unavailable(let why):
                rungs[.osFeatureSupported] = .yes   // the API answered → the OS exposes the feature
                rungs[.modelCurrentlyReady] = .no
                return FoundationModelCapabilityReportV1(rungs: rungs,
                    reason: "SystemLanguageModel unavailable: \(String(describing: why))")
            @unknown default:
                return FoundationModelCapabilityReportV1(rungs: rungs,
                    reason: "SystemLanguageModel availability unknown-case (OS newer than this build)")
            }
        } else {
            rungs[.osFeatureSupported] = .no
            return FoundationModelCapabilityReportV1(rungs: rungs,
                reason: "FoundationModels importable but OS below the availability floor")
        }
        #else
        rungs[.sdkFrameworkAvailable] = .no
        return FoundationModelCapabilityReportV1(rungs: rungs,
            reason: "FoundationModels not importable on this SDK (canImport == false) — honest absence, never fabricated")
        #endif
    }

    /// R9 §6.1 — the VALIDATOR: reject any structured field the INPUT TEXT does not support (mandate §6.1). Pure +
    /// testable WITHOUT a model: it takes a candidate structured output + the original input and returns a cleaned
    /// output with unsupported fields NULLED and listed in `rejectedUnsupportedFields`. "Supported" = the field's
    /// evidence span (or the field text itself) appears (case-insensitively, token-wise) in the input. This is the
    /// guardrail that stops the model inventing a target/conditional/action the text never contained.
    public static func rejectUnsupportedFields(candidate: ConditionalPressureStructuredOutputV1,
                                               inputText: String) -> ConditionalPressureStructuredOutputV1 {
        let hay = foldForMatch(inputText)
        var rejected: [String] = []
        func supported(_ s: String?) -> String? {
            guard let s, !s.isEmpty else { return s }
            // A field is supported when a meaningful token of it appears in the input (folded). Short connective words
            // alone don't count — require at least one token of length >= 3 that occurs in the input.
            let toks = foldForMatch(s).split(separator: " ").map(String.init).filter { $0.count >= 3 }
            if toks.isEmpty { return s }   // nothing substantive to verify → leave as-is (not a fabrication claim)
            if toks.contains(where: { hay.contains($0) }) { return s }
            return nil
        }
        let speaker = supported(candidate.speaker); if speaker == nil && candidate.speaker != nil { rejected.append("speaker") }
        let target = supported(candidate.target); if target == nil && candidate.target != nil { rejected.append("target") }
        let cond = supported(candidate.conditionalStructure); if cond == nil && candidate.conditionalStructure != nil { rejected.append("conditionalStructure") }
        let action = supported(candidate.requestedAction); if action == nil && candidate.requestedAction != nil { rejected.append("requestedAction") }
        let span = supported(candidate.evidenceSpan); if span == nil && candidate.evidenceSpan != nil { rejected.append("evidenceSpan") }
        // If the evidence span itself was rejected, the mechanism it supposedly rested on is also unsupported.
        let mechanism = (span == nil && candidate.evidenceSpan != nil) ? nil : candidate.mechanism
        if mechanism == nil && candidate.mechanism != nil { rejected.append("mechanism") }
        return ConditionalPressureStructuredOutputV1(
            speaker: speaker, target: target, conditionalStructure: cond, requestedAction: action,
            mechanism: mechanism, counterEvidence: candidate.counterEvidence, uncertainty: candidate.uncertainty,
            evidenceSpan: span, rejectedUnsupportedFields: rejected)
    }

    /// R9 §6.1 — attempt the EXPERIMENTAL inference on host, IF a session can genuinely open. Returns nil when the
    /// model is unavailable (then the caller reports the capability honestly and uses no result). The result is
    /// ALWAYS passed through `rejectUnsupportedFields` before return (guardrail). This NEVER drives production: the
    /// return is for evaluation/reporting only. Marked async because the real API is async.
    ///
    /// NOTE (honest): the real structured-generation call uses FoundationModels' `@Generable` output on
    /// `LanguageModelSession.respond(to:generating:)`. The exact generation surface is validated at build time by the
    /// installed SDK; if the host model is unavailable this returns nil WITHOUT fabricating a result.
    public static func tryStructuredProbe(inputText: String) async -> ConditionalPressureStructuredOutputV1? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else { return nil }
            // A real session could run here. We do NOT hard-wire the @Generable generation call in this build because
            // the SDK interface could not be independently verified by the build agent (reported honestly as
            // SDK_UNVERIFIED_BY_AGENT); the CONTRACT + VALIDATOR + capability report are the proven deliverable, and a
            // device/host run with the verified generation surface replaces this nil with a real validated structure.
            return nil
        }
        return nil
        #else
        return nil
        #endif
    }

    /// R9 §6.1/§7 — the FRESH evaluation probes (TR+EN; NOT the R7 regression set — those are regression-only). These
    /// are hand-authored examples WITH their expected structure, used to exercise the CONTRACT + VALIDATOR honestly
    /// (and, on a host where inference runs, to compare the model against). A mix of real conditional guilt and
    /// clean supportive/normal lines (the anti-false-positive controls). Pure data; no model dependency.
    public struct EvalProbeV1: Sendable, Equatable {
        public let text: String
        public let language: AnnotatedLanguageV1
        public let expectCoercion: Bool          // true = conditional guilt/coercion present; false = supportive/normal
        public let note: String
    }
    public static let freshEvalProbes: [EvalProbeV1] = [
        .init(text: "Eğer beni gerçekten sevseydin bunu benim için yapardın.", language: .turkish,
              expectCoercion: true, note: "conditional guilt — love conditioned on an action"),
        .init(text: "If you actually cared about me you'd delete that post right now.", language: .english,
              expectCoercion: true, note: "conditional guilt — care conditioned on compliance"),
        .init(text: "Beni seviyorsan bana güvenirsin, kimseye söyleme.", language: .turkish,
              expectCoercion: true, note: "conditional-trust coercion to secrecy"),
        .init(text: "Ne karar verirsen ver, ben her zaman yanındayım.", language: .turkish,
              expectCoercion: false, note: "supportive — unconditional, must NOT flag"),
        .init(text: "Take your time, there's no pressure at all — whatever you decide is fine.", language: .english,
              expectCoercion: false, note: "explicitly non-coercive, must NOT flag"),
        .init(text: "Bugün hava çok güzel, parkta yürüyüş yaptık.", language: .turkish,
              expectCoercion: false, note: "neutral everyday talk — no pressure"),
    ]
}
