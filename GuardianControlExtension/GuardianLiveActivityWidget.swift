//
//  GuardianLiveActivityWidget.swift — REAL Live Activity / Dynamic Island surface (PROMPT 007A §10,§11).
//
//  LIVE DYNAMIC ISLAND (micro-iteration): the Island is ALIVE like a music player AND shows a categorical HEAT BAR
//  whose marker slides to the WATCHED content's band the instant content changes.
//   • ALWAYS-ALIVE element: Text(timerInterval:) — a SYSTEM-ANIMATED session timer that ticks continuously with ZERO
//     app updates (the only lawful "always moving" mechanic ActivityKit gives us).
//   • HEAT BAR + MARKER: categorical bands (green CLEAR / gray UNKNOWN / amber CAUTION / red SHIELD) with a marker at
//     a CONTINUOUS position 0...1. The band + position come from the pure GuardianHeatMarkerV1 via the ContentState;
//     marker movement animates on each state-change update (SwiftUI implicit animation on the decoded position).
//   • NO fabricated 0-100 number anywhere (constitution rule 8). Position is state-derived today; a real score can
//     slot into the SAME marker later with no redesign. OFF drops the protective look immediately (no live marker).
//
//  Live Activities do NOT render reliably on the simulator → Island RENDERING is DEVICE_UNVERIFIED. The band/position
//  LOGIC is proven headlessly in GuardianMediaTests.
//
import WidgetKit
import SwiftUI
import ActivityKit

// GuardianActivityAttributes + GuardianHeatBandRaw are the CANONICAL shared types in Shared/GuardianLiveShared.swift
// (compiled into this target too — this extension compiles ONLY that shared file, so everything the widget needs to
//  render the bar must be reachable from there, by design).

struct GuardianLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GuardianActivityAttributes.self) { context in
            // Lock screen / banner — privacy-safe: alive timer + heat bar + lock-safe label (no rule text).
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: Self.icon(context.state.surface))
                    Text(context.state.label).font(.callout.weight(.medium))
                    Spacer()
                    LiveSessionTimer(start: context.state.sessionStart).font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                HeatBar(bandRaw: context.state.bandRaw, position: context.state.bandPosition)
                    .frame(height: 8)
            }
            .padding(12)
            .activityBackgroundTint(.black.opacity(0.25))
        } dynamicIsland: { context in
            DynamicIsland {
                // EXPANDED — the full alive surface: timer + heat bar w/ sliding marker + last-event (category only).
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: Self.icon(context.state.surface))
                        .foregroundStyle(GuardianHeatBandRaw.color(context.state.bandRaw))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // The ALWAYS-ALIVE element: a system-animated timer, zero app updates needed.
                    HStack(spacing: 4) {
                        Image(systemName: "dot.radiowaves.left.and.right").font(.caption2)
                        LiveSessionTimer(start: context.state.sessionStart).font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Gözlemde").font(.caption2).foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        HeatBar(bandRaw: context.state.bandRaw, position: context.state.bandPosition)
                            .frame(height: 10)
                        HStack {
                            Text(context.state.label).font(.caption).foregroundStyle(.primary)
                            Spacer()
                            Text(GuardianHeatBandRaw.caption(context.state.bandRaw))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(GuardianHeatBandRaw.color(context.state.bandRaw))
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: Self.icon(context.state.surface))
                    .foregroundStyle(GuardianHeatBandRaw.color(context.state.bandRaw))
            } compactTrailing: {
                // Minimal heat mini-bar so the band (and the marker's position) is legible even when compact.
                MiniHeatBar(bandRaw: context.state.bandRaw, position: context.state.bandPosition)
                    .frame(width: 34, height: 6)
            } minimal: {
                // Apple-clean: a single state glyph tinted by the live band (dot = the heat colour).
                Image(systemName: Self.icon(context.state.surface))
                    .foregroundStyle(GuardianHeatBandRaw.color(context.state.bandRaw))
            }
            .widgetURL(nil)
            .keylineTint(GuardianHeatBandRaw.isLive(context.state.bandRaw)
                         ? GuardianHeatBandRaw.color(context.state.bandRaw) : .clear)
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

// MARK: - The always-alive session timer (system-animated; ZERO app updates)

/// Text(timerInterval:) counts UP from the session start with NO app involvement — this is the lawful "always-moving"
/// liveliness mechanic (it keeps ticking even when the OS budgets our background updates to zero).
struct LiveSessionTimer: View {
    let start: Date
    var body: some View {
        // Open-ended range → counts up continuously. Monospaced digits keep it from jittering as it ticks.
        Text(timerInterval: start...Date.distantFuture, countsDown: false)
            .monospacedDigit()
    }
}

// MARK: - The heat bar + sliding marker

/// The categorical heat bar: four fixed colour zones (green/gray/amber/red) with a marker at `position` (0...1).
/// The marker slides when the decoded position changes on a state-change update — the "slide to the watched band"
/// behaviour. No numbers are drawn (rule 8). OFF/dormant draws the track only, no marker (never a protective look).
struct HeatBar: View {
    let bandRaw: String
    let position: Double

    private var zones: [Color] {
        // Must match GuardianHeatBandV1.range boundaries (0…0.40 / …0.65 / …0.85 / …1.0) so the track reads the band.
        [GuardianHeatBandRaw.color(GuardianHeatBandRaw.clear).opacity(0.55),
         GuardianHeatBandRaw.color(GuardianHeatBandRaw.unknown).opacity(0.55),
         GuardianHeatBandRaw.color(GuardianHeatBandRaw.caution).opacity(0.55),
         GuardianHeatBandRaw.color(GuardianHeatBandRaw.shield).opacity(0.55)]
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let live = GuardianHeatBandRaw.isLive(bandRaw)
            let x = min(max(CGFloat(position) * w, h / 2), w - h / 2)
            ZStack(alignment: .leading) {
                // Track — the four bands as a gradient, so the full heat map is always visible.
                LinearGradient(colors: zones, startPoint: .leading, endPoint: .trailing)
                    .clipShape(Capsule())
                    .opacity(live ? 1 : 0.3)
                if live {
                    // The sliding marker — a bright pill at the watched content's band position.
                    Capsule()
                        .fill(.white)
                        .overlay(Capsule().stroke(GuardianHeatBandRaw.color(bandRaw), lineWidth: 2))
                        .frame(width: max(h, 6), height: h)
                        .position(x: x, y: h / 2)
                        .shadow(color: GuardianHeatBandRaw.color(bandRaw).opacity(0.8), radius: 3)
                }
            }
            // Marker slide + colour cross-fade on each state-change update (keyed on the decoded values).
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: position)
            .animation(.easeInOut(duration: 0.25), value: bandRaw)
        }
    }
}

/// Compact-trailing mini bar: same semantics, smaller — a single-colour track for the CURRENT band + a dot marker.
struct MiniHeatBar: View {
    let bandRaw: String
    let position: Double
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let live = GuardianHeatBandRaw.isLive(bandRaw)
            let x = min(max(CGFloat(position) * w, h / 2), w - h / 2)
            ZStack(alignment: .leading) {
                Capsule().fill(GuardianHeatBandRaw.color(bandRaw).opacity(live ? 0.35 : 0.2))
                if live {
                    Circle().fill(GuardianHeatBandRaw.color(bandRaw))
                        .frame(width: h, height: h)
                        .position(x: x, y: h / 2)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: position)
        }
    }
}
