//
//  LiveGuardianInsightView.swift — B-LANE: GEN8 LIVE INSIGHT (the main user-facing Live Guardian surface).
//
//  WHY THIS EXISTS (mandate B1–B3): previously the app had no honest, Apple-clean surface that reflected the REAL
//  Guardian state — observation lifecycle, content changes, Tier-1 identity confidence, analysis, the decision and
//  the EVIDENCE TYPE it rests on. This card is that surface. Every line is a projection of REAL model state
//  (GuardianLabModel: userVisibleState, isReEvaluating, liveReasonCode, heartbeatFreshness) — never decoration.
//
//  PRIVACY (D-lane): NO raw OCR text, NO screenshots, NO content titles, NO sensitive info ever appears here. Only
//  the lock-safe categorical state + the evidence TYPE (text/visual/none) + a short reason string are shown.
//
import SwiftUI
import GuardianCore

struct LiveGuardianInsightView: View {
    @Bindable var model: GuardianLabModel
    @State private var showWhy = false
    @State private var showTimeline = false

    private var state: GuardianUserVisibleState { model.userVisibleState }

    var body: some View {
        VStack(alignment: .leading, spacing: GTokens.s3) {
            header
            Divider()
            lifecycleRows
            if model.isReEvaluating { reEvaluatingRow }
            decisionRow
            if state == .shieldMatch { personalFilterRow }
            Divider()
            sessionModeRow     // §5 — user-controlled ACTIVE/IDLE (one tap, reachable from the app)
            displayStyleRow    // §2.1 — HEAT MAP / EMOJI / NUMBER(locked)
            HStack(spacing: GTokens.s3) {
                whyButton
                timelineButton
            }
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
        .overlay(RoundedRectangle(cornerRadius: GTokens.radius).strokeBorder(accent.opacity(0.25)))
        .animation(.easeInOut(duration: 0.25), value: model.isReEvaluating)   // B2: transition bound to REAL state
        .animation(.easeInOut(duration: 0.25), value: state)
        .sheet(isPresented: $showWhy) { whySheet }
        .sheet(isPresented: $showTimeline) { GuardianSessionTimelineView(model: model) }
        .accessibilityElement(children: .contain)
    }

    // MARK: Header — the single honest headline + a status dot (no numeric score, no content title)

    private var header: some View {
        HStack(spacing: GTokens.s3) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Live Guardian").font(.headline)
                Text(headline).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Circle().fill(accent).frame(width: 10, height: 10)
                .accessibilityLabel(Text(headline))
        }
    }

    // MARK: Lifecycle rows — each is a real fact derived from the model

    private var lifecycleRows: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            factRow("Guardian", model.guardianEnabled ? "Etkin" : "Kapalı", ok: model.guardianEnabled)
            // A3 — REAL observation-active evidence (product mode) vs explicit lab simulation.
            if model.labMode {
                factRow("Gözlem", observationLabel, ok: state.impliesActiveProtection, note: "lab")
            } else {
                // §B — BROADCAST state and ANALYSIS state shown as SEPARATE facts (never one "protected" flag).
                let proj = model.observationProjection
                factRow("Yayın (OS)", proj.broadcasting ? "Canlı" : "Yok", ok: proj.broadcasting)
                factRow("Analiz", analysisLabel(proj), ok: proj.analysisRunning)
                factRow("Yayın bağlantısı (IPC)", model.heartbeatIPCActive ? "Aktif" : "DEGRADED", ok: model.heartbeatIPCActive)
            }
        }
    }

    /// §B — honest analysis-state copy. Running only when live + enabled + not idle; otherwise it names WHY (OS feed
    /// continues but analysis is off because Guardian is off or the user is idle).
    private func analysisLabel(_ proj: GuardianObservationProjectionV1) -> String {
        if proj.analysisRunning { return "Çalışıyor" }
        if proj.broadcastingButAnalysisOff { return model.guardianEnabled ? "Duraklatıldı (rölanti)" : "Kapalı (yayın sürüyor)" }
        return "—"
    }

    /// One lifecycle fact: label · value · an honest OK/not-OK dot. `note` shows e.g. "lab" without implying truth.
    private func factRow(_ label: String, _ value: String, ok: Bool, note: String? = nil) -> some View {
        HStack(spacing: GTokens.s2) {
            Circle().fill(ok ? Color.green : Color.secondary).frame(width: 7, height: 7)
            Text(label).font(.caption).foregroundStyle(.secondary)
            if let note { Text("(\(note))").font(.caption2).foregroundStyle(.tertiary) }
            Spacer()
            Text(value).font(.caption.weight(.medium))
        }
        .accessibilityElement(children: .combine)
    }

    private var reEvaluatingRow: some View {
        HStack(spacing: GTokens.s2) {
            ProgressView().controlSize(.small)
            Text("Yeniden değerlendiriliyor…").font(.callout.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: Decision row — the current decision + the EVIDENCE TYPE it rests on

    private var decisionRow: some View {
        VStack(alignment: .leading, spacing: GTokens.s1) {
            HStack {
                Text("Karar").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(decisionLabel).font(.callout.weight(.semibold)).foregroundStyle(accent)
            }
            HStack {
                Text("Kanıt türü").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Label(evidenceType.text, systemImage: evidenceType.symbol)
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text("Sonuç").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(resultFreshness).font(.caption).foregroundStyle(model.isReEvaluating ? .orange : .secondary)
            }
        }
        .padding(.top, GTokens.s1)
    }

    // B4 — the applied personal preference + the HONEST surface-control truth. On a 3rd-party app (ReplayKit) we
    // can only WARN; we never claim we hid/skipped content (constitution rule 18). This row makes that explicit.
    private var personalFilterRow: some View {
        VStack(alignment: .leading, spacing: GTokens.s1) {
            HStack {
                Label("Kişisel tercih", systemImage: "shield.lefthalf.filled")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Uyarıldı").font(.callout.weight(.semibold)).foregroundStyle(.orange)
            }
            Text("Bu başka bir uygulama olduğundan içeriği gizleyemeyiz; yalnızca uyarabiliriz.")
                .font(.caption2).foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, GTokens.s1)
        .accessibilityElement(children: .combine)
    }

    // §5 — USER-CONTROLLED ACTIVE/IDLE, reachable from the app (one tap). Honest: idle pauses heavy analysis and
    // makes NO "koruma aktif" claim; it does NOT stop the OS broadcast. Disabled when Guardian is off or the App
    // Group IPC can't reach the extension (we say so rather than pretend the toggle took effect).
    private var sessionModeRow: some View {
        VStack(alignment: .leading, spacing: GTokens.s1) {
            Toggle(isOn: Binding(get: { model.sessionIdle }, set: { model.setSessionIdle($0) })) {
                Label(model.sessionIdle ? "Rölanti (analiz duraklatıldı)" : "Analiz açık",
                      systemImage: model.sessionIdle ? "pause.circle" : "waveform")
                    .font(.callout.weight(.medium))
            }
            .disabled(!model.guardianEnabled)
            if !model.idleToggleReachesExtension {
                Text("Not: App Group bağlantısı yok — bu anahtar yayın sürecine ulaşamıyor.")
                    .font(.caption2).foregroundStyle(.orange)
            } else if model.sessionModeDiverges {
                // §B — the user's desire and the extension's CONFIRMED applied mode disagree (a tap still in flight).
                // Honest: we show BOTH, never pretend the request already took effect.
                Label("İsteniyor: \(model.sessionIdle ? "Rölanti" : "Analiz") · Uygulandı: bekleniyor",
                      systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption2).foregroundStyle(.orange)
            } else if model.appliedModeIdle == nil && model.observationProjection.broadcasting {
                Text("İsteniyor: \(model.sessionIdle ? "Rölanti" : "Analiz") · Uygulandı: henüz onaylanmadı")
                    .font(.caption2).foregroundStyle(.secondary)
            } else if model.sessionIdle {
                Text("Yayın sürüyor ama içerik şu an incelenmiyor. İçerik analizini sürdürmek için kapat.")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // §2.1 — the THREE display modes. All render the SAME real state; NUMBER is visible but LOCKED (honest copy).
    private var displayStyleRow: some View {
        VStack(alignment: .leading, spacing: GTokens.s1) {
            Text("Gösterim").font(.caption).foregroundStyle(.secondary)
            Picker("Gösterim", selection: Binding(get: { AppSettings.shared.displayStyle },
                                                  set: { AppSettings.shared.displayStyle = $0 })) {
                ForEach(GuardianDisplayStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
            if AppSettings.shared.displayStyle.isLocked {
                Label(AppSettings.shared.displayStyle.lockedNote, systemImage: "lock.fill")
                    .font(.caption2).foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var whyButton: some View {
        Button { showWhy = true } label: {
            Label("Neden?", systemImage: "questionmark.circle")
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: GTokens.minTouch)
        }
        .buttonStyle(.bordered)
        .accessibilityHint(Text("Bu kararın gerekçesini gösterir."))
    }

    // E-lane — entry point to the "Bu Oturum" (This Session) live timeline. Shows the real event count.
    private var timelineButton: some View {
        Button { showTimeline = true } label: {
            HStack(spacing: GTokens.s2) {
                Image(systemName: "list.bullet.rectangle")
                Text("Bu Oturum")
                if !model.timelineEvents.isEmpty {
                    Text("\(model.timelineEvents.count)")
                        .font(.caption2.weight(.bold)).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(accent, in: Capsule())
                }
            }
            .font(.callout.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: GTokens.minTouch)
        }
        .buttonStyle(.bordered)
        .accessibilityHint(Text("Bu oturumdaki Guardian olaylarını gösterir."))
    }

    private var whySheet: some View {
        VStack(alignment: .leading, spacing: GTokens.s4) {
            HStack {
                Image(systemName: symbol).font(.title2).foregroundStyle(accent)
                Text("Neden?").font(.title2.weight(.semibold))
            }
            Text(model.whyExplanation)
                .font(.body).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            // Honest provenance: no evidence → say so. Supported categories only.
            Text(provenanceNote).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Kapat") { showWhy = false }
                .frame(maxWidth: .infinity, minHeight: GTokens.minTouch)
                .buttonStyle(.borderedProminent)
        }
        .padding(GTokens.s6)
        .presentationDetents([.height(260)])
    }

    // MARK: - Derived (pure projections of REAL model state)

    private var headline: String {
        if !model.guardianEnabled { return "Kapalı" }
        if model.isReEvaluating { return "Yeniden değerlendiriliyor" }
        switch state {
        case .off:               return "Kapalı"
        case .unavailable:       return "Kullanılamıyor"
        case .starting:          return "Başlatılıyor"
        case .observing:         return "Gözlemde"
        case .observingIdle:     return "Rölanti"
        case .analyzing:         return "Analiz ediliyor"
        case .evidenceAvailable: return "Dikkat edilecek bir şey yok"
        case .caution:           return "Dikkat"
        case .unknown:           return "Belirsiz"
        case .shieldMatch:       return "Kalkan eşleşmesi"
        }
    }

    private var observationLabel: String {
        if !model.guardianEnabled { return "—" }
        if !model.labMode {
            switch model.heartbeatFreshness {
            case .active: return "Aktif (gerçek yayın)"
            case .stale:  return "Yayın durdu / yanıt yok"
            case .absent: return "Yayın yok"
            }
        }
        return state.impliesActiveProtection ? "Aktif" : (state == .starting ? "Başlatılıyor" : "Pasif")
    }

    private var decisionLabel: String {
        if model.isReEvaluating { return "—" }
        switch state {
        case .caution:           return "Dikkat"
        case .shieldMatch:       return "Kalkan eşleşti"
        case .evidenceAvailable: return "Uygun"
        case .unknown:           return "Belirsiz"
        case .observing, .analyzing: return "Henüz karar yok"
        default:                 return "—"
        }
    }

    private enum EvidenceType { case text, visual, none
        var text: String { switch self { case .text: "Metin"; case .visual: "Görsel"; case .none: "Yok" } }
        var symbol: String { switch self { case .text: "text.viewfinder"; case .visual: "eye"; case .none: "nosign" } }
    }
    private var evidenceType: EvidenceType {
        switch model.liveReasonCode {
        case .textEvidenceMatchedShield, .textEvidenceBenign: return .text
        case .visualEvidenceInsufficient:                     return .visual
        default:                                              return .none
        }
    }

    private var resultFreshness: String {
        if model.isReEvaluating { return "Geçersiz (içerik değişti)" }
        return state.impliesActiveProtection && (state == .caution || state == .shieldMatch || state == .evidenceAvailable)
            ? "Güncel" : "—"
    }

    private var provenanceNote: String {
        switch model.liveReasonCode {
        case .some:  return "Bu açıklama gerçek motor kanıtından üretildi."
        case .none:  return "Desteklenen bir kanıt bulunmadığından açıklama üretilmedi (dürüst: uydurma yok)."
        }
    }

    private var symbol: String {
        GuardianSurfaceSymbolAdapter.icon(state.nativeSurface)
    }
    private var accent: Color {
        switch state {
        case .caution:                        return .orange
        case .shieldMatch:                    return .red
        case .evidenceAvailable, .observing:  return .green
        case .unknown, .analyzing, .starting: return .secondary
        case .observingIdle:                  return .secondary   // §5.4 — idle: neutral, never a protective green
        case .off, .unavailable:              return .secondary
        }
    }
}

/// Small adapter so this view uses the SAME surface→symbol vocabulary as the widget/Live Activity (no divergence).
private enum GuardianSurfaceSymbolAdapter {
    static func icon(_ surface: NativeSurfaceState) -> String {
        #if canImport(ActivityKit)
        return GuardianSurfaceSymbol.icon(surface.rawValue)
        #else
        switch surface.rawValue {
        case "GUARDIAN_ON": return "shield.lefthalf.filled"
        case "CAUTION": return "exclamationmark.triangle"
        case "SHIELD_MATCH": return "eye.slash"
        case "OFF": return "shield.slash"
        default: return "questionmark.circle"
        }
        #endif
    }
}
