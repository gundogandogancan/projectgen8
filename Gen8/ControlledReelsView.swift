//
//  ControlledReelsView.swift — B/B5: the GEN8 CONTROLLED REELS PLAYER surface (Apple-quality, honest).
//
//  This is GEN8's FIRST real video-playback control surface. It renders our OWN AVPlayer through a bare
//  AVPlayerLayer (so WE fully control what the user sees — no AVPlayerViewController chrome we can't cover), and
//  it OBEYS the ControlledReelsModel's honest per-reel state:
//   - .playing      → the real video plays (image + audio).
//   - .evaluating   → "Kanıt hazırlanıyor…" (B1 pre-playback gate; nothing plays yet).
//   - .hidden       → B2/B5 shield: a full opaque cover over the layer (no last-frame/thumbnail leak) + the Apple-
//                     quality copy "Kişisel Kalkan — Bu içerik belirlediğin bir tercihle eşleşti." with the four
//                     honest actions: Atla · Yine de göster · Kuralı düzenle · Neden gizlendi?
//   - .undetermined → an explicit decision screen (B1): UNKNOWN is never presented as safe or auto-played.
//
//  No 0-100 score anywhere (constitution rule 8). Every claim ("Gizlendi") is shown only when the model confirms
//  the player is really paused+muted+covered (model.coverEngaged).
//
import SwiftUI
import AVFoundation
import GuardianCore

struct ControlledReelsView: View {
    @Bindable var model: ControlledReelsModel
    var onEditRules: (() -> Void)? = nil
    @State private var showWhy = false
    @State private var showEvidenceMap = false   // E3 — the "Video Kanıtı" temporal evidence sheet

    var body: some View {
        VStack(spacing: GTokens.s3) {
            header
            surface
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: GTokens.radius))
            controls
            provenanceFooter
            evidenceMapButton      // E3 — "Video Kanıtı": which timepoints were examined / matched / unexamined
            timelineDisclosure
        }
        .padding(.horizontal, GTokens.s4)
        .task { await model.start() }
        .onDisappear { model.stop() }
        .sheet(isPresented: $showWhy) { whySheet }
        .sheet(isPresented: $showEvidenceMap) {
            if let d = model.currentDecision {
                VideoEvidenceMapSheet(decision: d)
            }
        }
    }

    // E3 — entry to the Temporal Evidence Map. Shown only when there is a real decision with examined timepoints
    // (otherwise there is nothing honest to show). The count names examined timepoints, never "whole video".
    @ViewBuilder private var evidenceMapButton: some View {
        if let d = model.currentDecision, !d.timedEvidence.isEmpty {
            Button { showEvidenceMap = true } label: {
                // §G — renamed "Video Kanıtı" → "İçerik Kanıtı": the sheet now has a Görüntü (visual) AND a Ses (audio)
                // layer, so "İçerik" (content) is the honest umbrella. The count names examined timepoints, never "whole video".
                Label("İçerik Kanıtı · \(d.timedEvidence.count) zaman noktası", systemImage: "waveform.path.ecg.rectangle")
                    .font(.caption.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: GTokens.minTouch)
            }
            .buttonStyle(.bordered)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Kontrollü Oynatıcı").font(.headline)
                if let item = model.currentItem {
                    Text(item.title).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            // §E — OPTIONAL low-profile "sıradaki hazır" indicator. No notification, no attention-grab: a tiny chip
            // that simply tells the user the NEXT reel was already evaluated. Shown only when a valid prefetch is cached.
            if model.nextPrefetchReady {
                Label("Sıradaki hazır", systemImage: "bolt.badge.clock")
                    .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.secondary.opacity(0.12), in: Capsule())
                    .accessibilityLabel("Sıradaki içerik önceden değerlendirildi")
            }
            if !model.items.isEmpty {
                Text("\(model.currentIndex + 1)/\(model.items.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: The real player surface + overlays

    @ViewBuilder private var surface: some View {
        ZStack {
            Color.black
            #if canImport(UIKit)
            PlayerLayerView(player: model.player)
            #endif
            overlay
        }
    }

    @ViewBuilder private var overlay: some View {
        switch model.currentState {
        case .evaluating, .pendingEvaluation:
            evaluatingOverlay
        case .hidden:
            if model.coverEngaged { shieldCover } else { evaluatingOverlay }
        case .undetermined:
            undeterminedOverlay
        case .askUser:
            askApprovalOverlay          // C1 — a real match awaiting the user's approval (distinct from UNDETERMINED)
        case .blurred:
            if model.blurEngaged { blurOverlay } else { EmptyView() }   // C1 — real Gaussian blur over playing video
        case .muted:
            if model.muteEngaged { mutedIndicator } else { EmptyView() } // C1 — visible muted indicator; video plays
        case .warned:
            if model.warnEngaged { warnBanner } else { EmptyView() }     // C1 — warning banner over playing content
        case .playing, .userOverridden, .skipped:
            EmptyView()       // the real video is visible; no overlay
        }
    }

    private var evaluatingOverlay: some View {
        VStack(spacing: GTokens.s2) {
            ProgressView().tint(.white)
            Text("Kanıt hazırlanıyor…").font(.callout).foregroundStyle(.white)
            Text("Oynatım öncesi kişisel kalkanınla kontrol ediliyor.")
                .font(.caption2).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)   // opaque — no frame leak during the gate
    }

    // B2/B5 — the HIDE surface. Fully opaque (last-frame/thumbnail cannot leak), Apple-quality copy + 4 actions.
    private var shieldCover: some View {
        VStack(spacing: GTokens.s3) {
            Image(systemName: "hand.raised.fill").font(.system(size: 34)).foregroundStyle(.white)
            Text("Kişisel Kalkan").font(.headline).foregroundStyle(.white)
            Text("Bu içerik belirlediğin bir tercihle eşleşti.")
                .font(.callout).foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
            HStack(spacing: GTokens.s3) {
                actionButton("Atla", "forward.end") { Task { await model.skip() } }
                actionButton("Yine de göster", "eye") { Task { await model.showAnyway() } }
            }
            HStack(spacing: GTokens.s3) {
                actionButton("Kuralı düzenle", "slider.horizontal.3") { onEditRules?() }
                actionButton("Neden gizlendi?", "questionmark.circle") { showWhy = true }
            }
        }
        .padding(GTokens.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .transition(.opacity)
        // A4 — WARNING_PRESENTED is recorded ONLY when the shield cover actually appears (honest UI tie).
        .onAppear { model.markWarningPresented() }
    }

    private var undeterminedOverlay: some View {
        VStack(spacing: GTokens.s3) {
            Image(systemName: "questionmark.circle").font(.system(size: 34)).foregroundStyle(.white)
            Text("Emin değiliz").font(.headline).foregroundStyle(.white)
            Text("Bu içerik için yeterli kanıt elde edemedik. Senin yerine ‘güvenli’ demeyeceğiz — kararı sana bırakıyoruz.")
                .font(.caption).foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
            HStack(spacing: GTokens.s3) {
                actionButton("Atla", "forward.end") { Task { await model.skip() } }
                actionButton("Yine de göster", "eye") { Task { await model.showAnyway() } }
            }
        }
        .padding(GTokens.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    // C1 — ASK approval: a REAL match the policy wants the user to approve before exposure (not an abstention).
    private var askApprovalOverlay: some View {
        VStack(spacing: GTokens.s3) {
            Image(systemName: "hand.raised.circle").font(.system(size: 34)).foregroundStyle(.white)
            Text("Onayın gerekiyor").font(.headline).foregroundStyle(.white)
            Text("Bu içerik kişisel tercihinle eşleşti. Göstermeden önce onayını istiyoruz.")
                .font(.caption).foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
            HStack(spacing: GTokens.s3) {
                actionButton("Atla", "forward.end") { Task { await model.skip() } }
                actionButton("Göster", "eye") { Task { await model.showAnyway() } }
            }
        }
        .padding(GTokens.s6).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
    }

    // C1 — BLUR: the real video keeps playing UNDERNEATH; a live Gaussian blur overlay obscures the image. Audio
    // continues (blur is a visual action). A small chip names the reason + offers "Göster"/"Neden?". This is a REAL
    // on-surface blur (UIVisualEffectView over the AVPlayerLayer), not a fake cover — the frames are still rendering.
    private var blurOverlay: some View {
        ZStack {
            #if canImport(UIKit)
            BlurOverlayView()        // UIVisualEffectView(.systemUltraThinMaterial) over the live player layer
            #else
            Color.black.opacity(0.01)
            #endif
            VStack(spacing: GTokens.s2) {
                Image(systemName: "eye.trianglebadge.exclamationmark").font(.system(size: 28)).foregroundStyle(.white)
                Text("Bulanıklaştırıldı").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text("Tercihin 'bulanıklaştır' olduğu için görüntü bulanık; video sürüyor.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
                HStack(spacing: GTokens.s3) {
                    actionButton("Göster", "eye") { Task { await model.showAnyway() } }
                    actionButton("Neden?", "questionmark.circle") { showWhy = true }
                }
            }
            .padding(GTokens.s4)
        }
        .onAppear { model.markWarningPresented() }
    }

    // C1 — MUTE: the image plays; a visible muted indicator shows WHY the audio is off. Honest: audio is really muted.
    private var mutedIndicator: some View {
        VStack {
            HStack(spacing: GTokens.s2) {
                Image(systemName: "speaker.slash.fill").foregroundStyle(.white)
                Text("Ses kapatıldı (kişisel tercih)").font(.caption.weight(.medium)).foregroundStyle(.white)
                Button("Aç") { Task { await model.showAnyway() } }.font(.caption.weight(.bold)).foregroundStyle(.yellow)
            }
            .padding(.horizontal, GTokens.s3).padding(.vertical, GTokens.s2)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(.top, GTokens.s3)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { model.markWarningPresented() }
    }

    // C1 — WARN: content plays with a visible warning banner carrying the real reason. No hide claim.
    private var warnBanner: some View {
        VStack {
            HStack(spacing: GTokens.s2) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Uyarı").font(.caption.weight(.bold)).foregroundStyle(.white)
                    if let d = model.currentDecision {
                        Text(d.reason.turkishExplanation).font(.caption2).foregroundStyle(.white.opacity(0.9))
                            .lineLimit(2)
                    }
                }
                Spacer()
                Button("Neden?") { showWhy = true }.font(.caption2.weight(.bold)).foregroundStyle(.white)
            }
            .padding(GTokens.s3).background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
            .padding(GTokens.s3)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { model.markWarningPresented() }
    }

    private func actionButton(_ title: String, _ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, GTokens.s3).frame(minHeight: GTokens.minTouch)
        }
        .buttonStyle(.borderedProminent).tint(.white.opacity(0.18)).foregroundStyle(.white)
    }

    // MARK: Transport controls (always available; honest about state)

    private var controls: some View {
        HStack(spacing: GTokens.s3) {
            Button { Task { await model.move(by: -1) } } label: { Image(systemName: "chevron.left") }
                .frame(minWidth: GTokens.minTouch, minHeight: GTokens.minTouch)
                .disabled(model.currentIndex == 0)
            Text(stateLabel).font(.caption.weight(.medium)).foregroundStyle(stateColor)
                .frame(maxWidth: .infinity)
            Button { Task { await model.skip() } } label: { Label("Atla", systemImage: "forward.end") }
                .frame(minHeight: GTokens.minTouch).buttonStyle(.bordered)
        }
    }

    private var provenanceFooter: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let d = model.currentDecision {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.magnifyingglass").font(.caption2)
                    Text(provenanceText(d.provenance)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 4) {
                Image(systemName: model.sharedContainerActive ? "externaldrive.badge.checkmark" : "externaldrive.badge.exclamationmark")
                    .foregroundStyle(model.sharedContainerActive ? .green : .orange).font(.caption2)
                Text("Politika sürümü: \(model.policyRevision)").font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // FIX — surface the REAL controlled-player timeline (what OUR player actually did this session). Privacy-safe:
    // category + status + time only (no titles, no OCR, no frames). Previously computed but never shown in the UI.
    @ViewBuilder private var timelineDisclosure: some View {
        if !model.timelineEvents.isEmpty {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: GTokens.s2) {
                    ForEach(model.timelineEvents.reversed()) { ev in
                        HStack(spacing: GTokens.s2) {
                            Circle().fill(timelineColor(ev.status)).frame(width: 8, height: 8)
                            Text(timelineCategory(ev.category)).font(.caption)
                            Spacer()
                            Text(timelineTime(ev.epochSeconds)).font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Yalnızca bu oturum. Ham ekran/metin saklanmaz.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(.top, GTokens.s2)
            } label: {
                Label("Bu Oturum · \(model.timelineEvents.count) olay", systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func timelineCategory(_ c: GuardianTimelineCategoryV1) -> String {
        switch c {
        case .sessionStarted:         return "Oturum başladı"
        case .sessionEnded:           return "Oturum bitti"
        case .newContent:             return "Yeni içerik algılandı"
        case .identityResolved:       return "Kimlik çözüldü"
        case .evidenceCaptured:       return "Kanıt elde edildi"
        case .decision:               return "Guardian kararı"
        case .contentChanged:         return "İçerik değişti"
        case .observationGap:         return "Gözlem kesildi"
        case .observationResumed:     return "Gözlem yeniden başladı"
        case .personalShieldMatched:  return "Kişisel kalkan eşleşti"
        case .preferenceApplied:      return "Tercihin uygulandı"
        // 1G/2.3 — honest warn presentation stages (controlled player reaches PRESENTED on a real onAppear).
        case .matchDetected:          return "Eşleşme saptandı"
        case .actionSelected:         return "Eylem seçildi"
        case .warningReady:           return "Uyarı hazırlandı"
        case .warningDeliveryRequested: return "Uyarının iletilmesi istendi"
        case .warningDelivered:       return "Uyarı iletildi"
        case .warningPresented:       return "Uyarı ekranda gösterildi"
        case .presentationUnverified: return "Sunum doğrulanamadı"
        case .warningShown:           return "Uyarı gösterildi"   // deprecated; only old decoded snapshots reach here
        }
    }
    private func timelineColor(_ s: GuardianTimelineStatusV1) -> Color {
        switch s {
        case .active, .benign: return .green
        case .caution:         return .orange
        case .shieldMatch:     return .red
        case .unknown, .ended: return .secondary
        }
    }
    private func timelineTime(_ epoch: Double) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        return f.string(from: Date(timeIntervalSince1970: epoch))
    }

    private var whySheet: some View {
        VStack(alignment: .leading, spacing: GTokens.s4) {
            Text("Neden gizlendi?").font(.headline)
            if let d = model.currentDecision {
                Text(d.reason.turkishExplanation).font(.callout)
                Divider()
                detailRow("Kanıt kaynağı", provenanceText(d.provenance))
                if let rule = d.matchedRuleID { detailRow("Eşleşen kural", rule) }
                detailRow("Yüzey", "Kendi oynatıcımız (kontrollü) — gizleme gerçekten uygulanabilir")
                detailRow("Politika sürümü", "\(d.policyRevision)")
                Text("0–100 arası bir puan vermiyoruz; karar kanıt ve senin kuralına dayanır.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(GTokens.s6)
        .presentationDetents([.medium])
    }

    private func detailRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) { Text(k).foregroundStyle(.secondary); Spacer(); Text(v).multilineTextAlignment(.trailing) }
            .font(.caption)
    }

    private func provenanceText(_ p: ReelsEvidenceProvenanceV1) -> String {
        switch p {
        case .realOCR: return "Gerçek ekran metni (Apple Vision OCR, cihazda)"
        case .userSuppliedMetadata: return "İçeriğin bildirdiği başlık/metadata (görüntü anlama değil)"
        case .none: return "Kanıt elde edilemedi (bilinmiyor)"
        }
    }

    private var stateLabel: String {
        switch model.currentState {
        case .playing: return "Oynatılıyor"
        case .userOverridden: return "Senin isteğinle gösteriliyor"
        case .hidden: return model.coverEngaged ? "Gizlendi" : "Gizleniyor…"
        case .blurred: return "Bulanıklaştırıldı"
        case .muted: return "Ses kapatıldı"
        case .warned: return "Uyarı gösterildi"
        case .askUser: return "Onayın bekleniyor"
        case .evaluating, .pendingEvaluation: return "Değerlendiriliyor…"
        case .undetermined: return "Belirsiz — kararı sana bıraktık"
        case .skipped: return "Atlandı"
        }
    }
    private var stateColor: Color {
        switch model.currentState {
        case .playing, .userOverridden: return GuardianSurfaceState.Tone.aligned.color
        case .hidden: return GuardianSurfaceState.Tone.strongCaution.color
        case .blurred, .muted, .warned: return GuardianSurfaceState.Tone.caution.color
        case .undetermined, .askUser: return GuardianSurfaceState.Tone.unknown.color
        default: return GuardianSurfaceState.Tone.neutral.color
        }
    }
}

// MARK: - E3 "Video Kanıtı" — the Temporal Evidence Map sheet
//
// The centerpiece BUILD surface. It shows, on a timeline strip scaled to the examined span:
//   • EXAMINED timepoints as dots (we really decoded + OCR'd a frame there),
//   • MATCHED points as highlighted dots carrying the ACTUAL matched rule id (per-sample attribution, E1),
//   • the gaps between examined points labelled explicitly NEUTRAL "incelenmedi" — we never paint a colored danger
//     zone where we have NO evidence (mandate E3), and we never claim the whole video was examined (D honesty).
// Session-scoped, local, lightweight. Raw OCR text is NOT shown by default (privacy): we show the matched RULE and
// the outcome per point, not the recognized screen text.
struct VideoEvidenceMapSheet: View {
    let decision: ReelDecisionV1
    @State private var showRawText = false   // raw OCR hidden by default; opt-in per session only

    // §G — the two SEPARATE evidence layers. Görüntü = visual OCR timepoints; Ses = real audio-classifier events. We
    // never fuse them: each row cites which sense produced it, so the UI can't imply one sense supports the other's claim.
    private var visualRecords: [ReelsTimedEvidenceV1] {
        decision.timedEvidence.filter { $0.modality == .visualOCR }.sorted { $0.timestampSeconds < $1.timestampSeconds }
    }
    private var audioRecords: [ReelsTimedEvidenceV1] {
        decision.timedEvidence.filter { $0.modality == .audioEvent }.sorted { $0.timestampSeconds < $1.timestampSeconds }
    }
    private var records: [ReelsTimedEvidenceV1] { visualRecords }
    private var span: ClosedRange<Double> {
        let ts = records.map { $0.timestampSeconds }
        let lo = ts.min() ?? 0, hi = ts.max() ?? 1
        return lo...(hi > lo ? hi : lo + 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GTokens.s4) {
                header
                // §G — GÖRÜNTÜ (visual) layer.
                Text("Görüntü").font(.headline)
                strip
                legend
                Divider()
                pointList
                Divider()
                // §G — SES (audio) layer: real classified events / honest UNAVAILABLE when no audio analysis ran.
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
            Text("Bu içerikte hangi zaman noktalarını inceledik (görüntü), hangi ses olaylarını duyduk (ses), nerede eşleşme bulduk.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // §G — the SES (audio) layer. Shows the REAL classifier events (Apple Sound Analysis) with the matched rule where
    // one applies, their raw-confidence + time range when the framework supplied one. When no audio analysis exists for
    // this decision (vision-only / no audio track / deferred) we show an HONEST UNAVAILABLE row — never a blank "clean".
    @ViewBuilder private var audioLayer: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Text("Ses").font(.headline)
            if audioRecords.isEmpty {
                Text("Ses analizi bu içerik için kullanılamadı veya ses olayı bulunamadı — bu 'sessiz/güvenli' demek DEĞİLDİR.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(audioRecords.indices, id: \.self) { i in
                    let rec = audioRecords[i]
                    HStack(alignment: .top, spacing: GTokens.s2) {
                        Image(systemName: rec.matchedAtThisSample ? "waveform.badge.exclamationmark" : "waveform")
                            .foregroundStyle(rec.matchedAtThisSample ? .red : .secondary).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 1) {
                            // the classifier LABEL is the audio analogue of OCR text (NOT raw audio / NOT a transcript).
                            Text(rec.timestampSeconds >= 0
                                 ? String(format: "%.1fs — %@", rec.timestampSeconds, rec.text)
                                 : "\(rec.text) (zaman aralığı modelce verilmedi)")
                                .font(.caption.weight(.medium))
                            if let rule = rec.matchedRuleID {
                                Text("Eşleşen ses tercihi: \(rule)").font(.caption2).foregroundStyle(.red)
                            }
                        }
                        Spacer()
                    }
                }
                Text("Kanıt: Apple Sound Analysis · Ses. Ham güven skoru Guardian risk puanı DEĞİLDİR; ham ses saklanmaz.")
                    .font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // The timeline strip: examined points as dots on a neutral baseline. The baseline is explicitly "incelenmedi"
    // between points — no colored danger fill without evidence.
    private var strip: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.18)).frame(height: 6)   // neutral baseline = unexamined
                ForEach(records.indices, id: \.self) { i in
                    let rec = records[i]
                    let x = position(rec.timestampSeconds, width: w)
                    Circle()
                        .fill(dotColor(rec))
                        .frame(width: rec.matchedAtThisSample ? 16 : 10, height: rec.matchedAtThisSample ? 16 : 10)
                        .overlay(rec.matchedAtThisSample ? Circle().strokeBorder(.white, lineWidth: 2) : nil)
                        .position(x: min(max(x, 8), w - 8), y: 15)
                }
            }
            .frame(height: 30)
        }
        .frame(height: 34)
    }

    private var legend: some View {
        HStack(spacing: GTokens.s4) {
            legendItem(.green, "İncelendi")
            legendItem(.red, "Eşleşme")
            legendItem(.secondary.opacity(0.5), "İncelenmedi (boşluk)")
        }
        .font(.caption2)
    }
    private func legendItem(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) { Circle().fill(c).frame(width: 8, height: 8); Text(t).foregroundStyle(.secondary) }
    }

    private var pointList: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            ForEach(records.indices, id: \.self) { i in
                let rec = records[i]
                HStack(alignment: .top, spacing: GTokens.s2) {
                    Circle().fill(dotColor(rec)).frame(width: 8, height: 8).padding(.top, 4)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "%.1fs — %@", rec.timestampSeconds, outcomeLabel(rec)))
                            .font(.caption.weight(.medium))
                        if let rule = rec.matchedRuleID {
                            Text("Eşleşen kural: \(rule)").font(.caption2).foregroundStyle(.red)
                        }
                        if showRawText, rec.ocrStatus == .ran, !rec.text.isEmpty {
                            Text(rec.text).font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
                        }
                    }
                    Spacer()
                }
            }
            // §C5 — HONEST prefetched-item note. When the decision came from a prefetched (pre-exposure) evaluation its
            // raw OCR text was STRIPPED after the verdict (privacy: we keep only matched rule ids + timestamps + counts).
            // So for a prefetched item the Video Kanıtı shows sample dots + the matched rule, but NOT the raw text —
            // and we say so plainly rather than showing an empty field as if nothing was read.
            if rawTextWasStripped {
                Text("Bu karar önceden (sıradaki için) üretildi; ham ekran metni karardan sonra silindi — yalnızca eşleşen kural, zaman noktaları ve sayımlar tutuldu.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                Toggle(isOn: $showRawText) {
                    Text("Ham ekran metnini göster (yalnızca bu oturum)").font(.caption2)
                }
                .toggleStyle(.switch)
            }
        }
    }

    /// §C5 — true when at least one sample's OCR RAN but carries no text (the prefetch sanitizer stripped it). Lets us
    /// show the honest "text unavailable (prefetched)" note instead of a useless empty raw-text field.
    private var rawTextWasStripped: Bool {
        records.contains { $0.ocrStatus == .ran && $0.text.isEmpty }
    }

    private var footerHonesty: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Yalnızca \(records.count) zaman noktası incelendi — tüm video değil. Aradaki boşluklarda kısa bir olay kaçmış olabilir.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            // §B2 — SEPARATED, honest coverage accounting. Each number is a distinct fact; an early-stopped plan is
            // never dressed up as a full pass. Only shown when the provider produced real counters (planned > 0).
            if decision.coverageCounters.plannedSampleCount > 0 {
                let c = decision.coverageCounters
                Text("Örnekleme: planlanan \(c.plannedSampleCount) · denenen \(c.attemptedSampleCount) · çözülen \(c.decodedSampleCount) · OCR \(c.ocrExecutedCount)")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if c.earlyStopped {
                    Text(earlyStopCopy(c.earlyStopReason, attempted: c.attemptedSampleCount, planned: c.plannedSampleCount))
                        .font(.caption2).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
            }
            if decision.temporalCoverageLimited {
                Text("Zamansal kapsam sınırlı: örneklenen noktalar temizse bu 'videonun tamamı güvenli' demek değildir.")
                    .font(.caption2).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            Text("0–100 arası puan yok; karar kanıta ve kuralına dayanır.").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    // §B2 — honest early-stop copy: we say WHY we stopped before finishing the plan, never implying full coverage.
    private func earlyStopCopy(_ r: ReelsEarlyStopReasonV1, attempted: Int, planned: Int) -> String {
        switch r {
        case .verifiedMatch: return "Eşleşme doğrulandığı için \(attempted)/\(planned) noktada durduk — geri kalanı incelemek gereksizdi."
        case .cancelled:     return "İçerik değiştiği için erken durduk (\(attempted)/\(planned)). Bu sonuç bitmemiş olabilir."
        case .budgetThermal: return "Bütçe/termal baskı nedeniyle \(attempted)/\(planned) noktada durduk — kapsam daha sınırlı."
        case .none:          return ""
        }
    }

    private func position(_ t: Double, width: Double) -> Double {
        let lo = span.lowerBound, hi = span.upperBound
        guard hi > lo else { return width / 2 }
        return (t - lo) / (hi - lo) * width
    }
    private func dotColor(_ rec: ReelsTimedEvidenceV1) -> Color {
        if rec.matchedAtThisSample { return .red }
        switch rec.ocrStatus {
        case .ran, .ranNoText: return .green     // examined
        case .notDecoded:      return .secondary // could not decode here (counts against coverage, neutral)
        }
    }
    private func outcomeLabel(_ rec: ReelsTimedEvidenceV1) -> String {
        if rec.matchedAtThisSample { return "eşleşme bulundu" }
        switch rec.ocrStatus {
        case .ran:       return "incelendi (metin okundu)"
        case .ranNoText: return "incelendi (okunur metin yok)"
        case .notDecoded:return "çözülemedi"
        }
    }
}

#if canImport(UIKit)
import UIKit

/// C1 — a REAL Gaussian/material blur over the live player layer (BLUR_IF_CONTROLLED). The AVPlayerLayer keeps
/// rendering underneath (frames continue), and this UIVisualEffectView obscures them — a genuine on-surface blur, not
/// an opaque cover. Audio policy is unchanged (blur is a visual-only action; the model leaves audio playing).
struct BlurOverlayView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

/// A bare AVPlayerLayer host — WE own exactly what renders, so a HIDE cover is a true full-surface occlusion (no
/// AVPlayerViewController chrome or residual frame can leak around it). The layer is detached when the model
/// removes the player item (engageHide → replaceCurrentItem(nil)), so there is literally nothing to draw.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> PlayerContainerView {
        let v = PlayerContainerView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspect
        v.backgroundColor = .black
        return v
    }
    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
#endif
