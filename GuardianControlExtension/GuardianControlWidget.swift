//
//  GuardianControlWidget.swift — REAL WidgetKit Control (PROMPT 007A §9; §6 adaptive-session extension).
//  Control Center controls for Gen8 Guardian:
//   (1) Guardian ON/OFF intent (SetValueIntent).  Guardian ON ≠ broadcast started — the control changes INTENT only
//       (it writes `guardian.enabled`, now a REAL analysis gate the broadcast extension consumes). An AppIntent
//       CANNOT silently start a ReplayKit broadcast, and a SetValueIntent/toggle cannot launch the app, so this
//       control does NOT open the app — it only flips the product on/off intent. The separate LAUNCHER control (3)
//       is the Apple-supported path to the broadcast-start screen.
//   (2) §6 ACTIVE/IDLE one-tap toggle (SetValueIntent) — flips the user-controlled session mode the broadcast
//       extension observes. IDLE pauses heavy analysis (no "koruma aktif" claim); it NEVER stops the OS broadcast,
//       so we never claim "yayın durdu" — if the OS broadcast is still running the user stops it from the red bar.
//   (3) §A LAUNCHER control — an OpenIntent-backed button. iOS 18 ControlWidgetButton with an AppIntent conforming
//       to OpenIntent is the DOCUMENTED, Apple-supported way to foreground the app from Control Center. This is the
//       real "turning Guardian ON takes you to the broadcast-start screen" path: it opens the app, where Apple's
//       system broadcast picker lives (the ONLY place a ReplayKit broadcast can legitimately be started).
//  Four honest states surface through GuardianControlState.displayState: aktif / rölanti / kapalı / izin-bekliyor.
//
import WidgetKit
import AppIntents
import SwiftUI

@available(iOS 18.0, *)
struct GuardianControlWidget: ControlWidget {
    static let kind = "com.aymedo.Gen8.GuardianControl.toggle"   // PROPOSED id; no portal registration in R1
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetToggle("Gen8 Guardian",
                                isOn: GuardianControlState.shared.isEnabled,
                                action: GuardianToggleIntent()) { isOn in
                // Honest state label: aktif / rölanti / kapalı / izin-bekliyor (not just On/Off — §6).
                let s = GuardianControlState.shared.displayState
                Label(Self.title(for: s), systemImage: Self.symbol(for: s))
            }
        }
        .displayName("Gen8 Guardian")
        .description("Gen8 Guardian'ı açar/kapatır (ürün niyeti). Kapalıyken asla 'korundu' demez ve ağır analiz gerçekten durur. Yayını başlatmak için ayrı 'Yayını Başlat' kontrolünü kullan.")
    }

    static func title(for s: GuardianControlState.ControlDisplayState) -> String {
        switch s {
        case .off: return "Kapalı"
        case .permissionPending: return "İzin bekliyor"
        case .idle: return "Rölanti"
        case .active: return "Aktif"
        }
    }
    static func symbol(for s: GuardianControlState.ControlDisplayState) -> String {
        switch s {
        case .off: return "shield.slash"
        case .permissionPending: return "shield.lefthalf.filled.badge.checkmark"
        case .idle: return "pause.circle"
        case .active: return "shield.lefthalf.filled"
        }
    }
}

/// §6 — a SECOND control: the one-tap ACTIVE/IDLE switch. Visible only as a toggle whose state is the live idle flag.
@available(iOS 18.0, *)
struct GuardianIdleControlWidget: ControlWidget {
    static let kind = "com.aymedo.Gen8.GuardianControl.idle"
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetToggle("Gen8 Rölanti",
                                isOn: GuardianControlState.shared.isIdle,
                                action: GuardianIdleIntent()) { isIdle in
                Label(isIdle ? "Rölanti" : "Analiz açık", systemImage: isIdle ? "pause.circle" : "waveform")
            }
        }
        .displayName("Gen8 Analiz / Rölanti")
        .description("Analizi duraklat (rölanti) veya sürdür. Rölanti yayını durdurmaz; yalnızca ağır analizi duraklatır.")
    }
}

/// §A — the LAUNCHER control. A ControlWidgetButton whose action is an OpenIntent: the Apple-supported way to
/// foreground the app from Control Center. This is the honest "takes you to the broadcast-start screen" path — the
/// toggle above CANNOT open the app (a SetValueIntent has no launch effect), so this separate button carries that job.
@available(iOS 18.0, *)
struct GuardianLaunchControlWidget: ControlWidget {
    static let kind = "com.aymedo.Gen8.GuardianControl.launch"
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: GuardianOpenAppIntent()) {
                Label("Yayını Başlat", systemImage: "dot.radiowaves.left.and.right")
            }
        }
        .displayName("Gen8 Yayını Başlat")
        .description("Uygulamayı açar. ReplayKit yayını yalnızca Apple'ın sistem yayın seçicisinden başlatılabilir; bu kontrol seni o ekrana götürür.")
    }
}

/// §A — OpenIntent: foregrounds the Gen8 app. `openAppWhenRun = true` + OpenIntent conformance is the documented
/// iOS 18 mechanism for a Control Center button to launch the app. No broadcast is started here (iOS owns that via
/// the system picker inside the app) — we only open the app to the start screen, honestly.
@available(iOS 18.0, *)
struct GuardianOpenAppIntent: AppIntent, OpenIntent {
    static let title: LocalizedStringResource = "Open Gen8"
    static let openAppWhenRun = true
    @Parameter(title: "Target") var target: GuardianLaunchTarget
    init() { self.target = GuardianLaunchTarget(id: "broadcast-start") }
    func perform() async throws -> some IntentResult { .result() }
}

/// The launch target entity for the OpenIntent (a single well-known destination: the broadcast-start screen).
@available(iOS 18.0, *)
struct GuardianLaunchTarget: AppEntity {
    let id: String
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Gen8 Destination" }
    var displayRepresentation: DisplayRepresentation { "Yayın başlatma ekranı" }
    static var defaultQuery = GuardianLaunchTargetQuery()
}

@available(iOS 18.0, *)
struct GuardianLaunchTargetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [GuardianLaunchTarget] {
        identifiers.map { GuardianLaunchTarget(id: $0) }
    }
    func suggestedEntities() async throws -> [GuardianLaunchTarget] {
        [GuardianLaunchTarget(id: "broadcast-start")]
    }
}

@available(iOS 18.0, *)
struct GuardianToggleIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Gen8 Guardian"
    @Parameter(title: "Enabled") var value: Bool
    init() {}
    func perform() async throws -> some IntentResult {
        GuardianControlState.shared.setEnabled(value)   // single source of truth; OFF cancels future Guardian work
        return .result()
    }
}

/// §6 — ACTIVE/IDLE intent. Writes the user-controlled session mode the broadcast extension polls. It CANNOT start a
/// broadcast and does NOT stop the OS broadcast — it only toggles whether heavy analysis runs while a broadcast is up.
@available(iOS 18.0, *)
struct GuardianIdleIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Gen8 Analysis Idle"
    @Parameter(title: "Idle") var value: Bool
    init() {}
    func perform() async throws -> some IntentResult {
        GuardianControlState.shared.setIdle(value)   // IDLE = pause heavy analysis; broadcast keeps running if live
        return .result()
    }
}
