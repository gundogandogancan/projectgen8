//
//  ContentView.swift — RootView (app shell + navigation)
//  Launch moves immediately into state (no fake splash delay — PROMPT 001 §25).
//
import SwiftUI

struct RootView: View {
    @State private var model = GuardianLabModel()
    @State private var settings = AppSettings.shared
    @State private var entered = false

    var body: some View {
        Group {
            if entered {
                GuardianLabView(model: model)
            } else {
                OnboardingView(model: model) {
                    model.applyOnboarding()
                    entered = true
                    Task { await model.restartFeed() }
                }
            }
        }
        .environment(settings)
        .environment(\.locale, settings.language.localeOverride ?? Locale.autoupdatingCurrent)
        .task {
            // Headless device-proof hook (NOT normal UX): launch with
            // devicectl ... --environment-variables '{"GEN8_LA_EXERCISE":"1"}'
            #if canImport(ActivityKit)
            if #available(iOS 16.1, *), ProcessInfo.processInfo.environment["GEN8_LA_EXERCISE"] == "1" {
                GuardianLiveActivityController.shared.devExercise()
            }
            #endif
        }
    }
}

#Preview {
    RootView()
}
