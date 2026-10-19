import Foundation

// MARK: - Training Runner V1 (PROMPT 004 §9, §10, §11) — a REAL train→eval→export run.
// Compact architecture: deterministic lexicon features → logistic-regression head (LinearClassifier).
// Honest scope: trained on SYNTHETIC OWNED data to demonstrate the pipeline (ACTIVE_LAB, not production).
// Per-language (TR/EN) eval. Embedding-feature variant is a documented future upgrade.

public struct SyntheticTextSample: Sendable {
    public let text: String
    public let label: Int        // 1 = heavy sensitive topic (mortality/disaster/war/accident)
    public let language: String
    public init(_ text: String, _ label: Int, _ language: String) { self.text = text; self.label = label; self.language = language }
}

public struct TrainingRunResult: Sendable, Codable, Equatable {
    public var datasetVersion: String
    public var featureKind: String
    public var seedNote: String
    public var epochs: Int
    public var overall: ClassifierMetrics
    public var english: ClassifierMetrics
    public var turkish: ClassifierMetrics
    public var baselineF1: Double
    public var modelChecksum: String
    public var modelVersion: String
}

public struct TrainingRunnerV1: Sendable {
    public static let version = "training-runner-v1"
    public static let featureDim = 6     // 6 MDD lexicon categories
    public init() {}

    /// Deterministic 6-dim feature vector = normalized lexicon category hit counts.
    public func features(_ text: String, language: String) -> [Double] {
        func c(_ lex: [String: [String]]) -> Double { Double(Lexicons.hits(text, lexicon: lex, language: language).count) }
        let raw = [c(Lexicons.mortality), c(Lexicons.diseaseIllness), c(Lexicons.disaster),
                   c(Lexicons.severeAccident), c(Lexicons.warConflict), c(Lexicons.medicalHospital)]
        let maxv = max(1.0, raw.max() ?? 1.0)
        return raw.map { $0 / maxv }
    }

    public func toExamples(_ samples: [SyntheticTextSample]) -> [TrainingExample] {
        samples.map { TrainingExample(features: features($0.text, language: $0.language), label: $0.label, language: $0.language) }
    }

    /// Run the full train/eval loop on a provided dataset with a deterministic index-based split.
    public func run(_ samples: [SyntheticTextSample], datasetVersion: String, epochs: Int = 400) -> (model: LinearClassifier, result: TrainingRunResult) {
        let all = toExamples(samples)
        // Deterministic split: idx%5==0 → test, idx%5==1 → val, else train.
        var train: [TrainingExample] = [], test: [TrainingExample] = []
        for (i, e) in all.enumerated() { if i % 5 == 0 { test.append(e) } else { train.append(e) } }
        var model = LinearClassifier(featureDim: Self.featureDim)
        model.train(train, epochs: epochs)
        let overall = model.evaluate(test)
        let en = model.evaluate(test.filter { $0.language == "en" })
        let tr = model.evaluate(test.filter { $0.language == "tr" })
        // Majority-class baseline F1 on test.
        let pos = test.filter { $0.label == 1 }.count
        let baseline = test.isEmpty ? 0 : (Double(pos) / Double(test.count) >= 0.5 ? majorityF1(posFraction: Double(pos)/Double(test.count)) : 0)
        let result = TrainingRunResult(datasetVersion: datasetVersion, featureKind: "lexicon-6d",
                                       seedNote: "deterministic (zero-init, fixed split)", epochs: epochs,
                                       overall: overall, english: en, turkish: tr, baselineF1: baseline,
                                       modelChecksum: model.checksum(), modelVersion: model.version)
        return (model, result)
    }

    private func majorityF1(posFraction: Double) -> Double {
        // Always-predict-positive F1 = 2p/(1+p) where p = recall=1, precision=posFraction.
        let prec = posFraction, rec = 1.0
        return prec + rec == 0 ? 0 : 2*prec*rec/(prec+rec)
    }

    /// Small, legally-safe SYNTHETIC OWNED dataset (TR + EN). No scraped/private/child data.
    public static func goldenTextDataset() -> [SyntheticTextSample] {
        [
            // heavy sensitive (label 1) — EN
            .init("A massive earthquake killed dozens in the region.", 1, "en"),
            .init("Breaking: airstrike and shelling cause heavy casualties.", 1, "en"),
            .init("A fatal car crash on the highway this morning.", 1, "en"),
            .init("Flood and wildfire disaster devastated the town.", 1, "en"),
            .init("Obituary: he passed away after a long illness.", 1, "en"),
            // heavy sensitive (label 1) — TR
            .init("Şiddetli deprem bölgede çok sayıda ölüme yol açtı.", 1, "tr"),
            .init("Hava saldırısı ve bombardıman ağır zayiata neden oldu.", 1, "tr"),
            .init("Otoyolda ölümlü bir trafik kazası yaşandı.", 1, "tr"),
            .init("Sel ve yangın felaketi kasabayı harap etti.", 1, "tr"),
            .init("Uzun bir hastalığın ardından vefat etti.", 1, "tr"),
            // non-heavy (label 0) — EN
            .init("A friendly tutorial about Swift concurrency and actors.", 0, "en"),
            .init("Ten tips to improve your morning productivity routine.", 0, "en"),
            .init("A relaxing travel vlog through the mountains.", 0, "en"),
            .init("How to bake sourdough bread at home, step by step.", 0, "en"),
            .init("An interview about creative writing and storytelling.", 0, "en"),
            // non-heavy (label 0) — TR
            .init("Swift eşzamanlılık ve aktörler hakkında dostça bir rehber.", 0, "tr"),
            .init("Sabah verimliliğinizi artıracak on ipucu.", 0, "tr"),
            .init("Dağlarda huzurlu bir gezi günlüğü.", 0, "tr"),
            .init("Evde adım adım ekşi mayalı ekmek yapımı.", 0, "tr"),
            .init("Yaratıcı yazarlık üzerine keyifli bir söyleşi.", 0, "tr")
        ]
    }
}
