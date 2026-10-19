//
//  PureBarView.swift — the default Guardian surface (PROMPT 001 §8)
//  Ultra-thin, premium, calm. Tap → compact score/status. Expand → why/protection/evidence.
//  Truthful: UNKNOWN shows grey + "?" and never a stale safe/green state.
//
import SwiftUI
import GuardianCore

struct PureBarView: View {
    let state: GuardianSurfaceState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    let explanation: String

    var body: some View {
        VStack(spacing: GTokens.s2) {
            // L0 — the pure adaptive color bar (default).
            Capsule()
                .fill(state.tone.color)
                .frame(height: GTokens.barHeight)
                .frame(maxWidth: .infinity)
                .overlay(
                    Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: state.tone)

            // L1 — tap reveals compact score + status (color is NOT the only signal).
            if expanded {
                VStack(alignment: .leading, spacing: GTokens.s2) {
                    HStack(spacing: GTokens.s2) {
                        Image(systemName: state.tone.symbolName)
                            .foregroundStyle(state.tone.color)
                            .accessibilityHidden(true)
                        Text(state.label).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(state.scoreDisplay)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text("Coverage: \(state.coverage.rawValue)")
                        .font(.caption).foregroundStyle(.secondary)
                    // L2 — why / protection / evidence / matched rule.
                    Text(explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(GTokens.s3)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(reduceMotion ? nil : .easeInOut) { expanded.toggle() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Guardian: \(state.label), score \(state.scoreDisplay), coverage \(state.coverage.rawValue)")
        .accessibilityHint("Double-tap to \(expanded ? "hide" : "show") the reason.")
        .accessibilityAddTraits(.isButton)
    }
}
