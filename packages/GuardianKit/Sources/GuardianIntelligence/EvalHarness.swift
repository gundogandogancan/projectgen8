import Foundation
import GuardianCore

// MARK: - Evaluation Harness V1 (PROMPT 002 §15 / 002A §9)
// Per-task metrics — NEVER one fake "AI accuracy". Emits a machine-readable JSON artifact.
// Abstentions (UNKNOWN) are counted separately, never as hidden positives.

public struct EvalSample: Sendable {
    public enum Task: String, Sendable, Codable { case identity, language, ocr }
    public let id: String
    public let task: Task
    public let text: String?            // for language
    public let imageText: String?       // expected OCR text (rendered to a fixture)
    public let expectedLanguage: String?
    public let isSameContent: Bool?     // identity positive/negative control
    public init(id: String, task: Task, text: String? = nil, imageText: String? = nil,
                expectedLanguage: String? = nil, isSameContent: Bool? = nil) {
        self.id = id; self.task = task; self.text = text; self.imageText = imageText
        self.expectedLanguage = expectedLanguage; self.isSameContent = isSameContent
    }
}

public struct TaskMetrics: Codable, Sendable {
    public var task: String
    public var n: Int
    public var correct: Int
    public var abstentions: Int
    public var accuracyExclAbstentions: Double   // correct / (n - abstentions)
    public var note: String
}

public struct EvalResults: Codable, Sendable {
    public var schema = "eval-results-v1"
    public var perTask: [TaskMetrics]
    public var overallNote = "Per-task only. No aggregate 'AI accuracy'. Metrics are LAB/fixture-level."
}

public struct EvalHarness: Sendable {
    public init() {}

    public func run(_ samples: [EvalSample]) async -> EvalResults {
        var byTask: [EvalSample.Task: (n: Int, correct: Int, abst: Int)] = [:]
        let nl = NLTextSignalProvider()
        #if canImport(Vision)
        let ocr = VisionOCRProvider()
        let fp = VisionFeatureProvider()
        #endif

        for s in samples {
            var e = byTask[s.task] ?? (0,0,0); e.n += 1
            switch s.task {
            case .language:
                let out = await nl.identify(s.text ?? "")
                if out.state != .ok { e.abst += 1 }
                else if out.value?.language == s.expectedLanguage { e.correct += 1 }
            case .ocr:
                #if canImport(Vision)
                if let expected = s.imageText, let img = SyntheticImage.textImage(expected) {
                    let out = ocr.recognizeText(cgImage: img)
                    if out.state != .ok { e.abst += 1 }
                    else if (out.value?.text ?? "").uppercased().contains(expected.uppercased().split(separator: " ").first.map(String.init) ?? expected.uppercased()) { e.correct += 1 }
                } else { e.abst += 1 }
                #else
                e.abst += 1
                #endif
            case .identity:
                #if canImport(Vision)
                if let same = s.isSameContent,
                   let a = SyntheticImage.textImage("ALPHA REFERENCE CONTENT") {
                    let b = same ? SyntheticImage.textImage("ALPHA REFERENCE CONTENT")
                                 : SyntheticImage.solidImage(gray: 0.15)
                    if let b, let d = fp.distance(a, b) {
                        let predictedSame = d < 1.0
                        if predictedSame == same { e.correct += 1 }
                    } else { e.abst += 1 }
                } else { e.abst += 1 }
                #else
                e.abst += 1
                #endif
            }
            byTask[s.task] = e
        }

        let per = byTask.map { (task, v) -> TaskMetrics in
            let denom = max(1, v.n - v.abst)
            return TaskMetrics(task: task.rawValue, n: v.n, correct: v.correct, abstentions: v.abst,
                               accuracyExclAbstentions: Double(v.correct) / Double(denom),
                               note: "fixture-level; abstentions excluded from accuracy")
        }.sorted { $0.task < $1.task }
        return EvalResults(perTask: per)
    }

    /// Default tiny, legally-safe, synthetic golden set (Golden Dataset v0, §14).
    public static func goldenV0() -> [EvalSample] {
        [
            .init(id: "lang-en", task: .language, text: "The quick brown fox jumps over the lazy dog.", expectedLanguage: "en"),
            .init(id: "lang-tr", task: .language, text: "Bugün hava çok güzel ve kuşlar şarkı söylüyor.", expectedLanguage: "tr"),
            .init(id: "ocr-1", task: .ocr, imageText: "GUARDIAN LEARNING"),
            .init(id: "ocr-2", task: .ocr, imageText: "ATTENTION FIRST"),
            .init(id: "id-pos", task: .identity, isSameContent: true),
            .init(id: "id-neg", task: .identity, isSameContent: false)
        ]
    }
}
