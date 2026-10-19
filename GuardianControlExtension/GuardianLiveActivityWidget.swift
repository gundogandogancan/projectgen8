//
//  GuardianLiveActivityWidget.swift — REAL Live Activity / Dynamic Island surface (PROMPT 007A §10,§11)
//  Compiles the actual ActivityConfiguration + Dynamic Island regions. Minimal, privacy-safe (no Shield rule text),
//  UNKNOWN fallback, never a stale positive. Not device-verified (COMPILED_NOT_DEVICE_VERIFIED).
//
import WidgetKit
import SwiftUI
import ActivityKit

// GuardianActivityAttributes is the CANONICAL shared type in Shared/GuardianLiveShared.swift (compiled into this target too).

struct GuardianLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GuardianActivityAttributes.self) { context in
            // Lock screen / banner — minimal, privacy-safe.
            HStack(spacing: 8) {
                Image(systemName: Self.icon(context.state.surface))
                Text(context.state.label).font(.callout.weight(.medium))
                Spacer()
            }
            .padding(12)
            .activityBackgroundTint(.black.opacity(0.25))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: Self.icon(context.state.surface)) }
                DynamicIslandExpandedRegion(.trailing) { Text(Self.short(context.state.surface)).font(.caption2) }
                DynamicIslandExpandedRegion(.center) { Text("Gen8").font(.caption2).foregroundStyle(.secondary) }
                DynamicIslandExpandedRegion(.bottom) { Text(context.state.label).font(.caption) }
            } compactLeading: {
                Image(systemName: Self.icon(context.state.surface))
            } compactTrailing: {
                Text(Self.short(context.state.surface)).font(.caption2)
            } minimal: {
                Image(systemName: Self.icon(context.state.surface))
            }
            .widgetURL(nil)
            .keylineTint(.clear)
        }
    }

    // Map the surface raw value → SF Symbol. Unknown/unmapped → questionmark (never a positive/safe default).
    static func icon(_ surface: String) -> String {
        switch surface {
        case "GUARDIAN_ON": return "shield.lefthalf.filled"
        case "CAUTION": return "exclamationmark.triangle"
        case "SHIELD_MATCH": return "eye.slash"
        case "OFF": return "shield.slash"
        default: return "questionmark.circle"   // UNKNOWN fallback
        }
    }
    static func short(_ surface: String) -> String {
        switch surface {
        case "GUARDIAN_ON": return "On"
        case "CAUTION": return "Caution"
        case "SHIELD_MATCH": return "Shield"
        case "OFF": return "Off"
        default: return "Unknown"
        }
    }
}
