//
//  Presentation.swift — localized, user-friendly labels for internal canonical codes (PROMPT 007C)
//  The internal reason codes / enums are NOT changed; this is a presentation-only mapping (TR/EN via Localizable.xcstrings).
//  Raw codes (TEXT_EXACT, MATCH_LOW, NO_SHIELD_ACTION, …) are shown only in Developer Mode.
//
import SwiftUI
import GuardianCore

enum Present {
    static func inputType(_ t: ShieldInputType) -> LocalizedStringKey {
        switch t {
        case .textExact, .textPhrase: return "Exact text"
        case .semanticConcept: return "Concept"
        case .entity: return "Entity"
        case .source: return "Source"
        case .soundClass, .audioReference: return "Sound class"
        case .imageReference, .logoReference: return "Image"
        case .musicTrack, .musicArtist: return "Music"
        case .spokenReference: return "Spoken"
        case .customMultimodal: return "Custom"
        }
    }
    static func action(_ a: ShieldAction) -> LocalizedStringKey {
        switch a {
        case .allow, .allowWithNote: return "Allow"
        case .warn: return "Warn"
        case .ask: return "Ask"
        case .hideIfControlled, .blurIfControlled, .muteIfControlled, .skipIfControlledAndAligned: return "Hide"
        }
    }
    static func ruleState(_ s: ShieldRuleFunctionalState) -> LocalizedStringKey {
        switch s {
        case .active: return "Active"
        case .paused: return "Paused"
        case .expired: return "Expired"
        case .referenceReauthoringRequired: return "Update reference"
        case .matcherUnavailable: return "Unavailable"
        case .corrupt: return "Needs repair"
        case .migrating: return "Updating…"
        }
    }
    /// Friendly one-line outcome for the Shield sample tester (no raw codes).
    static func shieldOutcome(_ d: PersonalShieldDecision) -> LocalizedStringKey {
        switch d.layerDecision {
        case .noShieldAction: return "No match"
        case .note: return "Allowed (low confidence)"
        case .warn: return "Heads-up"
        case .ask: return "Ask first"
        case .execute: return "Matches your Shield"
        case .noShieldDecision: return "Unknown"
        }
    }
}
