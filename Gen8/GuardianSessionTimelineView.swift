//
//  GuardianSessionTimelineView.swift — C/E-lane: the "Bu Oturum" (This Session) LIVE TIMELINE sheet.
//
//  WHY THIS EXISTS (mandate C/E): the user can open this from the Live Insight card to SEE what the Guardian
//  actually did this session — the real event stream (started / new content / evidence / decision / content
//  changed / interrupted), each with a time, a category, a status, and a per-event "Neden?" (reusing the SAME
//  GuardianReasonCodeV1 mapping as the Live Insight card). Nothing here is fabricated.
//
//  PRIVACY (D-lane): NO raw OCR text, NO frames, NO titles, NO personal content. Only the lock-safe categorical
//  event + a short derived reason string. The feed is session-scoped and empties when Guardian is OFF.
//
import SwiftUI

struct GuardianSessionTimelineView: View {
    @Bindable var model: GuardianLabModel
    @State private var whyEvent: GuardianTimelineEventV1? = nil

    // Newest first — the most recent Guardian moment is what the user most wants to see.
    private var events: [GuardianTimelineEventV1] { model.timelineEvents.reversed() }

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty { emptyState } else { list }
            }
            .navigationTitle("Bu Oturum")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $whyEvent) { ev in whySheet(ev) }
    }

    private var emptyState: some View {
        VStack(spacing: GTokens.s3) {
            Image(systemName: "clock.badge.questionmark")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text(model.guardianEnabled
                 ? "Bu oturumda henüz bir olay yok."
                 : "Guardian kapalı — olay akışı durdu.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if model.labMode {
                Text("Lab oturumu (sentetik içerik üzerinde gerçek motor olayları).")
                    .font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center)
            }
        }
        .padding(GTokens.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            if model.labMode {
                Section {
                    Label("Lab oturumu — sentetik içerik, gerçek motor olayları.", systemImage: "flask")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(events) { ev in row(ev) }
            } footer: {
                Text("Olaylar yalnızca bu oturuma aittir ve oturum bitince silinir. Ham ekran/metin saklanmaz.")
                    .font(.caption2)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func row(_ ev: GuardianTimelineEventV1) -> some View {
        Button { whyEvent = ev } label: {
            HStack(spacing: GTokens.s3) {
                Circle().fill(statusColor(ev.status)).frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(categoryLabel(ev.category)).font(.callout.weight(.medium)).foregroundStyle(.primary)
                    Text(statusLabel(ev.status)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(timeString(ev.epochSeconds))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Image(systemName: "questionmark.circle").font(.caption).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Bu olayın gerekçesini gösterir."))
    }

    private func whySheet(_ ev: GuardianTimelineEventV1) -> some View {
        VStack(alignment: .leading, spacing: GTokens.s4) {
            HStack {
                Image(systemName: "questionmark.circle").font(.title2).foregroundStyle(statusColor(ev.status))
                Text("Neden?").font(.title2.weight(.semibold))
            }
            Text("\(categoryLabel(ev.category)) · \(statusLabel(ev.status)) · \(timeString(ev.epochSeconds))")
                .font(.caption).foregroundStyle(.secondary)
            Text(model.whyForEvent(ev))
                .font(.body).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Kapat") { whyEvent = nil }
                .frame(maxWidth: .infinity, minHeight: GTokens.minTouch)
                .buttonStyle(.borderedProminent)
        }
        .padding(GTokens.s6)
        .presentationDetents([.height(240)])
    }

    // MARK: - Pure projections (categorical → short Turkish label; no raw content)

    private func categoryLabel(_ c: GuardianTimelineCategoryV1) -> String {
        switch c {
        case .sessionStarted:     return "Oturum başladı"
        case .sessionEnded:       return "Oturum bitti"
        case .newContent:         return "Yeni içerik algılandı"
        case .identityResolved:   return "Kimlik çözüldü"
        case .evidenceCaptured:   return "Kanıt elde edildi"
        case .decision:           return "Guardian kararı"
        case .contentChanged:     return "İçerik değişti"
        case .observationGap:     return "Gözlem kesildi"
        case .observationResumed: return "Gözlem yeniden başladı"
        }
    }

    private func statusLabel(_ s: GuardianTimelineStatusV1) -> String {
        switch s {
        case .active:      return "Etkin"
        case .benign:      return "Kalkan eşleşmesi yok (analiz kapsamında)"
        case .caution:     return "Dikkat"
        case .shieldMatch: return "Kalkan eşleşti"
        case .unknown:     return "Belirsiz"
        case .ended:       return "Durdu"
        }
    }

    private func statusColor(_ s: GuardianTimelineStatusV1) -> Color {
        switch s {
        case .active, .benign: return .green
        case .caution:         return .orange
        case .shieldMatch:     return .red
        case .unknown:         return .secondary
        case .ended:           return .secondary
        }
    }

    private func timeString(_ epoch: Double) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        return f.string(from: Date(timeIntervalSince1970: epoch))
    }
}
