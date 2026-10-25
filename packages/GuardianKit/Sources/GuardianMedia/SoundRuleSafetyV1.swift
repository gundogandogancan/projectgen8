//
//  SoundRuleSafetyV1.swift — §1.1: SOUND-CLASS RULES ARE SAFE AT EVERY ENTRY POINT (the store boundary law).
//
//  THE DEFECT (mandate §1.1): the general rule composer (MyShieldView.ruleComposer) lets the user bind a
//  `.soundClass` rule to `.hideIfControlled` (an "execute"/destructive action). A classifier LABEL is NOT a
//  calibrated risk; it must NEVER drive a hard-to-reverse auto-HIDE/MUTE/SKIP on its OWN (constitution 8/15 —
//  a raw model number is not a verdict). The old audio-preference path (ShieldStudioModel.addAudioPreference)
//  already restricted to WARN/ASK, but `addRule` and any legacy/hand-authored rule could still smuggle a
//  soundClass+HIDE rule into the durable store, where BOTH the app AND the broadcast extension would then honour
//  it. A UI-only guard is insufficient — the mandate is explicit the boundary must be the STORE, not the UI.
//
//  THE LAW (enforced here, consumed by PersonalShieldSharedStoreV1 on save AND load, and by the Personal Learning
//  proposal validator): a `.soundClass` (or `.audioReference`) rule whose action is a controlled EXECUTE action
//  (hide/blur/mute/skip) is DOWNGRADED to WARN. The downgrade is VISIBLE (never silent): the rule's rawUserLabel
//  carries no change, but the function returns the list of rule IDs it downgraded so the UI (MyShieldView) can show
//  a flag and the composer can prevent the selection up front. Downgrade-on-save means a freshly composed unsafe
//  rule is stored safe; downgrade-on-load means a LEGACY rule already on disk is handled safely too (and a visible
//  flag is produced for it) without ever editing the frozen FileBackedPersonalShieldStore.
//
//  WHY A PURE TYPE: the validator is a pure function over value types (no store, no I/O), so it is deterministic and
//  unit-testable in isolation, and the SAME validator is reused by the store boundary and by the Personal Learning
//  proposal engine (mandate §1.1 final sentence: "the same validation on Personal Learning proposals").
//
import Foundation
import GuardianCore

public enum SoundRuleSafetyV1 {
    /// §1.1 — the controlled EXECUTE actions a sound-class rule may NOT carry on its own (destructive / hard to
    /// reverse from a non-calibrated classifier label). WARN/ASK/ALLOW* stay allowed (reversible, non-destructive).
    public static let disallowedSoundActions: Set<ShieldAction> =
        [.hideIfControlled, .blurIfControlled, .muteIfControlled, .skipIfControlledAndAligned]

    /// §1.1 — the input types this law governs: a classifier/acoustic label is not calibrated risk.
    public static func isSoundInput(_ t: ShieldInputType) -> Bool { t == .soundClass || t == .audioReference }

    /// §1.1 — is this rule an UNSAFE sound rule (a sound input bound to a controlled execute action)?
    public static func isUnsafeSoundRule(_ r: ShieldRuleV2) -> Bool {
        isSoundInput(r.inputType) && disallowedSoundActions.contains(r.action)
    }

    /// §1.1 — the single safe action a downgraded sound rule lands on: WARN (visible, reversible, non-destructive).
    public static let downgradeAction: ShieldAction = .warn

    /// §1.1 — return a SAFE copy of a rule: if it is an unsafe sound rule, its action is downgraded to WARN; every
    /// other rule is returned unchanged. Pure. The `updatedAtEpoch` is deliberately NOT touched here (the store owns
    /// durability stamps) so the downgrade is purely a safety projection, not a user-visible "edit".
    public static func sanitized(_ r: ShieldRuleV2) -> ShieldRuleV2 {
        guard isUnsafeSoundRule(r) else { return r }
        var safe = r
        safe.action = downgradeAction
        return safe
    }

    /// §1.1 — sanitize a whole rule set. Returns (sanitizedRules, downgradedRuleIDs). The ID list is the VISIBLE flag
    /// surface: the UI shows "this sound rule was limited to WARN"; it is never an empty silent change. Deterministic.
    public static func sanitize(_ rules: [ShieldRuleV2]) -> (rules: [ShieldRuleV2], downgradedRuleIDs: [String]) {
        var out: [ShieldRuleV2] = []
        var downgraded: [String] = []
        out.reserveCapacity(rules.count)
        for r in rules {
            if isUnsafeSoundRule(r) { downgraded.append(r.ruleID); out.append(sanitized(r)) }
            else { out.append(r) }
        }
        return (out, downgraded)
    }
}
