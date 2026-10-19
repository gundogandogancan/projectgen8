//
//  DesignSystem.swift — P0-Q design primitives (PROMPT 001 §B, §8, §24)
//  Minimal/elite/premium/native/calm. Semantic color tokens (no neon, no emoji icons).
//  Color is never the only signal (§603): every tone also carries a text label.
//
import SwiftUI
import GuardianCore

enum GTokens {
    // Spacing scale
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32
    static let radius: CGFloat = 14
    static let minTouch: CGFloat = 44           // accessibility touch target
    static let barHeight: CGFloat = 8           // ultra-thin Pure Bar
}

extension GuardianSurfaceState.Tone {
    /// Refined, calm semantic colors (no neon). Dark/light adaptive via opacity + system.
    var color: Color {
        switch self {
        case .aligned:        return Color(red: 0.16, green: 0.62, blue: 0.56) // refined teal/green
        case .neutral:        return Color(red: 0.26, green: 0.47, blue: 0.70) // restrained cool blue
        case .caution:        return Color(red: 0.85, green: 0.62, blue: 0.24) // refined amber
        case .strongCaution:  return Color(red: 0.84, green: 0.38, blue: 0.37) // soft coral
        case .unknown:        return Color(red: 0.55, green: 0.56, blue: 0.58) // neutral grey
        }
    }
    /// Non-color cue (icon/shape semantics), never color-only.
    var symbolName: String {
        switch self {
        case .aligned: return "checkmark.circle"
        case .neutral: return "info.circle"
        case .caution: return "exclamationmark.triangle"
        case .strongCaution: return "hand.raised"
        case .unknown: return "questionmark.circle"
        }
    }
}
