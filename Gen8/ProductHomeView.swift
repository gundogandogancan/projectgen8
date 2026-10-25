//
//  ProductHomeView.swift — §4: the ONE-SCREEN PRODUCT SHELL.
//
//  WHY THIS EXISTS (mandate §4): a normal user must launch into ONE simple surface — not the engineering harness.
//  This is NOT a rewrite: it composes the EXISTING models (GuardianLabModel, ShieldStudioModel, LocalLearningModel)
//  into the product surface the mandate lists:
//    1. GEN8 symbol + real Guardian status (from the truth projection — never a fabricated "protected").
//    2. Real start/stop (the OS broadcast picker — the only lawful way to start a ReplayKit broadcast).
//    3. Personal shield entry (words/phrases/topics — reuses MyShieldView).
//    4. Photo reference add (P1-5 — PersonalPhotoShieldView).
//    5. Family/parental profile entry point.
//    6. Subscription + profile (honest "yakında" — NO fake subscription backend, rule 1/21).
//    7. Privacy controls (analysis consent etc.).
//    8. "Neden? / Son analiz" access.
//
//  ALL lab screens (Controlled Reels, Long-Form, harnesses, Benchmarks, Learning debug) live behind the Developer
//  Lab entry (GuardianLabView), reachable ONLY from Settings — they do NOT occupy normal user navigation. No lab
//  code is deleted.
//
import SwiftUI
import GuardianCore

struct ProductHomeView: View {
    @Bindable var model: GuardianLabModel
    @Bindable var shield: ShieldStudioModel
    @Bindable var learning: LocalLearningModel
    @Environment(AppSettings.self) private var settings

    /// Entry to the full engineering harness. Set from Settings (not from normal navigation).
    @Binding var showDeveloperLab: Bool

    @State private var showShield = false
    @State private var showPhotoShield = false
    @State private var showFamily = false
    @State private var showSubscription = false
    @State private var showPrivacy = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: GTokens.s4) {
                    header

                    // 1 — REAL Guardian status (truth projection). The single always-on product surface.
                    LiveGuardianInsightView(model: model)

                    // 2 — real start/stop. The in-app toggle expresses INTENT; the OS broadcast picker actually
                    // starts/stops the cross-app capture (ReplayKit). Both shown honestly, never conflated.
                    startStopCard

                    // 3–8 — the product entry points. Each is a simple row; heavy surfaces open as sheets.
                    VStack(spacing: GTokens.s2) {
                        entryRow("Kişisel kalkan", "Kelime, cümle, konu", systemImage: "shield.lefthalf.filled") { showShield = true }
                        entryRow("Fotoğraf referansı", "Bir görseli kalkana ekle", systemImage: "photo.badge.plus") { showPhotoShield = true }
                        entryRow("Aile / ebeveyn", "Çocuk ve aile koruması", systemImage: "figure.2.and.child.holdinghands") { showFamily = true }
                        entryRow("Abonelik ve profil", "Hesap ve plan", systemImage: "person.crop.circle") { showSubscription = true }
                        entryRow("Gizlilik", "Analiz izni ve veriler", systemImage: "hand.raised") { showPrivacy = true }
                    }
                    .padding(.horizontal, GTokens.s4)
                }
                .padding(.top, GTokens.s2)
                .padding(.bottom, GTokens.s6)
            }
            .navigationTitle("GEN8")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(Text("Ayarlar"))
                }
            }
            .sheet(isPresented: $showShield) {
                NavigationStack { MyShieldView(model: shield).navigationTitle("Kişisel kalkan") }
            }
            .sheet(isPresented: $showPhotoShield) {
                NavigationStack { PersonalPhotoShieldView(shield: shield).navigationTitle("Fotoğraf referansı") }
            }
            .sheet(isPresented: $showFamily) { familySheet }
            .sheet(isPresented: $showSubscription) { subscriptionSheet }
            .sheet(isPresented: $showPrivacy) { privacySheet }
            .sheet(isPresented: $showSettings) { settingsSheet }
        }
    }

    // 1 — GEN8 symbol + a one-line honest status. The symbol reflects the truth projection's surface (gray/unknown
    // when not genuinely protecting — never a fabricated green).
    private var header: some View {
        VStack(spacing: GTokens.s2) {
            Image(systemName: headerSymbol)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(model.realityProjection.activeProtection ? Color.green : Color.secondary)
                .accessibilityHidden(true)
            Text("GEN8").font(.largeTitle.weight(.bold))
            Text(model.realityProjection.activeProtection ? "Koruma aktif (analizde)" : "Hazır — gözlem için yayını başlatın")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, GTokens.s2)
    }

    private var headerSymbol: String {
        model.guardianEnabled ? "shield.lefthalf.filled" : "shield.slash"
    }

    // 2 — the real start/stop surface.
    private var startStopCard: some View {
        VStack(alignment: .leading, spacing: GTokens.s3) {
            HStack {
                Toggle("Guardian", isOn: $model.guardianEnabled)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHint(Text("Guardian çalışma zamanını açar/kapatır. Kapalı asla 'korunuyor' demez."))
            }
            #if os(iOS)
            // The OS broadcast picker — the ONLY lawful way to start/stop a cross-app ReplayKit broadcast.
            CrossAppObservationView()
            #endif
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
        .padding(.horizontal, GTokens.s4)
    }

    private func entryRow(_ title: String, _ subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: GTokens.s3) {
                Image(systemName: systemImage).font(.title3).frame(width: 32)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.body.weight(.medium)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(GTokens.s3)
            .frame(minHeight: GTokens.minTouch)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
        }
        .buttonStyle(.plain)
    }

    // 5 — Family / parental entry. The engine's Child/Family policy precedence is canonical and UNCHANGED (§7); this
    // is the product entry point. Deep parental management integration is reported NOT_DONE honestly (P2 scope).
    private var familySheet: some View {
        NavigationStack {
            Form {
                Section("Aile ve çocuk koruması") {
                    Text("Çocuk güvenliği eşiği yetişkin tercihinin ÜSTÜNDEDİR ve kanonik öncelik sırası değişmez.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Label("Ebeveyn profili yönetimi", systemImage: "person.badge.key")
                    Text("Tam ebeveyn yönetimi akışı yakında. Mevcut sürümde çocuk/aile güvenlik eşikleri motor tarafında korunur; bu ekrandan yönetim henüz bağlanmadı.")
                        .font(.caption2).foregroundStyle(.tertiary)
                } footer: {
                    Text("Bu özellik DURUM: yakında (gerçek bağlanmadı — sahte akış gösterilmez).")
                }
            }
            .navigationTitle("Aile / ebeveyn")
        }
        .presentationDetents([.medium])
    }

    // 6 — Subscription + profile. HONEST placeholder: there is NO real billing backend, so we never show a fake
    // subscription (rule 21: scores/plans can't be faked). "yakında" only.
    private var subscriptionSheet: some View {
        NavigationStack {
            Form {
                Section("Abonelik") {
                    Text("Gerçek bir ödeme/abonelik altyapısı henüz bağlı değil.")
                        .font(.caption).foregroundStyle(.secondary)
                    Label("Planlar — yakında", systemImage: "creditcard")
                        .foregroundStyle(.secondary)
                }
                Section {
                    Label("Hesap — yakında", systemImage: "person.crop.circle")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Profil")
                } footer: {
                    Text("DURUM: yakında. Sahte abonelik veya hesap durumu gösterilmez.")
                }
            }
            .navigationTitle("Abonelik ve profil")
        }
        .presentationDetents([.medium])
    }

    // 7 — Privacy controls. The analysis consent gate is the real fail-closed control; raw screen content is never
    // retained by default (rule 17). Learning data stays device-local (no automatic path to a global pool).
    private var privacySheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Guardian KAPALI iken ağır analiz hiç çalışmaz (fail-closed). Ham ekran içeriği varsayılan olarak saklanmaz.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Öğrenme verisi") {
                    Toggle("Cihaz-içi öğrenme", isOn: Binding(
                        get: { learning.learningEnabled },
                        set: { learning.setLearningEnabled($0) }))
                    Text("Öğrenme verisi bu cihazda kalır; küresel bir havuza otomatik yol yoktur.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                Section {
                    Button(role: .destructive) { shield.deleteAll() } label: {
                        Label("Tüm kalkan kurallarını sil", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Gizlilik")
        }
        .presentationDetents([.large])
    }

    // Settings — also the ONLY entry to the Developer Lab (not in normal navigation).
    private var settingsSheet: some View {
        @Bindable var s = settings
        return NavigationStack {
            Form {
                Section("Dil") {
                    Picker("Dil", selection: $s.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Section {
                    Toggle("Developer Mode", isOn: $s.developerMode)
                } footer: {
                    Text("Geliştirici seçenekleri normal kullanımda gizlidir.")
                }
                if s.developerMode {
                    Section {
                        Button {
                            showSettings = false
                            showDeveloperLab = true
                        } label: {
                            Label("Developer Lab'ı aç", systemImage: "hammer")
                        }
                    } footer: {
                        Text("Kontrollü Reels, Uzun Video, harness'ler, benchmark ve öğrenme hata ayıklama buradadır — normal kullanıcı navigasyonunda yer almaz.")
                    }
                }
            }
            .navigationTitle("Ayarlar")
        }
        .presentationDetents([.medium, .large])
    }
}
