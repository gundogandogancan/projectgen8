//
//  PersonalPhotoShieldView.swift — P1-5: the product UI to add a PERSONAL PHOTO REFERENCE to the shield.
//
//  WHY (mandate §5): the user picks a reference image via Apple's PhotosPicker; we extract the LOCAL derived visual
//  signature (P006C) and save a user rule producing a real policyRevision. The raw photo is NOT persisted by default
//  (only the derived signature bytes). On a third-party surface the match is WARN-only (rule 18). Semantic relations
//  (who/what the photo depicts) are UNKNOWN/UNAVAILABLE in V1 — the UI says so and never fabricates them.
//
import SwiftUI
import GuardianCore
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(UIKit)
import UIKit
#endif

struct PersonalPhotoShieldView: View {
    @Bindable var shield: ShieldStudioModel
    @State private var label: String = ""
    @State private var action: ShieldAction = .warn
    @State private var statusMessage: String?
    @State private var adding = false
    #if canImport(PhotosUI)
    @State private var picked: PhotosPickerItem?
    #endif

    var body: some View {
        Form {
            Section {
                TextField("Etiket (örn. 'benim fotoğrafım')", text: $label)
                Picker("Eşleşince", selection: $action) {
                    Text("Uyar").tag(ShieldAction.warn)
                    Text("Sor").tag(ShieldAction.ask)
                }
            } header: {
                Text("Fotoğraf referansı")
            } footer: {
                Text("Seçtiğiniz görselden yalnızca YEREL bir görsel imza çıkarılır; ham fotoğraf saklanmaz. Üçüncü taraf uygulamada eşleşme yalnızca UYARI üretir (feed'i kontrol edemeyiz).")
            }

            Section {
                #if canImport(PhotosUI)
                PhotosPicker(selection: $picked, matching: .images, photoLibrary: .shared()) {
                    Label(adding ? "Ekleniyor…" : "Fotoğraf seç ve ekle", systemImage: "photo.badge.plus")
                }
                .disabled(adding)
                #else
                Text("Fotoğraf seçici bu platformda kullanılamıyor.")
                    .foregroundStyle(.secondary)
                #endif
                if let statusMessage {
                    Text(statusMessage).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                let imageRules = shield.rules.filter { $0.inputType == .imageReference }
                if imageRules.isEmpty {
                    Text("Henüz fotoğraf referansı eklenmedi.").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(imageRules, id: \.ruleID) { rule in
                        HStack {
                            Image(systemName: "photo").foregroundStyle(.tint)
                            Text(rule.rawUserLabel)
                            Spacer()
                            Text(rule.action.rawValue).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { idx in
                        for i in idx { shield.delete(imageRules[i]) }
                    }
                }
            } header: {
                Text("Eklenen fotoğraf referansları")
            } footer: {
                Text("Sınır: eşleştirme GÖRSEL benzerliğe dayanır (aynı/benzer/kırpılmış görsel). Fotoğrafın kime/neye ait olduğu (kişi, takım, konu) V1'de BİLİNMİYOR — bu bir anlamsal iddia değildir.")
            }
        }
        #if canImport(PhotosUI) && canImport(UIKit) && canImport(CoreGraphics)
        .onChange(of: picked) { _, item in
            guard let item else { return }
            adding = true; statusMessage = nil
            Task {
                defer { adding = false; picked = nil }
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let ui = UIImage(data: data), let cg = ui.cgImage else {
                    statusMessage = "Görsel okunamadı."
                    return
                }
                let ok = shield.addPhotoReference(cg, label: label, action: action)
                statusMessage = ok ? "Referans eklendi (politika sürümü: \(shield.policyRevision))."
                                   : "Görsel imzası çıkarılamadı; eklenmedi."
                if ok { label = "" }
            }
        }
        #endif
    }
}
