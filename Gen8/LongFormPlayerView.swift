//
//  LongFormPlayerView.swift — mandate §F: the USER-FACING LONG-FORM PLAYER surface (Apple-quality, honest).
//
//  This is the consumer long-form experience: a REAL AVPlayer playing a REAL, OWNED long demo video (generated on
//  demand at a short 120s demo spec so it is interactive), driven by LongFormGuardianModelV1 across time. It:
//    • shows a FAST decision badge QUICKLY (the first valid, limited-evidence verdict),
//    • shows an honest "ek analiz sürüyor" state while the fuller SELECTIVE/DEEPENING pass runs,
//    • honors the SAME HIDE/ASK/WARN/BLUR/MUTE action contracts as the controlled-reels shield surface (reused copy),
//    • renders an EVIDENCE-MAP TIMELINE STRIP over the whole asset: examined windows (dots), matched rule@second
//      (highlighted + rule name), audio vs visual markers distinguished, unexamined regions neutral "incelenmedi",
//      and a FAST-decision marker.
//
//  HONESTY: sparse sampling NEVER claims the whole video is safe; unexamined regions are shown as unexamined; no
//  0-100 score; the demo is labelled honestly as a 120s demo (the full 600s is the benchmark's domain, not this screen).
//  It reuses PlayerLayerView / BlurOverlayView from ControlledReelsView (same app module) — no duplication of the host.
//
import SwiftUI
import AVFoundation
import GuardianCore

struct LongFormPlayerView: View {
    @Bindable var model: LongFormPlayerModel
    var onEditRules: (() -> Void)? = nil
    @State private var showWhy = false
    @State private var showEvidenceMap = false

    var body: some View {
        VStack(spacing: GTokens.s3) {
            header
            surface
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: GTokens.radius))
            fastBadge
            deepeningIndicator
            timelineStripInline       // §F — the always-visible evidence strip over the WHOLE asset
            evidenceMapButton         // §F — the full İçerik Kanıtı sheet (per-window detail)
            provenanceFooter
        }
        .padding(.horizontal, GTokens.s4)
        .task { await model.start() }
        .onDisappear { model.stop() }
        .sheet(isPresented: $showWhy) { whySheet }
        .sheet(isPresented: $showEvidenceMap) {
            LongFormEvidenceMapSheet(outcomes: model.windowOutcomes, plan: model.plan,
                                     durationSeconds: model.durationSeconds,
                                     fastSeconds: model.fastExaminedSecond,
                                     examinedWindows: model.examinedWindows, plannedWindows: model.plannedWindows,
                                     ocrCalls: model.ocrCalls, audioWindows: model.audioWindows,
                                     framesDecoded: model.framesDecoded,
                                     deepeningExecuted: model.deepeningExecuted, deepeningDeferred: model.deepeningDeferred,
                                     recomputedFromCache: model.recomputedFromCache)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Uzun Video").font(.headline)
                // Honest label — this is explicitly the short demo, never claimed to be a full 600s video.
                Text(model.demoTitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if model.durationSeconds > 0 {
                Text("\(Int(model.durationSeconds))s")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: The real player surface + overlays

    @ViewBuilder private var surface: some View {
        ZStack {
            Color.black
            #if canImport(UIKit)
            PlayerLayerView(player: model.player)   // reused bare AVPlayerLayer host from ControlledReelsView
            #endif
            overlay
        }
    }

    @ViewBuilder private var overlay: some View {
        switch model.phase {
        case .idle, .generating:
            generatingOverlay
        case .analyzingFast:
            evaluatingOverlay
        case .failed(let msg):
            failedOverlay(msg)
        case .fastReady, .settled:
            actionOverlay
        }
    }

    // While the aggregate (or settled) decision is applied, show the shield surface that matches the real action.
    @ViewBuilder private var actionOverlay: some View {
        if let d = model.currentDecision {
            switch d.state {
            case .hidden:
                if model.coverEngaged { shieldCover } else { evaluatingOverlay }
            case .undetermined:
                undeterminedOverlay
            case .askUser:
                askApprovalOverlay
            case .blurred:
                if model.blurEngaged { blurOverlay } else { EmptyView() }
            case .muted:
                if model.muteEngaged { mutedIndicator } else { EmptyView() }
            case .warned:
                if model.warnEngaged { warnBanner } else { EmptyView() }
            case .playing, .userOverridden, .skipped, .pendingEvaluation, .evaluating:
                EmptyView()   // real video visible (or nothing to overlay)
            }
        } else {
            EmptyView()
        }
    }

    private var generatingOverlay: some View {
        VStack(spacing: GTokens.s2) {
            ProgressView().tint(.white)
            Text("Demo uzun video hazırlanıyor…").font(.callout).foregroundStyle(.white)
            Text("Gerçek bir 120 saniyelik video üretiliyor (birkaç saniye).")
                .font(.caption2).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
        }
        .padding(GTokens.s4).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
    }

    private var evaluatingOverlay: some View {
        VStack(spacing: GTokens.s2) {
            ProgressView().tint(.white)
            Text("Kanıt hazırlanıyor…").font(.callout).foregroundStyle(.white)
            Text("İlk karar için videonun başı kişisel kalkanınla kontrol ediliyor.")
                .font(.caption2).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
        }
        .padding(GTokens.s4).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
    }

    private func failedOverlay(_ msg: String) -> some View {
        VStack(spacing: GTokens.s2) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 30)).foregroundStyle(.orange)
            Text(msg).font(.callout).foregroundStyle(.white).multilineTextAlignment(.center)
            Text("‘Güvenli’ demiyoruz — analiz yapılamadı.").font(.caption2).foregroundStyle(.white.opacity(0.8))
        }
        .padding(GTokens.s4).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
    }

    // The SAME shield surfaces as the controlled-reels player (copy preserved for contract parity).
    private var shieldCover: some View {
        VStack(spacing: GTokens.s3) {
            Image(systemName: "hand.raised.fill").font(.system(size: 34)).foregroundStyle(.white)
            Text("Kişisel Kalkan").font(.headline).foregroundStyle(.white)
            Text("Bu videonun incelenen bir bölümü belirlediğin bir tercihle eşleşti.")
                .font(.callout).foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
            HStack(spacing: GTokens.s3) {
                actionButton("Yine de göster", "eye") { model.showAnyway() }
                actionButton("Kuralı düzenle", "slider.horizontal.3") { onEditRules?() }
            }
            actionButton("Neden gizlendi?", "questionmark.circle") { showWhy = true }
        }
        .padding(GTokens.s6).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
        .transition(.opacity)
    }

    private var undeterminedOverlay: some View {
        VStack(spacing: GTokens.s3) {
            Image(systemName: "questionmark.circle").font(.system(size: 34)).foregroundStyle(.white)
            Text("Emin değiliz").font(.headline).foregroundStyle(.white)
            Text("İncelenen zaman noktaları için yeterli kanıt elde edemedik. Senin yerine ‘güvenli’ demeyeceğiz.")
                .font(.caption).foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
            actionButton("Yine de göster", "eye") { model.showAnyway() }
        }
        .padding(GTokens.s6).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
    }

    private var askApprovalOverlay: some View {
        VStack(spacing: GTokens.s3) {
            Image(systemName: "hand.raised.circle").font(.system(size: 34)).foregroundStyle(.white)
            Text("Onayın gerekiyor").font(.headline).foregroundStyle(.white)
            Text("Bu videonun bir bölümü kişisel tercihinle eşleşti. Göstermeden önce onayını istiyoruz.")
                .font(.caption).foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
            actionButton("Göster", "eye") { model.showAnyway() }
        }
        .padding(GTokens.s6).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
    }

    private var blurOverlay: some View {
        ZStack {
            #if canImport(UIKit)
            BlurOverlayView()
            #else
            Color.black.opacity(0.01)
            #endif
            VStack(spacing: GTokens.s2) {
                Image(systemName: "eye.trianglebadge.exclamationmark").font(.system(size: 28)).foregroundStyle(.white)
                Text("Bulanıklaştırıldı").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text("Tercihin 'bulanıklaştır' olduğu için görüntü bulanık; video sürüyor.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
                actionButton("Göster", "eye") { model.showAnyway() }
            }
            .padding(GTokens.s4)
        }
    }

    private var mutedIndicator: some View {
        VStack {
            HStack(spacing: GTokens.s2) {
                Image(systemName: "speaker.slash.fill").foregroundStyle(.white)
                Text("Ses kapatıldı (kişisel tercih)").font(.caption.weight(.medium)).foregroundStyle(.white)
            }
            .padding(.horizontal, GTokens.s3).padding(.vertical, GTokens.s2)
            .background(.black.opacity(0.55), in: Capsule()).padding(.top, GTokens.s3)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var warnBanner: some View {
        VStack {
            HStack(spacing: GTokens.s2) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Uyarı").font(.caption.weight(.bold)).foregroundStyle(.white)
                    if let d = model.currentDecision {
                        Text(d.reason.turkishExplanation).font(.caption2).foregroundStyle(.white.opacity(0.9)).lineLimit(2)
                    }
                }
                Spacer()
                Button("Neden?") { showWhy = true }.font(.caption2.weight(.bold)).foregroundStyle(.white)
            }
            .padding(GTokens.s3).background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10)).padding(GTokens.s3)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func actionButton(_ title: String, _ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.footnote.weight(.medium))
                .padding(.horizontal, GTokens.s3).frame(minHeight: GTokens.minTouch)
        }
        .buttonStyle(.borderedProminent).tint(.white.opacity(0.18)).foregroundStyle(.white)
    }

    // MARK: FAST decision badge + deepening indicator

    // §F — the FAST decision badge appears QUICKLY: the first valid, limited-evidence verdict. It never claims the whole
    // video was understood — the label says it is the FIRST decision and the fuller pass may still be running.
    @ViewBuilder private var fastBadge: some View {
        if let f = model.fastDecision {
            HStack(spacing: GTokens.s2) {
                Image(systemName: fastSymbol(f)).foregroundStyle(fastColor(f))
                VStack(alignment: .leading, spacing: 1) {
                    Text("İlk karar: \(fastLabel(f))").font(.caption.weight(.semibold))
                    Text("Videonun başından sınırlı kanıtla — tüm video değil.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if let ms = model.firstValidDecisionMs {
                    Text("\(Int(ms)) ms").font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                }
            }
            .padding(GTokens.s3)
            .background(fastColor(f).opacity(0.12), in: RoundedRectangle(cornerRadius: GTokens.radius))
        }
    }

    // §F — the honest "ek analiz sürüyor" state while the SELECTIVE/DEEPENING pass runs past the fast decision.
    @ViewBuilder private var deepeningIndicator: some View {
        if model.phase == .fastReady {
            HStack(spacing: GTokens.s2) {
                ProgressView().controlSize(.small)
                Text("Ek analiz sürüyor — diğer zaman aralıkları inceleniyor…")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if model.phase == .settled {
            HStack(spacing: GTokens.s2) {
                Image(systemName: "checkmark.seal").foregroundStyle(.secondary)
                Text("Seçili zaman aralıkları incelendi · \(model.examinedWindows)/\(model.plannedWindows) pencere")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fastLabel(_ d: ReelDecisionV1) -> String {
        if d.matchState.isMatch { return "eşleşme bulundu" }
        if d.matchState.isNonDeterminable { return "belirsiz" }
        return "başta eşleşme yok"
    }
    private func fastSymbol(_ d: ReelDecisionV1) -> String {
        if d.matchState.isMatch { return "hand.raised.fill" }
        if d.matchState.isNonDeterminable { return "questionmark.circle" }
        return "checkmark.circle"
    }
    private func fastColor(_ d: ReelDecisionV1) -> Color {
        if d.matchState.isMatch { return GuardianSurfaceState.Tone.strongCaution.color }
        if d.matchState.isNonDeterminable { return GuardianSurfaceState.Tone.unknown.color }
        return GuardianSurfaceState.Tone.aligned.color
    }

    // MARK: Inline evidence strip (§F — over the WHOLE asset)

    @ViewBuilder private var timelineStripInline: some View {
        if model.durationSeconds > 0, !model.windowOutcomes.isEmpty {
            VStack(alignment: .leading, spacing: GTokens.s2) {
                Text("İçerik Kanıtı — zaman şeridi").font(.caption.weight(.semibold))
                LongFormTimelineStrip(outcomes: model.windowOutcomes, durationSeconds: model.durationSeconds,
                                      fastSeconds: model.fastExaminedSecond)
                Text("Dolu noktalar incelendi; kırmızı = eşleşme; şeridin geri kalanı incelenmedi.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var evidenceMapButton: some View {
        if !model.windowOutcomes.isEmpty {
            Button { showEvidenceMap = true } label: {
                Label("İçerik Kanıtı · \(model.examinedWindows) incelenen pencere", systemImage: "waveform.path.ecg.rectangle")
                    .font(.caption.weight(.medium)).frame(maxWidth: .infinity, minHeight: GTokens.minTouch)
            }
            .buttonStyle(.bordered)
        }
    }

    private var provenanceFooter: some View {
        HStack(spacing: 4) {
            Image(systemName: model.sharedContainerActive ? "externaldrive.badge.checkmark" : "externaldrive.badge.exclamationmark")
                .foregroundStyle(model.sharedContainerActive ? .green : .orange).font(.caption2)
            Text("Politika sürümü: \(model.policyRevision)").font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
            Spacer()
            if model.recomputedFromCache {
                Text("Kanıt yeniden kullanıldı").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var whySheet: some View {
        VStack(alignment: .leading, spacing: GTokens.s4) {
            Text("Neden bu karar?").font(.headline)
            if let d = model.currentDecision {
                Text(d.reason.turkishExplanation).font(.callout)
                Divider()
                if let rule = d.matchedRuleID { detailRow("Eşleşen kural", rule) }
                detailRow("Yüzey", "Kendi uzun-video oynatıcımız (kontrollü) — eylem gerçekten uygulanabilir")
                detailRow("Politika sürümü", "\(d.policyRevision)")
                Text("Yalnızca seçili zaman noktaları incelendi — tüm video değil. 0–100 arası puan yok.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(GTokens.s6).presentationDetents([.medium])
    }

    private func detailRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) { Text(k).foregroundStyle(.secondary); Spacer(); Text(v).multilineTextAlignment(.trailing) }
            .font(.caption)
    }
}

// MARK: - §F — the long-asset timeline strip (examined windows / matched rule@second / FAST marker / unexamined)
//
// Scaled to the FULL asset duration (0…duration), not just the examined span — so the UNEXAMINED regions are honestly
// visible as the neutral baseline between the examined dots. We NEVER paint a colored danger fill where there is no
// evidence. A matched window is a larger highlighted dot; a FAST-examined timepoint carries a small marker above it.
struct LongFormTimelineStrip: View {
    let outcomes: [LongFormWindowOutcomeV1]
    let durationSeconds: Double
    let fastSeconds: Double?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.18)).frame(height: 6)   // neutral baseline = unexamined
                ForEach(outcomes.indices, id: \.self) { i in
                    let o = outcomes[i]
                    let x = position(o.window.sampleSeconds, width: w)
                    Circle()
                        .fill(dotColor(o))
                        .frame(width: matched(o) ? 15 : 9, height: matched(o) ? 15 : 9)
                        .overlay(matched(o) ? Circle().strokeBorder(.white, lineWidth: 2) : nil)
                        .position(x: min(max(x, 8), w - 8), y: 18)
                    // distinguish audio-bearing windows with a small waveform tick above the dot
                    if o.audioRan {
                        Image(systemName: "waveform").font(.system(size: 8)).foregroundStyle(.secondary)
                            .position(x: min(max(x, 8), w - 8), y: 5)
                    }
                }
                if let fs = fastSeconds {
                    // FAST-decision marker — a downward chevron above its examined timepoint.
                    Image(systemName: "arrowtriangle.down.fill").font(.system(size: 9)).foregroundStyle(.blue)
                        .position(x: min(max(position(fs, width: w), 8), w - 8), y: 32)
                }
            }
            .frame(height: 36)
        }
        .frame(height: 36)
    }

    private func matched(_ o: LongFormWindowOutcomeV1) -> Bool { o.matchedRuleID != nil }
    private func position(_ t: Double, width: Double) -> Double {
        guard durationSeconds > 0 else { return width / 2 }
        return min(max(t, 0), durationSeconds) / durationSeconds * width
    }
    private func dotColor(_ o: LongFormWindowOutcomeV1) -> Color {
        if o.matchedRuleID != nil { return .red }
        switch o.status {
        case .examined:        return .green
        case .notDecoded:      return .secondary
        case .deferredThermal: return .orange
        case .skippedBudget, .cancelled: return .secondary.opacity(0.5)
        }
    }
}

// MARK: - §F — the full İçerik Kanıtı sheet for the long asset (per-window detail + honest coverage facts)
//
// Reuses the "İçerik Kanıtı" visual language from ControlledReelsView's VideoEvidenceMapSheet: a Görüntü (visual)
// timeline strip + per-point list with the matched RULE (not raw screen text), a distinct Ses (audio) accounting,
// and an honesty footer with SEPARATED coverage counts. Never claims the whole video is safe.
struct LongFormEvidenceMapSheet: View {
    let outcomes: [LongFormWindowOutcomeV1]
    let plan: LongFormPlanV1?
    let durationSeconds: Double
    let fastSeconds: Double?
    let examinedWindows: Int
    let plannedWindows: Int
    let ocrCalls: Int
    let audioWindows: Int
    let framesDecoded: Int
    let deepeningExecuted: Int
    let deepeningDeferred: Int
    let recomputedFromCache: Bool

    private var visualOutcomes: [LongFormWindowOutcomeV1] {
        outcomes.filter { $0.ocrRan || $0.status == .notDecoded }.sorted { $0.window.sampleSeconds < $1.window.sampleSeconds }
    }
    private var audioOutcomes: [LongFormWindowOutcomeV1] {
        outcomes.filter { $0.audioRan && !$0.audioLabels.isEmpty }.sorted { $0.window.sampleSeconds < $1.window.sampleSeconds }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GTokens.s4) {
                header
                if let p = plan { strategyRow(p) }
                Text("Görüntü").font(.headline)
                LongFormTimelineStrip(outcomes: outcomes, durationSeconds: durationSeconds, fastSeconds: fastSeconds)
                legend
                Divider()
                visualList
                Divider()
                audioLayer
                footerHonesty
                Spacer(minLength: 0)
            }
            .padding(GTokens.s6)
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("İçerik Kanıtı").font(.title2.weight(.semibold))
            Text("Bu uzun videonun hangi zaman aralıklarını inceledik (görüntü), hangi ses olaylarını duyduk (ses), nerede eşleşme bulduk — ve nerede incelemedik.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func strategyRow(_ p: LongFormPlanV1) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Plan: \(strategyLabel(p.strategy)) · bütçe \(p.budgetWindows) pencere")
                .font(.caption.weight(.medium))
            Text("Termal: \(p.thermal.rawValue.lowercased()) · OCR: \(p.requestsOCR ? "evet" : "hayır") · Ses: \(p.requestsAudio ? "evet" : "hayır")")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
    private func strategyLabel(_ s: LongFormPlanStrategyV1) -> String {
        switch s {
        case .conservativeCoverage: return "Tutumlu kapsam (düşük bütçe)"
        case .thoroughCoverage:     return "Kapsamlı inceleme"
        }
    }

    private var legend: some View {
        HStack(spacing: GTokens.s4) {
            legendItem(.green, "İncelendi")
            legendItem(.red, "Eşleşme")
            legendItem(.orange, "Ertelendi (termal)")
            legendItem(.secondary.opacity(0.5), "İncelenmedi")
        }
        .font(.caption2)
    }
    private func legendItem(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) { Circle().fill(c).frame(width: 8, height: 8); Text(t).foregroundStyle(.secondary) }
    }

    private var visualList: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            ForEach(visualOutcomes.indices, id: \.self) { i in
                let o = visualOutcomes[i]
                HStack(alignment: .top, spacing: GTokens.s2) {
                    Circle().fill(o.matchedRuleID != nil ? Color.red : .green).frame(width: 8, height: 8).padding(.top, 4)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "%.0fs — %@", o.window.sampleSeconds, outcomeLabel(o)))
                            .font(.caption.weight(.medium))
                        if let rule = o.matchedRuleID {
                            Text("Eşleşen kural: \(rule)").font(.caption2).foregroundStyle(.red)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    private var audioLayer: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Text("Ses").font(.headline)
            if audioOutcomes.isEmpty {
                Text("Ses analizi bu video için çalışmadı veya ses olayı bulunamadı — bu 'sessiz/güvenli' demek DEĞİLDİR.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(audioOutcomes.indices, id: \.self) { i in
                    let o = audioOutcomes[i]
                    HStack(alignment: .top, spacing: GTokens.s2) {
                        Image(systemName: o.matchedRuleID != nil ? "waveform.badge.exclamationmark" : "waveform")
                            .foregroundStyle(o.matchedRuleID != nil ? .red : .secondary).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(format: "%.0fs — %@", o.window.sampleSeconds, o.audioLabels.joined(separator: ", ")))
                                .font(.caption.weight(.medium))
                            if let rule = o.matchedRuleID {
                                Text("Eşleşen ses tercihi: \(rule)").font(.caption2).foregroundStyle(.red)
                            }
                        }
                        Spacer()
                    }
                }
                Text("Kanıt: Apple Sound Analysis · Ses. Ham ses saklanmaz; etiket bir risk puanı DEĞİLDİR.")
                    .font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footerHonesty: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Yalnızca \(examinedWindows)/\(plannedWindows) zaman penceresi incelendi — tüm video değil. İncelenmeyen aralıklarda bir olay kaçmış olabilir.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Örnekleme: OCR \(ocrCalls) · ses penceresi \(audioWindows) · çözülen kare \(framesDecoded) · derinleşen \(deepeningExecuted) · ertelenen \(deepeningDeferred)")
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if deepeningDeferred > 0 {
                Text("Termal/bellek baskısı nedeniyle \(deepeningDeferred) derinleşme penceresi ertelendi — kapsam daha sınırlı.")
                    .font(.caption2).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if recomputedFromCache {
                Text("Karar, daha önce çıkarılmış kanıttan yeniden hesaplandı (yeniden kod çözme yapılmadı).")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Text("Örneklenen noktalar temizse bu 'videonun tamamı güvenli' demek değildir. 0–100 arası puan yok.")
                .font(.caption2).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func outcomeLabel(_ o: LongFormWindowOutcomeV1) -> String {
        if o.matchedRuleID != nil { return "eşleşme bulundu" }
        switch o.status {
        case .examined:        return o.ocrText.isEmpty ? "incelendi (okunur metin yok)" : "incelendi"
        case .notDecoded:      return "çözülemedi"
        case .deferredThermal: return "ertelendi (termal)"
        case .skippedBudget:   return "atlandı (bütçe)"
        case .cancelled:       return "iptal edildi"
        }
    }
}
