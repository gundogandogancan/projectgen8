import Foundation

// MARK: - TR + EN lexicons (PROMPT 003 §21) — deterministic, inspectable, versioned.
// These are LEXICON_V1 signals, NOT trained models and NOT "AI". Thresholds are per-language.
// Matching is diacritic/case-insensitive word-boundary-ish containment on normalized tokens.

public enum Lexicons {
    public static let version = "lexicon-v1"

    public static let mortality: [String: [String]] = [
        "en": ["death", "died", "dead", "killed", "fatal", "deceased", "passed away", "obituary", "funeral"],
        "tr": ["ölüm", "öldü", "ölü", "vefat", "hayatını kaybetti", "cenaze", "can verdi", "yaşamını yitirdi"]
    ]
    public static let diseaseIllness: [String: [String]] = [
        "en": ["disease", "illness", "cancer", "tumor", "infection", "virus", "diagnosis", "symptoms", "chronic"],
        "tr": ["hastalık", "kanser", "tümör", "enfeksiyon", "virüs", "teşhis", "belirti", "kronik", "rahatsızlık"]
    ]
    public static let disaster: [String: [String]] = [
        "en": ["earthquake", "flood", "wildfire", "hurricane", "tsunami", "disaster", "catastrophe", "famine"],
        "tr": ["deprem", "sel", "yangın", "kasırga", "tsunami", "felaket", "afet", "kıtlık"]
    ]
    public static let severeAccident: [String: [String]] = [
        "en": ["crash", "accident", "collision", "derailment", "explosion", "wreck"],
        "tr": ["kaza", "çarpışma", "patlama", "devrildi", "enkaz", "faciası"]
    ]
    public static let warConflict: [String: [String]] = [
        "en": ["war", "airstrike", "bombing", "conflict", "invasion", "militia", "casualties", "shelling"],
        "tr": ["savaş", "hava saldırısı", "bombardıman", "çatışma", "işgal", "saldırı", "zayiat"]
    ]
    public static let medicalHospital: [String: [String]] = [
        "en": ["hospital", "surgery", "icu", "clinic", "patient", "treatment", "doctor", "nurse"],
        "tr": ["hastane", "ameliyat", "yoğun bakım", "klinik", "hasta", "tedavi", "doktor", "hemşire"]
    ]

    // Manipulation / attention lexicons (H5)
    public static let urgency: [String: [String]] = [
        "en": ["now", "hurry", "last chance", "don't miss", "act fast", "today only", "limited time"],
        "tr": ["şimdi", "acele", "son şans", "kaçırma", "hemen", "sadece bugün", "sınırlı süre"]
    ]
    public static let scarcity: [String: [String]] = [
        "en": ["only", "limited", "few left", "exclusive", "running out", "sold out soon"],
        "tr": ["sadece", "sınırlı", "son", "özel", "tükeniyor", "az kaldı", "stoklarla sınırlı"]
    ]
    public static let fear: [String: [String]] = [
        "en": ["warning", "danger", "shocking", "terrifying", "you won't believe", "disaster", "threat"],
        "tr": ["uyarı", "tehlike", "şok", "korkunç", "inanamayacaksınız", "tehdit", "dikkat"]
    ]
    public static let anger: [String: [String]] = [
        "en": ["outrageous", "disgusting", "scandal", "betrayal", "they lied", "exposed"],
        "tr": ["rezalet", "skandal", "ihanet", "yalan söylediler", "iğrenç", "ifşa"]
    ]
    public static let repeatedCTA: [String: [String]] = [
        "en": ["subscribe", "like and share", "click here", "buy now", "sign up", "follow"],
        "tr": ["abone ol", "beğen ve paylaş", "tıkla", "hemen al", "kaydol", "takip et"]
    ]
    public static let clickbait: [String: [String]] = [
        "en": ["this one trick", "doctors hate", "what happens next", "number 7 will", "gone wrong"],
        "tr": ["bu numara", "doktorlar nefret", "sonra ne oldu", "7 numara", "kötü bitti"]
    ]

    /// Normalize text for matching: lowercase, diacritic-fold, collapse whitespace.
    public static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Count lexicon hits in text for a language (falls back to scanning both if language unknown).
    public static func hits(_ text: String, lexicon: [String: [String]], language: String?) -> [String] {
        let norm = normalize(text)
        let langs = language.map { [$0] } ?? ["en", "tr"]
        var found: [String] = []
        for l in langs {
            for term in lexicon[l] ?? [] {
                if norm.contains(normalize(term)) { found.append(term) }
            }
        }
        return found
    }
}
