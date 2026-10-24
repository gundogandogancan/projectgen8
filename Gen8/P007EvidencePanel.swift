//
//  P007EvidencePanel.swift — GuardianLab V5 internal evidence panel (PROMPT 007 §31)
//  Debug/evidence only; not shown in normal UX. States are HONEST: device-only metrics read NOT_MEASURED here
//  because no signing team is wired (see docs/platform/ios/P007_DEVICE_AND_SIGNING_ENVIRONMENT.md).
//
import SwiftUI
import GuardianCore

struct P007EvidencePanel: View {
    private let profile = DeviceCapabilityProfile()   // runtime-derived on device; defaults in simulator

    var body: some View {
        DisclosureGroup("P007 Evidence (internal)") {
            VStack(alignment: .leading, spacing: GTokens.s1) {
                row("Device / signing", "iPhone connected · team PENDING_EXTERNAL_DEPENDENCY")
                row("App Group IPC", GuardianActivationBridge.shared.diagnostic)   // honest: ACTIVE vs DEGRADED — never a silent fallback
                row("Compute plan", profile.recommendedMode().rawValue)
                row("Heavy models allowed", profile.allowsHeavyModels ? "yes" : "no")
                row("H1 visual safety", "UNAVAILABLE (no rights-clear model)")
                row("Speech TR/EN", "on-device probe (lab); device NOT_MEASURED")
                row("Admission latency", "LAB benchmarked; device NOT_MEASURED")
                row("Native surface sample", NativeSurfaceState.from(glyph: .shieldMatch, guardianEnabled: true).lockSafeLabel)
            }
            .font(.caption.monospaced())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, GTokens.s1)
        }
        .font(.caption)
        .padding(.horizontal, GTokens.s4)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).foregroundStyle(.secondary).frame(width: 160, alignment: .leading)
            Text(v)
            Spacer(minLength: 0)
        }
    }
}
