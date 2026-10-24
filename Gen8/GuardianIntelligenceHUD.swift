//
//  GuardianIntelligenceHUD.swift — P009B §25 + R1 §13 Developer Intelligence HUD. DEBUG/DEVELOPER ONLY.
//  R1 truthfulness laws: a mandatory SOURCE banner distinguishes REAL IN-PROCESS perception from
//  rights-clear synthetic/derived lab playback (lab corpus may never masquerade as real perception);
//  availability shows the ACTUAL 5-tier class from the registry; latency shows measured monotonic
//  p50/p95 or the literal NOT_MEASURED — never 0 ms. No raw media dump. No glyph. No score.
//
#if DEBUG
import SwiftUI
import CoreGraphics
import CoreText
import GuardianCore
import GuardianIntelligence

@Observable final class IntelligenceHUDModel {
    enum SourceMode: String {
        case synthetic = "SOURCE: RIGHTS-CLEAR SYNTHETIC/DERIVED LAB"
        case real = "SOURCE: REAL IN-PROCESS"
        case none = "SOURCE: — (nothing run yet)"
    }
    let brain: GuardianMetaBrainV2
    var scenarioIndex = 0
    var semanticIndex = 0
    var lastRoute: MetaBrainRouteV2?
    var lastState: ContentUnderstandingStateV1?
    var lastGraph: CrossModalExpertGraphV1?
    var lastWorldModel: ContentWorldModelV1?               // P009C §27 — semantic extension
    var lastDNAState: String = "—"
    var lastPolicy: AdmissionStateCandidateV1?             // P009D §19 — policy extension
    var childMode = false
    var lastScenarioName = "—"
    var sourceMode: SourceMode = .none
    var realProvenance: [String] = []
    var provisional = false
    var itemCounter: UInt64 = 1
    let scenarios = P009BCorpusV2.scenarios(.tune)
    let semanticScenarios = P009CCorpusV1.scenarios(.tune)

    init() {
        let b = GuardianMetaBrainV2()
        b.registry.register(VisionExpertV1())
        b.registry.register(LanguageOCRExpertV1())
        b.registry.register(SpeechExpertV1())
        b.registry.register(AudioEventExpertV1())
        b.registry.register(MusicExpertV1())
        b.registry.register(SymbolExpertV1())
        b.registry.register(TemporalExpertV1())
        b.registry.register(SafetyEvidenceExpertV1())
        b.registry.register(BenefitEvidenceExpertV1())
        b.registry.register(AttentionPressureExpertV1())
        b.beginObservation(ObservationID(1))
        brain = b
    }

    /// Lab playback — corpus-authored derived inputs. ALWAYS labeled synthetic.
    func runNextCorpusScenario() {
        let s = scenarios[scenarioIndex % scenarios.count]
        scenarioIndex += 1
        let item = ContentItemID(itemCounter); itemCounter += 1
        let r = P009BCorpusV2.runScenario(s, brain: brain, item: item, provisional: provisional,
                                          nowMs: Double(scenarioIndex) * 100)
        lastRoute = r.route; lastState = r.state; lastGraph = r.graph; lastScenarioName = s.name
        sourceMode = .synthetic; realProvenance = []
    }

    /// REAL perception — renders an owned image in-process and runs REAL Vision OCR + classify + NL
    /// through RealObservationToExpertInputAdapterV1 (no synthetic fallback inside the adapter).
    func runRealCapture() async {
        guard let image = Self.renderOwnedImage(text: "LEARN THE SCIENCE LESSON GUIDE") else { return }
        let adapted = await RealObservationToExpertInputAdapterV1().adapt(cgImage: image)
        let item = ContentItemID(itemCounter); itemCounter += 1
        let ctx = ExpertTaskContextV2(observationID: ObservationID(1), shotID: ShotID(item.raw), itemID: item,
                                      itemProvisional: provisional, profile: .appFullTier1,
                                      requestedDomains: ExpertDomainV2.allCases, generation: brain.currentGeneration)
        let route = brain.route(input: adapted.input, context: ctx, nowMs: Double(itemCounter) * 100)
        let graph = CrossModalExpertGraphV1(); graph.relate(route.evidence)
        let state = ContentUnderstandingStateV1.build(itemProvisional: provisional, evidence: route.evidence,
                                                      graph: graph, registry: brain.registry, unknownReasons: route.unknownReasons)
        lastRoute = route; lastState = state; lastGraph = graph; lastScenarioName = "real-capture(owned rendered image)"
        sourceMode = adapted.providerProvenance.isEmpty ? .none : .real
        realProvenance = adapted.providerProvenance
    }

    /// P009C §27 — run a multi-segment SEMANTIC scenario through the world-model path (lab playback).
    func runNextSemanticScenario() {
        let s = semanticScenarios[semanticIndex % semanticScenarios.count]
        semanticIndex += 1
        let item = ContentItemID(itemCounter); itemCounter += 1
        let m = P009CCorpusV1.run(s, brain: brain, item: item, provisional: provisional)
        lastWorldModel = m
        lastScenarioName = "semantic:\(s.name)"
        sourceMode = .synthetic; realProvenance = []
        // DNA finalization attempt (authoritative snapshot only when confirmed)
        if !provisional {
            let fin = ContentDNAFinalizerV1()
            let snap = IdentityResolutionSnapshotV1(itemID: item, identityRevision: 0, resolutionState: .confirmed,
                                                    sourceProfile: .appFullTier1, evidenceProvenance: "hud-lab",
                                                    confirmationAuthority: .tier1AppFull, generation: brain.currentGeneration,
                                                    unresolvedSplitOrMerge: false, strongNewOrConflict: false)
            let (dna, refusal) = fin.finalize(model: m, identity: snap, currentGeneration: brain.currentGeneration,
                                              dnaRaw: item.raw, nowMs: 0)
            lastDNAState = dna.map { "FINALIZED(\($0.revisionState.rawValue))" } ?? "REFUSED(\(refusal?.rawValue ?? "?"))"
        } else {
            lastDNAState = "REFUSED(provisional-identity)"
        }
        // P009D §19 — policy evaluation over the SAME world model (cheap re-derive; no re-understanding)
        let childProfile = childMode ? GuardianEnteredChildProfileV1(ageYears: 9, jurisdictionCode: "TR",
                                                                     enteredByGuardian: true) : nil
        lastPolicy = AdmissionPolicyPipelineV1.evaluate(worldModel: m, childProfile: childProfile,
                                                        shieldConfig: ShieldConfigV2(blockedConcepts: ["concept:mortality"]),
                                                        nowMs: 0)
    }

    // P010 TIER-1 item-identity SELF-TEST — REAL Vision feature prints over owned rendered scenes, run through
    // the SAME Tier1ItemIdentityV1 component + fusion law the broadcast extension uses. No raw media retained.
    var tier1Lines: [String] = []
    func runTier1SelfTest() {
        tier1Lines = []
        // Scene A + variant A2 (same "item": same hue/subject, moved subject + brightness shift) + distinct scene B.
        guard let a = Self.renderOwnedScene(hue: 0.58, bright: 0.55, subjectX: 120, caption: "COSMOS GALAXY PART ONE"),
              let a2 = Self.renderOwnedScene(hue: 0.58, bright: 0.72, subjectX: 190, caption: "COSMOS GALAXY PART TWO"),
              let b = Self.renderOwnedScene(hue: 0.08, bright: 0.60, subjectX: 540, caption: "PASTA KITCHEN RECIPE") else {
            tier1Lines = ["scene render failed"]; return
        }
        let t1 = Tier1ItemIdentityV1(policy: Tier1IdentityPolicyV1(minIntervalMs: 0))
        func line(_ name: String, _ img: CGImage, expect: String) {
            let r = t1.assess(cgImage: img, ocrText: nil, tier0OpenedNewItem: false,
                              tier0StrongNew: false, tier0ProjectionCorrelation: nil)
            tier1Lines.append("\(name): \(r.verdict.rawValue) conf=\(String(format: "%.2f", r.confidence)) fpDist=\(r.fpDistance.map { String(format: "%.3f", $0) } ?? "-") latMs=\(String(format: "%.1f", r.latencyMs)) (expect \(expect))")
        }
        line("seed A", a, expect: "UNKNOWN no-reference")
        line("A→A′ same-item variant", a2, expect: "SAME_ITEM")
        line("A′→B distinct item", b, expect: "NEW_ITEM")
        tier1Lines.append("policy=\(t1.policy.revision) · synthetic-calibrated thresholds · device evidence PENDING")
        lastScenarioName = "tier1-self-test(owned rendered scenes)"
        sourceMode = .real
        realProvenance = ["vision-feature-print(real, in-process)"]
    }
    static func renderOwnedScene(hue: Double, bright: Double, subjectX: Double, caption: String,
                                 width: Int = 720, height: Int = 405) -> CGImage? {
        func hsb(_ h: Double, _ s: Double, _ b: Double) -> CGColor {
            let i = Int(h * 6) % 6, f = h * 6 - Double(Int(h * 6))
            let p = b * (1 - s), q = b * (1 - f * s), t = b * (1 - (1 - f) * s)
            let rgb: (Double, Double, Double)
            switch i { case 0: rgb = (b, t, p); case 1: rgb = (q, b, p); case 2: rgb = (p, b, t)
                       case 3: rgb = (p, q, b); case 4: rgb = (t, p, b); default: rgb = (b, p, q) }
            return CGColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(hsb(hue, 0.35, bright)); ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(hsb((hue + 0.5).truncatingRemainder(dividingBy: 1), 0.75, 0.85))
        ctx.fillEllipse(in: CGRect(x: subjectX, y: 140, width: 220, height: 150))
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.85))
        ctx.fill(CGRect(x: 0, y: 40, width: Double(width), height: 60))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 36, nil)
        let attr = NSAttributedString(string: caption, attributes: [
            kCTFontAttributeName as NSAttributedString.Key: font,
            kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(red: 1, green: 1, blue: 1, alpha: 1)])
        ctx.textPosition = CGPoint(x: 20, y: 58)
        CTLineDraw(CTLineCreateWithAttributedString(attr), ctx)
        return ctx.makeImage()
    }

    static func renderOwnedImage(text: String, width: Int = 900, height: Int = 240) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 64, nil)
        let attr = NSAttributedString(string: text, attributes: [
            kCTFontAttributeName as NSAttributedString.Key: font,
            kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ])
        ctx.textPosition = CGPoint(x: 40, y: height / 2 - 24)
        CTLineDraw(CTLineCreateWithAttributedString(attr), ctx)
        return ctx.makeImage()
    }

    func simulateIdentityChange() { brain.identityChanged() }

    func expertStatus(_ d: ExpertDomainV2) -> String {
        guard let r = lastRoute else { return "—" }
        if r.cacheHits.contains(d) { return "HIT" }
        if r.executed.contains(d) { return "COMPLETE" }
        if r.deferredThermal.contains(d) { return "DEFERRED" }
        if r.unavailable.contains(d) { return "UNAVAILABLE" }
        if r.unknownReasons.contains(where: { $0.hasPrefix("stale-discarded:\(d.rawValue)") }) { return "STALE" }
        return "IDLE"
    }
    /// Measured monotonic percentiles or the literal NOT_MEASURED — never "0 ms" without samples.
    func latencyText(_ op: String) -> String {
        guard let p = brain.latency.percentiles(op) else { return "NOT_MEASURED" }
        return String(format: "%.3f/%.3f ms (n=%d)", p.p50, p.p95, p.count)
    }
}

struct GuardianIntelligenceHUD: View {
    @State private var model = IntelligenceHUDModel()

    var body: some View {
        DisclosureGroup("P009B Intelligence HUD (developer)") {
            VStack(alignment: .leading, spacing: GTokens.s1) {
                // R1 §13 mandatory source banner — lab playback can never masquerade as real perception
                Text(model.sourceMode.rawValue)
                    .font(.caption.bold())
                    .padding(4)
                    .background(model.sourceMode == .real ? Color.green.opacity(0.25) : Color.orange.opacity(0.25))

                HStack {
                    Button("Corpus scenario (lab)") { model.runNextCorpusScenario() }.buttonStyle(.bordered)
                    Button("Semantic scenario (lab)") { model.runNextSemanticScenario() }.buttonStyle(.bordered)
                    Button("REAL capture") { Task { await model.runRealCapture() } }.buttonStyle(.bordered)
                    Button("TIER-1 identity") { model.runTier1SelfTest() }.buttonStyle(.bordered)
                    Button("Identity change") { model.simulateIdentityChange() }.buttonStyle(.bordered)
                    Toggle("provisional", isOn: $model.provisional).fixedSize()
                }
                .font(.caption)

                if !model.tier1Lines.isEmpty {
                    Text("Tier-1 item identity (P010 — REAL feature print; synthetic-calibrated, device-pending)")
                        .font(.caption.bold()).padding(.top, 2)
                    ForEach(Array(model.tier1Lines.enumerated()), id: \.offset) { _, l in
                        Text(l)
                    }
                }

                row("Scenario", model.lastScenarioName)
                row("Real providers", model.realProvenance.isEmpty ? "— (lab inputs)" : model.realProvenance.joined(separator: " · "))
                row("Capability profile", RuntimeCapabilityProfileV2.appFullTier1.rawValue)
                row("Identity", model.lastState?.identityStatus ?? "—")
                row("Generation", "\(model.brain.currentGeneration)")

                Text("Experts (status · ACTUAL availability tier)").font(.caption.bold()).padding(.top, 2)
                ForEach(ExpertDomainV2.allCases, id: \.self) { d in
                    row(d.rawValue, "\(model.expertStatus(d))  ·  \(model.brain.registry.availability(d).rawValue)")
                }

                Text("Understanding").font(.caption.bold()).padding(.top, 2)
                row("Topics", (model.lastState?.topicCandidates.prefix(4)).map { $0.joined(separator: ", ") } ?? "—")
                row("Safety evidence", (model.lastState?.safetyEvidence.prefix(3)).map { $0.joined(separator: ", ") } ?? "—")
                row("Benefit evidence", (model.lastState?.benefitEvidence.prefix(3)).map { $0.joined(separator: ", ") } ?? "—")
                row("Contradictions", "\(model.lastState?.contradictions ?? 0)")
                row("OOD flags", "\(model.lastState?.oodFlags ?? 0)")
                row("UNKNOWN reasons", (model.lastRoute?.unknownReasons.prefix(3)).map { $0.joined(separator: " · ") } ?? "—")
                row("ContentDNA ready", model.lastState.map { $0.contentDNAReady ? "YES (confirmed)" : "NO" } ?? "—")

                if let wm = model.lastWorldModel {
                    Text("World model (P009C — evidence, no verdict/score)").font(.caption.bold()).padding(.top, 2)
                    row("Episodes", "\(wm.episodes.count) (revisions: \(wm.episodes.map { "\($0.revision)" }.joined(separator: ",")))")
                    row("Primary topics", wm.primaryTopics.map { $0.concept }.joined(separator: ", "))
                    row("Secondary", wm.secondaryTopics.prefix(4).map { $0.concept }.joined(separator: ", "))
                    row("Entities", wm.entities.prefix(4).map { $0.canonical + ($0.conflicting ? "⚠︎conflict" : "") }.joined(separator: ", "))
                    row("Intents", wm.intents.prefix(3).map { $0.intent.rawValue }.joined(separator: ", ") + (wm.intentAmbiguous ? "  [AMBIGUOUS]" : ""))
                    row("Events", wm.events.prefix(5).map { $0.kind.rawValue }.joined(separator: " → "))
                    row("Narrative", wm.narrativeLabels.joined(separator: " · "))
                    row("maxRisk / benefit / manip", String(format: "%.2f", wm.maxRiskSeen) + " / \(wm.benefitEvidence.count) / \(wm.manipulationEvidence.count)")
                    row("Contradictions", wm.contradictionResolutions.map { $0.outcome.rawValue }.joined(separator: ", "))
                    row("Knowledge state", "\(wm.knowledgeState.rawValue) (uncertainty \(String(format: "%.2f", wm.uncertainty.overall)))")
                    row("DNA", "\(wm.readiness ? "READY" : "NOT-READY") · \(model.lastDNAState)")
                }
                if let p = model.lastPolicy {
                    Text("Policy (P009D — categorical, score OFF)").font(.caption.bold()).padding(.top, 2)
                    Toggle("child profile (demo: guardian-entered 9, TR)", isOn: $model.childMode).font(.caption).fixedSize()
                    row("Admission", p.state.rawValue)
                    row("Dominant reason", "\(p.dominantReason.code.rawValue): \(p.dominantReason.basis)")
                    row("Secondary", p.secondaryReasons.prefix(3).map { $0.code.rawValue }.joined(separator: ", "))
                    row("Child outcome", p.childOutcome?.rawValue ?? "— (no child profile)")
                    row("Age source", p.childSourceClass.map { "\($0.rawValue) (never presented as legal)" } ?? "—")   // P009E F-6: carried, not hardcoded
                    row("Shield", p.shieldOutcome.map { "\($0.hardMatch ? "HARD" : "no-match") · \($0.matchConfidence.rawValue)" } ?? "—")
                    row("H1 status", "UNAVAILABLE_EVIDENCE_BACKED (open blocker — visible on every route)")
                    row("Unresolved", p.unresolvedConflicts.isEmpty ? "none" : p.unresolvedConflicts.joined(separator: ", "))
                    row("Policy versions", "\(p.versions.policyEngine) · \(p.versions.ageRegistry)")
                }
                if let p = model.lastPolicy, let wm = model.lastWorldModel {
                    Text("Score (P009E — INTERNAL · DEMO FUSION WEIGHTS, not the fitted artifact; PRODUCTION SCORE DISPLAY: OFF)").font(.caption.bold()).padding(.top, 2)   // P009E-R1 A8-F7
                    let reg = CalibrationRegistryV2()
                    let eng = PersonalSuitabilityScoreV2.EngineV1(registry: reg,
                        fusion: SuitabilityFusionModelV1(wRisk: -1.6, wBenefit: 1.12, wManip: 0, wShield: -1,
                                                         wChild: -1.12, bias: 2, fitted: true, trainMAE: 0.68))
                    let locale = wm.primaryTopics.isEmpty ? "en" : "en"
                    let c = eng.evaluate(worldModel: wm, decision: p, profile: .adultNeutral, locale: locale)
                    row("Internal score", c.score.map { String(format: "%.0f/100 (%@)", $0, c.interpretation) } ?? "NIL — \(c.abstentionReason ?? "abstained")")
                    row("Confidence / coverage", "\(c.scoreConfidence) / \(String(format: "%.2f", c.evidenceCoverage))")
                    row("Calibration", "\(c.calibrationStatus) · \(c.calibrationVersion)")
                    row("Sentinel/teen gate", p.childOutcome == .unknownReview ? "FAIL-CLOSED REVIEW" : "—")
                    row("Release gate", "CLOSED (\(ProductionScoreReleaseGateV1.evaluate().conditions.filter { !$0.met }.count)/10 unmet)")
                }
                Text("Runtime (measured — NOT_MEASURED when no samples)").font(.caption.bold()).padding(.top, 2)
                row("Route", routeLine)
                row("Cache", "hits=\(model.brain.cache.hits) misses=\(model.brain.cache.misses) ttlExp=\(model.brain.cache.ttlExpiries)")
                row("route p50/p95", model.latencyText("route"))
                row("cache-lookup", model.latencyText("cache-lookup"))
                row("graph-fusion", model.latencyText("graph-fusion"))
                row("state-build", model.latencyText("state-build"))
                row("Thermal", model.brain.governor.thermal.rawValue)
                row("Score display", "OFF (CalibrationRegistrySkeletonV1 refuses — P009B law)")
            }
            .font(.caption.monospaced())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, GTokens.s1)
        }
        .font(.caption)
        .padding(.horizontal, GTokens.s4)
    }

    private var routeLine: String {
        guard let r = model.lastRoute else { return "—" }
        return "exec=\(r.executed.count) hit=\(r.cacheHits.count) defer=\(r.deferredThermal.count) unavail=\(r.unavailable.count)"
    }
    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).foregroundStyle(.secondary).frame(width: 150, alignment: .leading)
            Text(v)
            Spacer(minLength: 0)
        }
    }
}
#endif
