//
//  GuardianLearningView.swift — §4: "Guardian'ım Nasıl Öğreniyor?" (How Guardian Learns — under your control).
//
//  The user-facing surface for Personal Learning V1. It explains WHAT is used, lets the user turn local learning
//  ON/OFF, shows PENDING proposals with accept/reject, UNDO the last accepted change, reset the learning history,
//  and (separately) reset the shield rules. First-run shows the scope explanation. Honest copy: no "KVKK zero"
//  claim; the clear statement that GEN8 learns ONLY from permitted explicit feedback, ONLY on this device, and
//  NEVER changes rules without the user's approval (mandate §4).
//
import SwiftUI
import GuardianCore

struct GuardianLearningView: View {
    @Bindable var model: LocalLearningModel
    /// §4 — resetting the SHIELD rules is a SEPARATE control from resetting learning history. We take the shield
    /// model so the "kalkan kurallarını ayrıca sıfırla" button is on this screen but clearly distinct.
    @Bindable var shield: ShieldStudioModel
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: GTokens.s3) {
            if !model.consentShown { consentCard }
            toggleCard
            explanationCard
            proposalsCard
            undoResetCard
            privacyCard
        }
        .padding(.horizontal, GTokens.s4)
        .onAppear { model.refresh() }
    }

    // §4 — first-use scope explanation (shown once; acknowledging also opts in to the explanation, not to learning).
    private var consentCard: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Text("GEN8 nasıl öğrenir?").font(.headline)
            Text("GEN8, izin verdiğin geri bildirimlerden yalnızca bu cihazda kişisel öneriler oluşturur. Sen onaylamadıkça kurallarını değiştirmez.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Anladım") { model.markConsentShown() }
                .frame(minHeight: GTokens.minTouch).buttonStyle(.borderedProminent)
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
    }

    private var toggleCard: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Toggle(isOn: Binding(get: { model.learningEnabled }, set: { model.setLearningEnabled($0) })) {
                Text("Yerel öğrenme").font(.subheadline.weight(.semibold))
            }
            Text(model.learningEnabled
                 ? "Açık: yalnızca açık geri bildirimlerinden, bu cihazda öneri üretilir."
                 : "Kapalı: davranışından hiçbir kalıcı öğrenme kaydı oluşmaz; kuralların normal çalışır.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: GTokens.s1) {
            Text("Hangi etkileşimler kullanılır?").font(.subheadline.weight(.semibold))
            Label("İçeriğe özel 'Yine de göster'", systemImage: "eye")
            Label("'Bunun gibi daha az göster' / 'Bu uyarı yardımcı olmadı'", systemImage: "hand.thumbsdown")
            Label("ASK (sor) ekranındaki yanıtın", systemImage: "questionmark.circle")
            Text("Kaydırma, izleme süresi veya duraksamadan OTOMATİK çıkarım yapılmaz.")
                .font(.caption2).foregroundStyle(.secondary).padding(.top, 2)
        }
        .font(.footnote)
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
    }

    private var proposalsCard: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Text("Bekleyen öneriler (\(model.pending.count))").font(.subheadline.weight(.semibold))
            if model.pending.isEmpty {
                Text("Şu an güvenilir bir öneri yok. Yeterli, tutarlı ve bağımsız geri bildirim birikmeden öneri üretilmez.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(model.pending, id: \.proposalID) { p in proposalRow(p) }
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
    }

    @ViewBuilder private func proposalRow(_ p: LearningProposalV1) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(p.reason).font(.footnote)
            Text("\(p.currentAction.rawValue) → \(p.proposedAction.rawValue) · kural: \(p.ruleID)")
                .font(.caption2.monospaced()).foregroundStyle(.secondary)
            HStack {
                Button("Kabul et") { model.accept(p.proposalID) }
                    .buttonStyle(.borderedProminent).frame(minHeight: GTokens.minTouch)
                Button("Reddet") { model.reject(p.proposalID) }
                    .buttonStyle(.bordered).frame(minHeight: GTokens.minTouch)
            }
        }
        .padding(.vertical, 4)
    }

    private var undoResetCard: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            if model.undoableProposalID != nil {
                Button { _ = model.undoLast() } label: {
                    Label("Son değişikliği geri al", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity, minHeight: GTokens.minTouch)
                }.buttonStyle(.bordered)
            }
            Button(role: .destructive) { model.resetLearningHistory() } label: {
                Label("Öğrenme geçmişini sıfırla", systemImage: "trash")
                    .frame(maxWidth: .infinity, minHeight: GTokens.minTouch)
            }.buttonStyle(.bordered)
            Text("Öğrenme geçmişini sıfırlamak mevcut kalkan kurallarını SİLMEZ.")
                .font(.caption2).foregroundStyle(.secondary)
            Button(role: .destructive) { shield.deleteAll() } label: {
                Label("Kalkan kurallarını ayrıca sıfırla", systemImage: "shield.slash")
                    .frame(maxWidth: .infinity, minHeight: GTokens.minTouch)
            }.buttonStyle(.bordered)
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
    }

    private var privacyCard: some View {
        let f = model.privacyFacts
        return VStack(alignment: .leading, spacing: GTokens.s1) {
            Text("Gizlilik").font(.subheadline.weight(.semibold))
            Text("Öğrenme verisi bu cihazda kalır; küresel bir havuza otomatik yol yoktur. 'Cihazda = KVKK sıfır' iddiası yapılmaz.")
                .font(.caption2).foregroundStyle(.secondary)
            if settings.developerMode {
                Text("fileProtection=\(f.fileProtection ? "complete" : "n/a") · excludedFromBackup=\(f.excludedFromBackup ? "yes" : "no") · öneri=\(f.proposalCount) · toplam=\(f.aggregateCount) · policyRev=\(model.policyRevision)")
                    .font(.caption2.monospaced()).foregroundStyle(.tertiary)
            }
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
    }
}
