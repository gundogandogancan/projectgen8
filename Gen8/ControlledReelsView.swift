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

    var body: some View {
        VStack(spacing: GTokens.s3) {
            header
            surface
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: GTokens.radius))
            controls
            provenanceFooter
        }
        .padding(.horizontal, GTokens.s4)
        .task { await model.start() }
        .onDisappear { model.stop() }
        .sheet(isPresented: $showWhy) { whySheet }
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
        case .evaluating, .pendingEvaluation: return "Değerlendiriliyor…"
        case .undetermined: return "Belirsiz — kararı sana bıraktık"
        case .skipped: return "Atlandı"
        }
    }
    private var stateColor: Color {
        switch model.currentState {
        case .playing, .userOverridden: return GuardianSurfaceState.Tone.aligned.color
        case .hidden: return GuardianSurfaceState.Tone.strongCaution.color
        case .undetermined: return GuardianSurfaceState.Tone.unknown.color
        default: return GuardianSurfaceState.Tone.neutral.color
        }
    }
}

#if canImport(UIKit)
import UIKit

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
