//
//  GuardianIntelligenceHUD.swift — P009B §25 Developer Intelligence HUD. DEBUG/DEVELOPER ONLY.
//  Proves the Octopus mesh is actually operating: runs REAL corpus scenarios through a live
//  GuardianMetaBrainV2 (all 10 expert arms registered) and displays the real route — expert status,
//  coverage, topics, safety evidence, contradictions, cache, latency, thermal, UNKNOWN, DNA readiness.
//  No raw private text/media dump. No semantic glyph. No numeric suitability score. (§25 rules.)
//
#if DEBUG
import SwiftUI
import GuardianCore

@Observable final class IntelligenceHUDModel {
    let brain: GuardianMetaBrainV2
    var scenarioIndex = 0
    var lastRoute: MetaBrainRouteV2?
    var lastState: ContentUnderstandingStateV1?
    var lastGraph: CrossModalExpertGraphV1?
    var lastScenarioName = "—"
    var provisional = false
    var itemCounter: UInt64 = 1
    let scenarios = P009BCorpusV1.corpus(seed: 0)

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

    func runNext() {
        let s = scenarios[scenarioIndex % scenarios.count]
        scenarioIndex += 1
        let item = ContentItemID(itemCounter); itemCounter += 1
        let now = Double(scenarioIndex) * 100
        let r = P009BCorpusV1.runScenario(s, brain: brain, item: item, provisional: provisional, nowMs: now)
        lastRoute = r.route; lastState = r.state; lastGraph = r.graph; lastScenarioName = s.name
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
}

struct GuardianIntelligenceHUD: View {
    @State private var model = IntelligenceHUDModel()

    var body: some View {
        DisclosureGroup("P009B Intelligence HUD (developer)") {
            VStack(alignment: .leading, spacing: GTokens.s1) {
                HStack {
                    Button("Run scenario") { model.runNext() }.buttonStyle(.bordered)
                    Button("Identity change") { model.simulateIdentityChange() }.buttonStyle(.bordered)
                    Toggle("provisional", isOn: $model.provisional).fixedSize()
                }
                .font(.caption)

                row("Scenario", model.lastScenarioName)
                row("Capability profile", RuntimeCapabilityProfileV2.appFullTier1.rawValue)
                row("Identity", model.lastState?.identityStatus ?? "—")
                row("Generation", "\(model.brain.currentGeneration)")

                Text("Experts").font(.caption.bold()).padding(.top, 2)
                ForEach(ExpertDomainV2.allCases, id: \.self) { d in
                    row(d.rawValue, "\(model.expertStatus(d))  ·  \(model.brain.registry.availability(d).rawValue)")
                }

                Text("Understanding").font(.caption.bold()).padding(.top, 2)
                row("Coverage", coverageLine)
                row("Topics", (model.lastState?.topicCandidates.prefix(4)).map { $0.joined(separator: ", ") } ?? "—")
                row("Safety evidence", (model.lastState?.safetyEvidence.prefix(3)).map { $0.joined(separator: ", ") } ?? "—")
                row("Benefit evidence", (model.lastState?.benefitEvidence.prefix(3)).map { $0.joined(separator: ", ") } ?? "—")
                row("Contradictions", "\(model.lastState?.contradictions ?? 0)")
                row("OOD flags", "\(model.lastState?.oodFlags ?? 0)")
                row("UNKNOWN reasons", (model.lastRoute?.unknownReasons.prefix(3)).map { $0.joined(separator: " · ") } ?? "—")
                row("ContentDNA ready", model.lastState.map { $0.contentDNAReady ? "YES (confirmed)" : "NO" } ?? "—")

                Text("Runtime").font(.caption.bold()).padding(.top, 2)
                row("Route", routeLine)
                row("Cache", "hits=\(model.brain.cache.hits) misses=\(model.brain.cache.misses)")
                row("Latency p50/p95", latencyLine)
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

    private var coverageLine: String {
        guard let s = model.lastState, !s.modalityCoverage.isEmpty else { return "—" }
        return s.modalityCoverage.sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.key.rawValue)=\(String(format: "%.1f", $0.value))" }.joined(separator: " ")
    }
    private var routeLine: String {
        guard let r = model.lastRoute else { return "—" }
        return "exec=\(r.executed.count) hit=\(r.cacheHits.count) defer=\(r.deferredThermal.count) unavail=\(r.unavailable.count)"
    }
    private var latencyLine: String {
        let snap = model.brain.registry.health.snapshot()
        let pairs = ExpertDomainV2.allCases.compactMap { d -> String? in
            guard let h = snap[d], !h.latenciesMs.isEmpty else { return nil }
            return "\(d.rawValue.prefix(4)):\(String(format: "%.0f/%.0f", h.p50, h.p95))"
        }
        return pairs.isEmpty ? "no samples yet" : pairs.joined(separator: " ")
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
