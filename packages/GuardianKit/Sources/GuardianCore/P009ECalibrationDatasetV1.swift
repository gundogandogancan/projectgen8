import Foundation

// MARK: - P009E §7/§8 — calibration dataset registry: item×profile pairs, dual-annotated, split-disjoint
// at ITEM level. Source classes are declared per item; EVERYTHING here is SYNTHETIC_DERIVED or
// STRUCTURAL_ONLY → real-world claims structurally unsupported (ENGINEERING_CALIBRATION_ONLY).
// The P009B CAL_RESERVED bank (fingerprint aa6bd546ae28278f, content-locked) is consumed here for the
// FIRST time — in the CALIBRATION split only, as its reservation always intended.

public enum CalibrationDatasetRegistryV1 {
    public static let version = "p009e-calibration-dataset-v1"

    static func pair(_ item: String, _ corpus: String, _ p: ProfileFixtureV1, _ split: CalibrationSplitV1,
                     _ la: Int, _ lb: Int, locale: String, source: CalibrationSourceClassV1 = .syntheticDerived,
                     adjudicated: Int? = nil) -> CalibrationPairV1 {
        CalibrationPairV1(itemID: item, corpus: corpus, profile: p, split: split, source: source,
                          annotation: CalibrationAnnotationV1(itemID: item, profileID: p.profileID, locale: locale,
                                                              labelA: la, labelB: lb, adjudicated: adjudicated))
    }

    /// Item-level split disjointness is LAW: an item name appears in exactly one split (test-asserted).
    public static let pairs: [CalibrationPairV1] = {
        var out: [CalibrationPairV1] = []
        let A = ProfileFixtureV1.adultNeutral, S = ProfileFixtureV1.adultShieldMortality
        let C9 = ProfileFixtureV1.parentChild9TR, T14 = ProfileFixtureV1.parentTeen14TR
        // ── TRAIN_TUNE (items from P009D tune + P009C tune — distinct names) ──
        out += [
            pair("pd-educational-graphic", "P009D", A, .trainTune, 2, 2, locale: "en"),
            pair("pd-educational-graphic", "P009D", C9, .trainTune, 1, 0, locale: "en", adjudicated: 1),
            pair("pd-mortality-education-adult", "P009D", A, .trainTune, 3, 2, locale: "en"),
            pair("pd-mortality-education-adult", "P009D", S, .trainTune, 1, 1, locale: "en"),
            pair("pd-sensitive-news-adult", "P009D", A, .trainTune, 1, 1, locale: "tr"),
            pair("pd-sensitive-news-adult", "P009D", C9, .trainTune, 0, 0, locale: "tr"),
            pair("pd-severe-violence-lexical", "P009D", A, .trainTune, 0, 1, locale: "tr", adjudicated: 0),
            pair("pd-severe-violence-lexical", "P009D", C9, .trainTune, 0, 0, locale: "tr"),
            pair("pd-child-fear", "P009D", C9, .trainTune, 1, 1, locale: "tr"),
            pair("pd-child-fear", "P009D", A, .trainTune, 2, 3, locale: "tr"),
            pair("pd-persuasive-ad", "P009D", A, .trainTune, 2, 1, locale: "en"),
            pair("pd-persuasive-ad", "P009D", C9, .trainTune, 1, 1, locale: "en"),
            pair("pd-manipulative-urgency", "P009D", A, .trainTune, 1, 2, locale: "tr"),
            pair("pd-calm-nature", "P009D", A, .trainTune, 4, 4, locale: "tr"),
            pair("pd-calm-nature", "P009D", T14, .trainTune, 4, 3, locale: "tr"),
            pair("pd-shield-topic-match", "P009D", S, .trainTune, 1, 1, locale: "tr"),
            pair("pd-h1-unavailable-adult-neutral", "P009D", A, .trainTune, 3, 3, locale: "en"),
            pair("pd-multi-policy-conflict", "P009D", C9, .trainTune, 0, 0, locale: "tr"),
            pair("tc-straight-educational", "P009C", A, .trainTune, 4, 3, locale: "en"),
            pair("tc-straight-educational", "P009C", C9, .trainTune, 2, 2, locale: "en"),
            pair("tc-calm-nature", "P009C", A, .trainTune, 4, 4, locale: "tr"),
            pair("tc-sensitive-news", "P009C", A, .trainTune, 1, 1, locale: "tr"),
            pair("tc-benign-then-risky", "P009C", A, .trainTune, 1, 1, locale: "en"),
            pair("tc-risky-then-benign", "P009C", A, .trainTune, 1, 2, locale: "tr"),
            pair("tc-humor", "P009C", A, .trainTune, 3, 3, locale: "en"),
            pair("tc-persuasive-ad-like-urgency", "ALIAS:tc-intent-ambiguity", A, .trainTune, 2, 2, locale: "en"),
        ]
        // ── CALIBRATION (P009B CAL_RESERVED first consumption + P009D heldout names) ──
        out += [
            pair("cal-documentary-tr", "P009B_CAL_RESERVED", A, .calibration, 3, 3, locale: "tr"),
            pair("cal-gameplay-en", "P009B_CAL_RESERVED", A, .calibration, 3, 2, locale: "en"),
            pair("cal-news-flood", "P009B_CAL_RESERVED", A, .calibration, 1, 1, locale: "tr"),
            pair("cal-news-flood", "P009B_CAL_RESERVED", C9, .calibration, 0, 0, locale: "tr"),
            pair("cal-asmr-calm", "P009B_CAL_RESERVED", A, .calibration, 4, 4, locale: "en"),
            pair("cal-debate-mixed", "P009B_CAL_RESERVED", A, .calibration, 2, 2, locale: "tr"),
            pair("cal-cooking-fail", "P009B_CAL_RESERVED", A, .calibration, 3, 3, locale: "en"),
            pair("hd-storm-news-child", "P009D", C9, .calibration, 0, 0, locale: "en"),
            pair("hd-cooking-neutral-adult", "P009D", A, .calibration, 4, 3, locale: "en"),
            pair("hd-teen-sensitive-caution", "P009D", T14, .calibration, 2, 2, locale: "tr"),
            pair("hd-parent-stricter", "P009D", ProfileFixtureV1.parentTeen14Strict, .calibration, 0, 1, locale: "en", adjudicated: 0),
            pair("hd-ocean-calm-alias", "ALIAS:hc-ocean-calm", A, .calibration, 4, 4, locale: "en"),
        ]
        // ── HELD_OUT_FINAL (untouched until frozen; distinct items) ──
        out += [
            pair("hc-educational-cooking", "P009C", A, .heldOutFinal, 4, 4, locale: "en"),
            pair("hc-educational-cooking", "P009C", C9, .heldOutFinal, 2, 2, locale: "en"),
            pair("hc-edu-war-history", "P009C", A, .heldOutFinal, 2, 2, locale: "en"),
            pair("hc-quoted-threat-news", "P009C", A, .heldOutFinal, 2, 1, locale: "tr"),
            pair("hc-urgent-flashsale", "P009C", A, .heldOutFinal, 1, 2, locale: "en", adjudicated: 2),
            pair("hc-wedding-grief-shift", "P009C", A, .heldOutFinal, 1, 1, locale: "tr"),
            pair("hc-storm-recovery", "P009C", A, .heldOutFinal, 1, 1, locale: "en"),
            pair("hc-teach-or-sell", "P009C", A, .heldOutFinal, 2, 2, locale: "tr"),
        ]
        // ── STRESS ──
        out += [
            pair("sd-benefit-flood-vs-strong-risk", "P009D", C9, .stress, 0, 0, locale: "en"),
            pair("sd-many-shield-entries", "P009D", S, .stress, 1, 1, locale: "tr"),
            pair("sc-long-risk-tail", "P009C", A, .stress, 1, 1, locale: "en"),
            pair("sc-correlated-lexical-flood", "P009C", A, .stress, 1, 1, locale: "en"),
        ]
        // ── OOD ──
        out += [
            pair("od-empty-content", "P009D", C9, .ood, 2, 2, locale: "en", source: .structuralOnly),
            pair("od-unsupported-language-child", "P009D", C9, .ood, 2, 2, locale: "ja", source: .structuralOnly),
            pair("oc-poisoned-values", "P009C", A, .ood, 2, 2, locale: "en", source: .structuralOnly),
            pair("od-poisoned-input", "P009D", A, .ood, 2, 2, locale: "en", source: .structuralOnly),
        ]
        // ── SAFETY_SENTINEL (never fitted/tuned; categorical no-false-safe law) ──
        out += [
            pair("a7-teen-sexual-text-equivalent", "P009E_TEEN", T14, .safetySentinel, 0, 0, locale: "en"),
            pair("pd-selfharm-literal-claim", "P009D", C9, .safetySentinel, 0, 0, locale: "en"),
            pair("pd-child-targeted-cta", "P009D", C9, .safetySentinel, 1, 0, locale: "en", adjudicated: 0),
            pair("pd-humor-explicit-claim", "P009D", C9, .safetySentinel, 0, 0, locale: "en"),
            pair("hd-cross-language-en-config-tr-content", "P009D", S, .safetySentinel, 1, 1, locale: "tr"),
        ]
        return out
    }()

    public static func pairs(in split: CalibrationSplitV1) -> [CalibrationPairV1] { pairs.filter { $0.split == split } }
    /// item-level split map for the leakage law
    public static var itemSplitViolations: [String] {
        var seen: [String: CalibrationSplitV1] = [:]
        var v: [String] = []
        for p in pairs {
            let key = p.itemID.replacingOccurrences(of: "ALIAS:", with: "")
            if let s = seen[key], s != p.split { v.append("item-in-two-splits:\(key):\(s.rawValue)+\(p.split.rawValue)") }
            seen[key] = p.split
        }
        return v
    }
    public static var sourceClassCounts: [CalibrationSourceClassV1: Int] {
        Dictionary(grouping: pairs, by: { $0.source }).mapValues { $0.count }
    }
    public static var supportsRealWorldClaims: Bool {
        pairs.contains { $0.source.supportsRealWorldClaims }    // false today — structurally honest
    }
}
