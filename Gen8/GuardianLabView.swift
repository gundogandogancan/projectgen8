//
//  GuardianLabView.swift — internal controlled harness (PROMPT 001 §D, §10, §13)
//  Short-form feed + long-form player. Proves the pre-exposure + temporal-skip-safety contracts
//  on-device with deterministic fixtures. Diagnostics are behind an internal disclosure.
//
import SwiftUI
import GuardianCore

struct GuardianLabView: View {
    @Bindable var model: GuardianLabModel
    @Environment(AppSettings.self) private var settings
    @State private var shield = ShieldStudioModel()
    @State private var tab = 0
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: GTokens.s4) {
            // B-LANE — GEN8 LIVE INSIGHT: the primary Live Guardian surface. Reflects REAL state only.
            LiveGuardianInsightView(model: model)
                .padding(.horizontal, GTokens.s4)
                .padding(.top, GTokens.s2)

            // Default Guardian surface — Pure Bar, pinned under the safe area.
            PureBarView(state: model.surface, explanation: model.explanation)
                .padding(.horizontal, GTokens.s4)

            HStack {
                Toggle("Guardian", isOn: $model.guardianEnabled)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHint("Turns the Guardian runtime on or off. Off never claims Protected.")
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel(Text("Settings"))
            }
            .padding(.horizontal, GTokens.s4)

            Picker("Lab", selection: $tab) {
                Text("Short-form").tag(0)
                Text("Long-form").tag(1)
                Text("My Shield").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, GTokens.s4)

            ScrollView {
                if tab == 0 { shortForm } else if tab == 1 { longForm } else { MyShieldView(model: shield) }
                // Engineering panels are hidden from normal use; Developer Mode reveals them.
                if tab != 2 && settings.developerMode {
                    diagnostics; P007EvidencePanel()
                    #if DEBUG
                    GuardianIntelligenceHUD()   // P009B §25 — DEBUG builds only; proves the mesh operates
                    #endif
                }
            }
        }
        .sheet(isPresented: $model.showAskSheet) { askSheet }
        .sheet(isPresented: $showSettings) { settingsSheet }
    }

    @ViewBuilder private var settingsSheet: some View {
        @Bindable var s = settings
        NavigationStack {
            Form {
                Section("Language") {
                    Picker("Language", selection: $s.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Section {
                    Toggle("Developer Mode", isOn: $s.developerMode)
                } footer: {
                    Text("Developer options are hidden from normal use.")
                }
                // A3 — the lab simulation (synthetic 'active') is DEVELOPER-ONLY. A normal user never sees it; the
                // product default is REAL-heartbeat-derived observation. Turning Guardian ON in product mode never
                // claims OBSERVING until a real broadcast heartbeat proves the session is live.
                if s.developerMode {
                    Section {
                        Toggle("Lab mode (synthetic session)", isOn: $model.labMode)
                            .onChange(of: model.labMode) { _, nowLab in
                                // Switching OUT of lab must drop any synthetic ACTIVE and re-derive from the REAL
                                // broadcast heartbeat; switching INTO lab restores the controlled-harness path.
                                if model.guardianEnabled {
                                    let was = model.guardianEnabled
                                    model.guardianEnabled = false
                                    model.guardianEnabled = was
                                }
                                _ = nowLab
                            }
                    } footer: {
                        Text("Developer-only. Lab mode simulates the OS confirming a broadcast (controlled harness). Product mode (default) derives observation-active ONLY from a REAL broadcast heartbeat over the App Group — no synthetic 'active'.")
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .presentationDetents([.medium])
    }

    // MARK: Short-form harness
    private var shortForm: some View {
        VStack(alignment: .leading, spacing: GTokens.s3) {
            #if os(iOS)
            CrossAppObservationView()
            #endif
            let c = model.currentCandidate
            VStack(alignment: .leading, spacing: GTokens.s2) {
                Text("Candidate \(model.feedIndex + 1)/\(model.feedCount)")
                    .font(.caption).foregroundStyle(.secondary)
                Text(c.id.raw).font(.headline)
                if let f = c.fixture, !f.topics.isEmpty {
                    Text("Topics: \(f.topics.joined(separator: ", "))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                // Raw cache/coverage/reason-code chips are engineering detail → Developer Mode only.
                if settings.developerMode {
                    HStack(spacing: GTokens.s2) {
                        chip(model.lastDecisionCached ? "cached" : "fresh", .blue)
                        chip(model.surface.coverage.rawValue.lowercased(), .gray)
                        if !model.lastReason.isEmpty { chip(model.lastReason, .orange) }
                    }
                }
            }
            .padding(GTokens.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))

            HStack(spacing: GTokens.s3) {
                Button("Re-decide") { Task { await model.decideCurrent() } }
                    .frame(minHeight: GTokens.minTouch)
                Button("Next →") { Task { await model.advance() } }
                    .frame(maxWidth: .infinity, minHeight: GTokens.minTouch)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, GTokens.s4)
        .task { await model.decideCurrent() }
    }

    // MARK: Long-form harness
    private var longForm: some View {
        VStack(alignment: .leading, spacing: GTokens.s3) {
            // Engineering-only controls (raw version/mode) — Developer Mode only.
            if settings.developerMode {
                Toggle("Use wrong-version TemporalGraph", isOn: $model.useWrongVersion)
                    .onChange(of: model.useWrongVersion) { _, _ in model.tickTemporal() }
                Picker("Temporal mode", selection: $model.temporalMode) {
                    ForEach(TemporalGuardMode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }.pickerStyle(.segmented)
            }

            HStack {
                Text("Playhead").font(.caption)
                Spacer()
                Text("\(Int(model.playhead))s").monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: $model.playhead, in: 0...model.temporalDuration, step: 1)
                .onChange(of: model.playhead) { _, _ in model.tickTemporal() }

            if let banner = model.temporalBanner {
                Label(banner, systemImage: "exclamationmark.triangle")
                    .font(.footnote).padding(GTokens.s3)
                    .background(GuardianSurfaceState.Tone.caution.color.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: GTokens.radius))
            }
            Text(model.temporalStatus).font(.caption).foregroundStyle(.secondary)

            Button("Evaluate skip of next flagged segment") { model.requestSkip() }
                .frame(maxWidth: .infinity, minHeight: GTokens.minTouch)
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, GTokens.s4)
        .task { model.tickTemporal() }
    }

    private var askSheet: some View {
        VStack(spacing: GTokens.s4) {
            Text("Flagged segment ahead").font(.headline)
            if let s = model.pendingSkipSegment {
                Text("Segment \(Int(s.startSeconds))–\(Int(s.endSeconds))s. Skip it or continue?")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            HStack(spacing: GTokens.s3) {
                Button("Continue") { model.continueThrough() }
                    .frame(maxWidth: .infinity, minHeight: GTokens.minTouch).buttonStyle(.bordered)
                Button("Skip") { model.confirmSkip() }
                    .frame(maxWidth: .infinity, minHeight: GTokens.minTouch).buttonStyle(.borderedProminent)
            }
        }
        .padding(GTokens.s6)
        .presentationDetents([.medium])
    }

    // MARK: Internal diagnostics (debug only)
    private var diagnostics: some View {
        DisclosureGroup("Diagnostics (internal)") {
            let s = model.snapshot
            VStack(alignment: .leading, spacing: GTokens.s1) {
                diagRow("cache hits / misses", "\(s.cacheHits) / \(s.cacheMisses)")
                diagRow("preflight runs", "\(s.preflightRuns)")
                diagRow("cancellations", "\(s.cancellations)")
                diagRow("duplicate analysis prevented", "\(s.duplicateAnalysisPrevented)")
                diagRow("peak concurrent tasks", "\(s.peakConcurrentTasks)")
                diagRow("decisions", "\(s.decisionCount)")
                diagRow("decision latency p50 (ns)", "\(s.decisionLatencyP50Nanos)")
                diagRow("network bytes", "\(s.networkBytes)")
            }
            .font(.caption.monospacedDigit())

            Divider().padding(.vertical, GTokens.s2)

            // Real preflight debug (002A §18) — REAL vs UNAVAILABLE provider heads.
            Text("Real preflight (debug)").font(.caption.weight(.semibold))
            Button("Run real preflight") { Task { await model.runRealPreflightDebug() } }
                .font(.caption).frame(minHeight: GTokens.minTouch)
            Text(model.preflightSummary).font(.caption2.monospaced()).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(model.preflightHeads) { h in
                HStack {
                    Text(h.id).foregroundStyle(.secondary)
                    Spacer()
                    Text(h.state)
                        .foregroundStyle(h.state == "REAL" ? Color.green : (h.state == "UNAVAILABLE" ? .secondary : .orange))
                }.font(.caption2.monospaced())
            }
        }
        .padding(GTokens.s4)
    }

    private func diagRow(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(.secondary); Spacer(); Text(v) }
    }

    private func chip(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption2.weight(.medium))
            .padding(.horizontal, GTokens.s2).padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }
}
