//
//  MyShieldView.swift — "My Shield" studio surface (PROMPT 006A §26,§27)
//  Create personal shield rules (text / concept / source / sound), see the deterministic outcome,
//  and preview the Guardian glyph. Honest: low-confidence is shown as a note, UNKNOWN is never "safe".
//
import SwiftUI
import GuardianCore

struct MyShieldView: View {
    @Bindable var model: ShieldStudioModel
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: GTokens.s3) {
            glyphPreview
            sampleTester
            ruleComposer
            ruleList
        }
        .padding(.horizontal, GTokens.s4)
    }

    private var glyphPreview: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Text("Guardian glyph").font(.subheadline.weight(.semibold))
            HStack(spacing: GTokens.s3) {
                if let g = model.lastGlyph {
                    Image(systemName: g.symbolName).font(.title2)
                    if !g.emoji.isEmpty { Text(g.emoji).font(.title2) }
                    VStack(alignment: .leading) {
                        Text(g.label).font(.callout.weight(.medium))
                        if !g.isTruthfulSafeClaim {
                            Text("Not a safety claim").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Glyph off").foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Style", selection: $model.glyphStyle) {
                    Text("Minimal").tag(GlyphStyle.minimalSymbols)
                    Text("Emoji").tag(GlyphStyle.emoji)
                    Text("Off").tag(GlyphStyle.off)
                }
                .pickerStyle(.menu)
                .onChange(of: model.glyphStyle) { _, _ in model.evaluate() }
            }
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
    }

    private var sampleTester: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Text("Sample content").font(.subheadline.weight(.semibold))
            TextField("Describe sample content", text: $model.sampleText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.evaluate() }
            Text(settings.developerMode ? LocalizedStringKey(model.outcomeSummary) : Present.shieldOutcome(model.lastOutcome))
                .font(.footnote.monospaced())
                .foregroundStyle(model.lastOutcome.layerDecision == .execute ? .red : .primary)
            Button("Evaluate") { model.evaluate() }
                .frame(minHeight: GTokens.minTouch).buttonStyle(.bordered)
        }
    }

    private var ruleComposer: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Text("Add a shield rule").font(.subheadline.weight(.semibold))
            TextField("Word, phrase, concept, source…", text: $model.draftLabel)
                .textFieldStyle(.roundedBorder)
            Picker("Type", selection: $model.draftType) {
                Text("Exact text").tag(ShieldInputType.textExact)
                Text("Concept").tag(ShieldInputType.semanticConcept)
                Text("Entity").tag(ShieldInputType.entity)
                Text("Sound class").tag(ShieldInputType.soundClass)
            }.pickerStyle(.segmented)
            Picker("Action", selection: $model.draftAction) {
                Text("Warn").tag(ShieldAction.warn)
                Text("Ask").tag(ShieldAction.ask)
                // §1.1 — HIDE is NOT offered for a sound rule: a classifier label is not calibrated risk, so a
                // soundClass/audioReference rule may only WARN/ASK. The option is hidden up front (the store boundary
                // ALSO downgrades it, but preventing the selection explains the limit instead of surprising the user).
                if !SoundRuleSafetyV1.isSoundInput(model.draftType) {
                    Text("Hide").tag(ShieldAction.hideIfControlled)
                }
            }.pickerStyle(.segmented)
            // §1.1 — if the user had HIDE selected and then switched to a sound type, snap the draft action back to a
            // safe value so the (now-hidden) HIDE tag can't linger as the selection.
            .onChange(of: model.draftType) { _, newType in
                if SoundRuleSafetyV1.isSoundInput(newType),
                   SoundRuleSafetyV1.disallowedSoundActions.contains(model.draftAction) {
                    model.draftAction = .warn
                }
            }
            if SoundRuleSafetyV1.isSoundInput(model.draftType) {
                Text("Ses sınıfı kuralları yalnızca UYAR/SOR olabilir (ses etiketi kalibre risk değildir).")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Button("Add rule") { model.addDraft() }
                .frame(maxWidth: .infinity, minHeight: GTokens.minTouch).buttonStyle(.borderedProminent)
        }
        .padding(GTokens.s4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
    }

    @ViewBuilder private func ruleRow(_ rule: ShieldRuleV2) -> some View {
        let state = model.functionalState(rule)
        HStack {
            VStack(alignment: .leading) {
                Text(rule.rawUserLabel).font(.callout)
                if settings.developerMode {
                    Text("\(rule.inputType.rawValue) · \(rule.action.rawValue) · \(state.rawValue)")
                        .font(.caption2).foregroundStyle(state == .active ? Color.secondary : Color.orange)
                } else {
                    HStack(spacing: 4) {
                        Text(Present.inputType(rule.inputType)); Text("·"); Text(Present.action(rule.action))
                        Text("·"); Text(Present.ruleState(state))
                    }
                    .font(.caption2).foregroundStyle(state == .active ? Color.secondary : Color.orange)
                }
                // 006C §12 — reference needs re-authoring: rule still exists, protection currently unavailable.
                if model.needsReauthoring(rule) {
                    Text("Protection unavailable — Update reference")
                        .font(.caption2).foregroundStyle(.orange)
                }
                // §1.1 — VISIBLE downgrade flag: this sound rule's unsafe HIDE action was limited to WARN at the
                // store boundary (never silent). The downgrade is a safety guarantee, not a failure hidden from the UI.
                if model.isDowngraded(rule) {
                    Text("Ses kuralı güvenlik için UYAR'a sınırlandı (gizleme sese uygulanamaz).")
                        .font(.caption2).foregroundStyle(.orange)
                }
            }
            Spacer()
            Button(role: .destructive) { model.delete(rule) } label: { Image(systemName: "trash") }
                .frame(minWidth: GTokens.minTouch, minHeight: GTokens.minTouch)
        }
    }

    private var ruleList: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Text("Active rules (\(model.ruleCount))").font(.subheadline.weight(.semibold))
            // A2 — starter examples are offered ONLY on a genuine first run (healthy, never-seeded, empty store) and
            // ONLY via this explicit choice. After a delete-all the shield stays empty; this prompt never reappears.
            if model.isGenuineFirstRun {
                VStack(alignment: .leading, spacing: GTokens.s1) {
                    Text("Kalkanın şu an boş.").font(.footnote.weight(.medium))
                    Text("İstersen örnek kurallarla başlayabilirsin; dilediğin zaman düzenleyip silebilirsin.")
                        .font(.caption2).foregroundStyle(.secondary)
                    Button("Örnek kurallarla başla") { model.seedStarterRulesIfUserChooses() }
                        .font(.caption).frame(minHeight: GTokens.minTouch).buttonStyle(.bordered)
                }
                .padding(GTokens.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
            }
            ForEach(model.rules, id: \.ruleID) { rule in
                ruleRow(rule)
            }
            storageFooter
        }
    }

    // B1 — HONEST storage + deletion controls. States WHERE rules live (shared App Group vs app-private) and lets
    // the user delete everything on-device. The policy version is shown as a plain number (no numeric content score).
    private var storageFooter: some View {
        VStack(alignment: .leading, spacing: GTokens.s2) {
            Divider()
            HStack(spacing: 4) {
                Image(systemName: model.sharedContainerActive ? "externaldrive.badge.checkmark" : "externaldrive.badge.exclamationmark")
                    .foregroundStyle(model.sharedContainerActive ? .green : .orange)
                Text(model.sharedContainerActive
                     ? "Kurallar cihazda, paylaşımlı kasada saklanıyor (yayın uzantısı okuyabiliyor)."
                     : "Paylaşımlı kasa yok — kurallar yalnızca uygulamada; başka uygulamada koruma iddia edilemez.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Text("Politika sürümü: \(model.policyRevision)")
                .font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
            Button(role: .destructive) { model.deleteAll() } label: {
                Label("Tüm kuralları sil", systemImage: "trash")
                    .frame(maxWidth: .infinity, minHeight: GTokens.minTouch)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, GTokens.s2)
    }
}
