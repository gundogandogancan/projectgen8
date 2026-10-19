//
//  GuardianControlWidget.swift — REAL WidgetKit Control (PROMPT 007A §9)
//  Control Center toggle for Gen8 Guardian ON/OFF via AppIntents SetValueIntent + shared activation state.
//  Compiles under the installed toolchain; unsigned/uninstalled in this R1 prompt.
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
                Label(isOn ? "On" : "Off", systemImage: isOn ? "shield.lefthalf.filled" : "shield.slash")
            }
        }
        .displayName("Gen8 Guardian")
        .description("Turns the Gen8 Guardian runtime on or off. Off never claims Protected.")
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
