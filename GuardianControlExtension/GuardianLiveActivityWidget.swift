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
            // Lock screen / banner — privacy-safe: alive timer + chosen-style indicator + lock-safe label (no rule text).
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: Self.icon(context.state.surface))
                    Text(context.state.title).font(.callout.weight(.medium))   // §2.3 state-specific title
                    Spacer()
                    LiveSessionTimer(start: context.state.sessionStart).font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                // §2.1 — render in the user's chosen style (same real state): HEAT_MAP bar / EMOJI / NUMBER(locked).
                StyledStateIndicator(style: context.state.displayStyleRaw, bandRaw: context.state.bandRaw,
                                     position: context.state.bandPosition, compact: false)
                    .frame(height: 20)
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
                    // §2.3 — the state-specific title (Gözlemde / Rölanti / Analiz / Kapalı …), never hard-coded.
                    Text(context.state.title).font(.caption2).foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // §2.1 — the user's chosen style renders the SAME real state + band.
                        StyledStateIndicator(style: context.state.displayStyleRaw, bandRaw: context.state.bandRaw,
                                             position: context.state.bandPosition, compact: false)
                            .frame(height: 22)
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
                // §2.1 — the band in the user's chosen compact style (mini heat bar / emoji face). NUMBER stays locked.
                StyledStateIndicator(style: context.state.displayStyleRaw, bandRaw: context.state.bandRaw,
                                     position: context.state.bandPosition, compact: true)
                    .frame(width: 34, height: 14)
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
                    // The sliding marker — a bright pill at the watched content's band position. §2.2: a USER_OVERRIDE
                    // draws HOLLOW (clear fill + band-colour outline) so a conscious exception is visually distinct
                    // from an evidence-clear FILLED marker (never confused with a green "safe" result).
                    let override = GuardianHeatBandRaw.isUserOverride(bandRaw)
                    Capsule()
                        .fill(override ? Color.clear : Color.white)
                        .overlay(Capsule().stroke(GuardianHeatBandRaw.color(bandRaw), lineWidth: override ? 2.5 : 2))
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
/// §2.2: a USER_OVERRIDE draws a HOLLOW (outlined) dot so the conscious exception stays distinct even when tiny.
struct MiniHeatBar: View {
    let bandRaw: String
    let position: Double
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let live = GuardianHeatBandRaw.isLive(bandRaw)
            let override = GuardianHeatBandRaw.isUserOverride(bandRaw)
            let x = min(max(CGFloat(position) * w, h / 2), w - h / 2)
            ZStack(alignment: .leading) {
                Capsule().fill(GuardianHeatBandRaw.color(bandRaw).opacity(live ? 0.35 : 0.2))
                if live {
                    Circle()
                        .fill(override ? Color.clear : GuardianHeatBandRaw.color(bandRaw))
                        .overlay(Circle().stroke(GuardianHeatBandRaw.color(bandRaw), lineWidth: override ? 2 : 0))
                        .frame(width: h, height: h)
                        .position(x: x, y: h / 2)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: position)
        }
    }
}

// MARK: - §2.1 Three display styles (HEAT_MAP / EMOJI / NUMBER-locked) — all render the SAME real state + band.

/// Renders the CURRENT band in the user's chosen display style. There is NEVER separate decision logic per style:
/// every style is a pure projection of the SAME GuardianUserVisibleState + band + policy that the heat bar uses.
///  • HEAT_MAP → the categorical heat bar + sliding marker.
///  • EMOJI    → the band as a colour face + expressive glyph (🟢😊 ⬜🤔 🟡⚠️ 🔴🛡️ 🔵🙋).
///  • NUMBER   → VISIBLE but LOCKED (score gate CLOSED, rule 8): shows a padlock + honest "kalibrasyon" copy,
///               NEVER a fabricated 0-100. Falls back to the heat bar beneath the lock so state is still legible.
struct StyledStateIndicator: View {
    let style: String
    let bandRaw: String
    let position: Double
    let compact: Bool

    var body: some View {
        switch style {
        case GuardianDisplayStyleRaw.emoji:
            emojiView
        case GuardianDisplayStyleRaw.number:
            numberLockedView
        default:   // HEAT_MAP (and any unknown style) → the categorical bar
            heatView
        }
    }

    private var heatView: some View {
        compact
            ? AnyView(MiniHeatBar(bandRaw: bandRaw, position: position))
            : AnyView(HeatBar(bandRaw: bandRaw, position: position))
    }

    private var emojiView: some View {
        let face = GuardianDisplayStyleRaw.emojiFace(bandRaw)
        let glyph = GuardianDisplayStyleRaw.emojiGlyph(bandRaw)
        return HStack(spacing: compact ? 1 : 4) {
            Text(face).font(compact ? .caption2 : .title3)
            if !compact { Text(glyph).font(.title3) }
        }
        .frame(maxWidth: .infinity, alignment: compact ? .trailing : .center)
        .accessibilityLabel(GuardianHeatBandRaw.caption(bandRaw))
    }

    private var numberLockedView: some View {
        // NUMBER is visible-but-locked: honest padlock, never a fabricated score. The bar stays underneath so the
        // real categorical state is never hidden behind the lock.
        ZStack {
            heatView.opacity(0.35)
            HStack(spacing: 3) {
                Image(systemName: "lock.fill").font(.caption2)
                if !compact { Text("Kalibrasyon bekliyor").font(.caption2) }
            }
            .foregroundStyle(.secondary)
        }
    }
}
