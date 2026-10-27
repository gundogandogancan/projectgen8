//
//  RecognitionMemoryView.swift — R11-B §5: "İçerik Hafızası" (Content Memory — under your control).
//
//  The user-facing surface for the on-device Content Evidence Memory (Recognize & Recall V1). It explains honestly
//  WHAT is remembered (only DERIVED recognition signatures + prior evidence — never raw video/ses/metin), lets the
//  user turn the memory ON/OFF, see the record-type counts, choose the retention window, and clear all memory. The
//  copy is honest: recognition reuses only VALID prior EVIDENCE re-adjudicated under the CURRENT policy — it never
//  republishes an old decision, and partial history is never full-video knowledge (mandate §1/§3.1/§4).
//
import SwiftUI

struct RecognitionMemoryView: View {
    @Bindable var model: RecognitionMemoryModel

    private let retentionChoices = [7, 14, 30, 90]

    var body: some View {
        VStack(alignment: .leading, spacing: GTokens.s3) {
            if !model.consentShown { consentCard }
            toggleCard
            explanationCard
            visibilityCard
            retentionCard
            clearCard
            privacyCard
        }
        .padding(.horizontal, GTokens.s4)
        .onAppear { model.refresh() }
    }

    private var consentCard: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Text("İçerik hafızası nedir?").font(.headline)
            Text("GEN8, daha önce analiz ettiği içeriği tekrar gördüğünde tanıyabilmek için yalnızca TÜRETİLMİŞ parmak izlerini ve o içeriğe ait önceki kanıtı bu cihazda tutar. Ham video, ses, ekran görüntüsü veya metin saklanmaz. Tanınan içerik için önceki kanıt, güncel politikayla yeniden değerlendirilir; eski karar aynen tekrarlanmaz.")
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
            Toggle(isOn: Binding(get: { model.enabled }, set: { model.setEnabled($0) })) {
                Text("İçerik hafızası").font(.subheadline.weight(.semibold))
            }
            Text(model.enabled
                 ? "Açık (yalnızca bu cihazda): tanınan içerik için önceki kanıt, güncel politikayla yeniden değerlendirilir."
                 : "Kapalı: hiçbir tanıma kaydı tutulmaz; her içerik sıfırdan analiz edilir.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Text("Dürüst sınır").font(.subheadline.weight(.semibold))
            Text("Kısmen analiz edilen içerik, videonun tamamının bilindiği anlamına gelmez. Yalnızca gerçekten analiz edilen bölüm bilinir (ör. ilk 4 sn analiz edildiyse kapsam 4 sn'dir). Görülmemiş gelecek bölüm gizlice izlenmez.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
    }

    private var visibilityCard: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Text("Saklanan kayıtlar").font(.subheadline.weight(.semibold))
            Text("Toplam kayıt: \(model.recordCount)").font(.caption)
            if model.modalityCounts.isEmpty {
                Text("Henüz tanıma kaydı yok.").font(.caption2).foregroundStyle(.secondary)
            } else {
                ForEach(model.modalityCounts.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                    Text("• \(k): \(v) kayıt").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
    }

    private var retentionCard: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Text("Saklama süresi").font(.subheadline.weight(.semibold))
            Picker("Saklama süresi", selection: Binding(get: { model.retentionDays }, set: { model.setRetentionDays($0) })) {
                ForEach(retentionChoices, id: \.self) { d in Text("\(d) gün").tag(d) }
            }
            .pickerStyle(.segmented)
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
    }

    private var clearCard: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Button(role: .destructive) { model.clearAll() } label: {
                Text("Tüm içerik hafızasını temizle")
            }
            .frame(minHeight: GTokens.minTouch)
            Text("Tüm tanıma kayıtlarını siler. Ayarların korunur.").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Text("Gizlilik durumu").font(.subheadline.weight(.semibold))
            Text("Dosya koruması: \(model.fileProtectionComplete ? "tam (cihaz kilitliyken şifreli)" : "bu platformda uygulanmıyor")")
                .font(.caption2).foregroundStyle(.secondary)
            Text("Yedeklemeden hariç: \(model.excludedFromBackup ? "evet" : "hayır")")
                .font(.caption2).foregroundStyle(.secondary)
            Text("Hafıza yalnızca bu cihazda; hiçbir yere yüklenmez.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
    }
}
