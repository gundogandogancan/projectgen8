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

    // 5 — Family / parental entry (R5 §2/§3 UX). The FIRST REAL profile create/edit flow: it writes the SHARED
    // family profile store the broadcast extension actually reads (revision bump → live decision invalidation).
    // The engine's Child/Family policy precedence is canonical and UNCHANGED (§7). Remote/account management is
    // explicitly NOT_AVAILABLE (never a promised capability we don't have).
    private var familySheet: some View {
        FamilyProfileSheetView()
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
    // (R5: the family sheet is FamilyProfileSheetView below — the real create/edit flow, no placeholder.)
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

// MARK: - R5 §2/§3 UX — the MINIMAL REAL family profile screen.
//
// Writes the SHARED FamilyProfileSharedStoreV1 the broadcast extension reads: Save/Delete bump the family revision,
// the extension re-reads on its ~1s gate, the current decision is invalidated and the current content re-evaluated
// under the new policy — live, no restart. HONESTY LAWS on-screen: the parent declaration is a DECLARATION ("beyan —
// kimlik doğrulaması değildir"); age is parent-ENTERED only (no estimation); preferences are STRICTER-ONLY; remote/
// account management is explicitly NOT_AVAILABLE; 3rd-party apps get WARN-only (we never claim to block their feeds).
struct FamilyProfileSheetView: View {
    private let store = FamilyProfileSharedStoreV1()

    @State private var loadedState: FamilyProfileStateV1 = .missing
    @State private var hasStoredProfile = false
    @State private var profileID = UUID().uuidString
    @State private var createdEpoch: Double = 0
    @State private var mode: FamilyPolicyModeV1 = .adult
    @State private var ageText = ""
    @State private var parentDeclaration = false
    @State private var jurisdiction = "TR"
    @State private var extraCautionFear = false
    @State private var extraCautionManipulation = false
    @State private var blockSensitiveNews = false
    @State private var statusLine: String? = nil

    /// ONLY the supported jurisdictions from the versioned frozen registry — nothing else is offered.
    private var supportedJurisdictions: [String] { JurisdictionAgeBandRegistryV1.supportedJurisdictions.sorted() }
    private var needsChildFields: Bool { mode != .adult }
    private var enteredAge: Int? { Int(ageText.trimmingCharacters(in: .whitespaces)) }
    private var ageValid: Bool {
        guard let a = enteredAge else { return false }
        return mode == .child ? (1...12).contains(a) : (13...17).contains(a)
    }
    private var canSave: Bool { mode == .adult || (ageValid && parentDeclaration) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Aile ve çocuk koruması") {
                    Text("Çocuk güvenliği eşiği yetişkin tercihinin ÜSTÜNDEDİR ve kanonik öncelik sırası değişmez. Yaş yalnızca ebeveyn tarafından girilir; yüz, fotoğraf veya davranıştan yaş tahmini YAPILMAZ.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Profil durumu") {
                    LabeledContent("Durum", value: stateLabel)
                    if let s = statusLine {
                        Text(s).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                Section("Politika modu") {
                    Picker("Mod", selection: $mode) {
                        ForEach(FamilyPolicyModeV1.allCases, id: \.self) { Text($0.turkishLabel).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if mode == .adult {
                        Text("Yetişkin modunda çocuk/ergen katmanı uygulanmaz; kişisel kalkan ve genel koruma aynen sürer.")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                if needsChildFields {
                    Section("Yaş (ebeveyn girişi)") {
                        TextField(mode == .child ? "Yaş (1–12)" : "Yaş (13–17)", text: $ageText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Toggle("Ebeveyn beyanı", isOn: $parentDeclaration)
                        Text("Beyan — kimlik doğrulaması değildir. Beyan olmadan çocuk kararı üretilmez (motor kendisi güvenli tarafta kalır).")
                            .font(.caption2).foregroundStyle(.tertiary)
                        if !ageText.isEmpty && !ageValid {
                            Text(mode == .child ? "Geçerli aralık: 1–12." : "Geçerli aralık: 13–17.")
                                .font(.caption2).foregroundStyle(.red)
                        }
                    }
                    Section("Bölge (yalnızca desteklenenler)") {
                        Picker("Bölge", selection: $jurisdiction) {
                            ForEach(supportedJurisdictions, id: \.self) { Text($0).tag($0) }
                        }
                        Text("Kayıt: \(JurisdictionAgeBandRegistryV1.version). Desteklenmeyen bölge motor tarafında güvenli tarafta (inceleme) kalır.")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    Section("Sıkılaştırıcı ebeveyn tercihleri") {
                        Toggle("Korku/tehdit işaretlerinde ekstra dikkat", isOn: $extraCautionFear)
                        Toggle("Manipülasyon işaretlerinde ekstra dikkat", isOn: $extraCautionManipulation)
                        Toggle("Hassas haber içeriğini kısıtla", isOn: $blockSensitiveNews)
                        Text("Tercihler korumayı yalnızca SIKILAŞTIRABİLİR; hiçbir tercih çocuk tabanını gevşetemez.")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                Section {
                    Button("Kaydet") { save() }
                        .disabled(!canSave)
                    if hasStoredProfile {
                        Button("Profili sil", role: .destructive) { deleteProfile() }
                    }
                } footer: {
                    Text(canSave ? "Kaydet: yayın sürüyorsa mevcut karar geçersiz kılınır ve içerik yeni politikayla yeniden değerlendirilir."
                                 : "Kaydetmek için geçerli bir yaş gir ve ebeveyn beyanını işaretle.")
                }
                Section("Uzaktan / hesap yönetimi") {
                    Label("Uzaktan ebeveyn yönetimi — NOT_AVAILABLE", systemImage: "icloud.slash")
                        .foregroundStyle(.secondary)
                    Text("Bu sürümde hesap/uzaktan yönetim ve üçüncü taraf uygulama engelleme YOKTUR. Üçüncü taraf uygulamalarda yalnızca UYARI verilebilir; başka bir uygulamanın akışını kontrol ettiğimiz iddia edilmez.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .navigationTitle("Aile / ebeveyn")
            .onAppear(perform: load)
        }
        .presentationDetents([.large])
    }

    private var stateLabel: String {
        switch loadedState {
        case .valid:       return "KAYITLI (geçerli)"
        case .missing:     return "PROFİL YOK"
        case .stale:       return "GÜNCEL DEĞİL (stale)"
        case .corrupt:     return "BOZUK KAYIT (kurtarıldı)"
        case .unsupported: return "DESTEKLENMEYEN BÖLGE"
        }
    }

    private func load() {
        let r = store.load()
        loadedState = r.state
        hasStoredProfile = r.profile != nil
        if let p = r.profile {
            profileID = p.profileID
            createdEpoch = p.createdEpoch
            mode = p.mode
            ageText = p.parentEnteredAgeYears.map(String.init) ?? ""
            parentDeclaration = p.parentDeclaration
            jurisdiction = p.jurisdictionCode
            extraCautionFear = p.extraCautionFearThreat
            extraCautionManipulation = p.extraCautionManipulation
            blockSensitiveNews = p.blockSensitiveNews
        }
        if r.state == .corrupt {
            statusLine = "Kayıtlı profil çözülemedi; boş profile kurtarıldı (gizlenmedi). Yeniden kaydet."
        } else if r.state == .stale {
            statusLine = "Paylaşılan sürüm sayacı okunan dosyadan ileride; profil güncel kabul edilmiyor."
        } else if !r.sharedContainerActive {
            statusLine = "App Group kapsayıcısı yok (DEGRADED): profil yalnız bu süreçte görünür; uzantı MISSING görür."
        } else {
            statusLine = nil
        }
    }

    private func save() {
        let now = Date().timeIntervalSince1970
        let profile = FamilyProfileV1(
            profileID: profileID, mode: mode,
            parentEnteredAgeYears: needsChildFields ? enteredAge : nil,
            parentDeclaration: needsChildFields ? parentDeclaration : false,
            jurisdictionCode: jurisdiction,
            extraCautionFearThreat: needsChildFields && extraCautionFear,
            extraCautionManipulation: needsChildFields && extraCautionManipulation,
            blockSensitiveNews: needsChildFields && blockSensitiveNews,
            createdEpoch: createdEpoch == 0 ? now : createdEpoch, modifiedEpoch: now)
        let message: String
        if let rev = store.save(profile) {
            message = "Kaydedildi (revizyon \(rev)). Yayın açıksa uzantı ~1 sn içinde yeni politikayı okur."
        } else {
            message = "KAYDEDİLEMEDİ — profil değişmedi (dürüst hata; sahte başarı gösterilmez)."
        }
        load()
        statusLine = message
    }

    private func deleteProfile() {
        let message: String
        if store.delete() {
            message = "Profil silindi. Uzantı varsayılan (yetişkin) duruşa döner; mevcut karar geçersiz kılındı."
            ageText = ""; parentDeclaration = false; mode = .adult
            extraCautionFear = false; extraCautionManipulation = false; blockSensitiveNews = false
            createdEpoch = 0; profileID = UUID().uuidString
        } else {
            message = "SİLİNEMEDİ — profil hâlâ kayıtlı (dürüst hata)."
        }
        load()
        statusLine = message
    }
}
