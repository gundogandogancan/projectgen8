//
//  RecognitionMemoryModel.swift — R11-B §5: the @MainActor @Observable the "İçerik Hafızası" (Content Memory) screen
//  binds to. It owns the user-facing controls for the on-device Content Evidence Memory (Recognize & Recall V1):
//  ON/OFF toggle, first-run consent, record-type visibility (counts per modality), clear-all, and retention choice.
//
//  PRIVACY CONTRACT (mandate §4/§5): DEFAULT ON but strictly LOCAL-ONLY; nothing is uploaded. When OFF, the extension
//  does NO lookup and NO write (the store's settings.enabled gate). Clearing removes all records; consent withdrawal
//  (turning OFF) is honoured. The model only ever reads/writes DERIVED records — it never surfaces raw media (there is
//  none to surface). The counts shown are derived aggregates (how many records, by modality), never content.
//
import Foundation
// NOTE: GuardianMedia types are SOURCE-compiled into this app target (same pattern as GuardianLabModel) —
// there is intentionally NO `import GuardianMedia`; the app does not link GuardianMedia as a module.

@MainActor
@Observable
final class RecognitionMemoryModel {
    private let store: ContentEvidenceMemoryV1

    private(set) var enabled: Bool = true
    private(set) var consentShown: Bool = false
    private(set) var retentionDays: Int = 30
    private(set) var recordCount: Int = 0
    /// Derived visibility: how many records carry each modality (record-type visibility, mandate §5). Never content.
    private(set) var modalityCounts: [String: Int] = [:]
    private(set) var fileProtectionComplete: Bool = false
    private(set) var excludedFromBackup: Bool = false
    private(set) var sharedContainerActive: Bool = false

    init(store: ContentEvidenceMemoryV1 = ContentEvidenceMemoryV1()) {
        self.store = store
        refresh()
    }

    func refresh() {
        let res = store.load()
        enabled = res.payload.settings.enabled
        consentShown = res.payload.settings.consentShown
        retentionDays = res.payload.settings.retentionDays
        recordCount = res.payload.records.count
        var counts: [String: Int] = [:]
        for r in res.payload.records { for m in r.evidenceModalities { counts[m, default: 0] += 1 } }
        modalityCounts = counts
        fileProtectionComplete = res.fileProtectionComplete
        excludedFromBackup = res.excludedFromBackup
        sharedContainerActive = res.sharedContainerActive
    }

    private var currentSettings: RecognitionMemorySettingsV1 {
        RecognitionMemorySettingsV1(enabled: enabled, consentShown: consentShown, retentionDays: retentionDays)
    }

    func markConsentShown() {
        var s = currentSettings; s.consentShown = true
        _ = store.saveSettings(s, nowEpoch: Date().timeIntervalSince1970)
        refresh()
    }

    func setEnabled(_ on: Bool) {
        var s = currentSettings; s.enabled = on
        _ = store.saveSettings(s, nowEpoch: Date().timeIntervalSince1970)
        refresh()
    }

    func setRetentionDays(_ days: Int) {
        var s = currentSettings; s.retentionDays = days
        _ = store.saveSettings(s, nowEpoch: Date().timeIntervalSince1970)
        refresh()
    }

    /// §5 — "hafızayı temizle": clear all records but keep settings.
    func clearAll() {
        _ = store.clearAllRecords(nowEpoch: Date().timeIntervalSince1970)
        refresh()
    }
}
