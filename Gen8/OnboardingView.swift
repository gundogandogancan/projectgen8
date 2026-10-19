//
//  OnboardingView.swift — minimal onboarding (PROMPT 001 §C, §19)
//  Choose mode + Personal Algorithm threshold; truthful capability/privacy note; enter GuardianLab.
//
import SwiftUI
import GuardianCore

struct OnboardingView: View {
    @Bindable var model: GuardianLabModel
    let onEnter: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Gen8 understands what you’re about to see — before you see it — and shows one calm signal. It never claims to control another app’s feed, and it shows “?” when it doesn’t know.")
                        .font(.callout).foregroundStyle(.secondary)
                } header: { Text("Your Guardian") }

                Section("Mode") {
                    Picker("Mode", selection: $model.mode) {
                        ForEach(GuardianMode.allCases, id: \.self) { m in
                            Text(m.rawValue.capitalized).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    HStack {
                        Text("Minimum score")
                        Spacer()
                        Text(String(format: "%.1f", model.threshold))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: $model.threshold, in: 0...10, step: 0.5) {
                        Text("Minimum personal score")
                    }
                    .accessibilityValue(String(format: "%.1f", model.threshold))
                } header: { Text("My Algorithm") }
                footer: { Text("Content scoring below your threshold is marked Not Recommended. Your explicit choices outrank passive signals.") }

                Section {
                    Label("Raw screen content is never stored. Analysis is on-device for this lab.", systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { Text("Privacy & capability truth") }

                Section {
                    Button(action: onEnter) {
                        Text("Enter GuardianLab")
                            .frame(maxWidth: .infinity, minHeight: GTokens.minTouch)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Welcome")
        }
    }
}
