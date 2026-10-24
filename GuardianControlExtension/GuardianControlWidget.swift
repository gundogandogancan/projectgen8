//
//  GuardianControlWidget.swift — REAL WidgetKit Control (PROMPT 007A §9; §6 adaptive-session extension).
//  Control Center controls for Gen8 Guardian:
//   (1) Guardian ON/OFF intent (SetValueIntent).  Guardian ON ≠ broadcast started — the control changes INTENT; the
//       broadcast is only ever "aktif" when a REAL system callback/heartbeat proves it (mandate §6). An AppIntent
//       CANNOT silently start a ReplayKit broadcast, so turning Guardian ON DEEP-LINKS the user into the app's start
//       screen where Apple's system broadcast picker lives.
//   (2) §6 ACTIVE/IDLE one-tap toggle (SetValueIntent) — flips the user-controlled session mode the broadcast
//       extension observes. IDLE pauses heavy analysis (no "koruma aktif" claim); it NEVER stops the OS broadcast,
//       so we never claim "yayın durdu" — if the OS broadcast is still running the user stops it from the red bar.
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
        .description("Gen8 Guardian'ı açar/kapatır. Kapalıyken asla 'korundu' demez. Açmak yayın başlatma ekranını açar.")
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
