import Foundation

// MARK: - Bounded Next +1/+2/+3 look-ahead scheduler (structured concurrency, cancellable)
// Ref: Build Bible §15(Prompt 000), §617; PROMPT 001 §11, §16, §27.
// Invariants: ≤3 look-ahead, dedupe by ContentID, stale-candidate cancellation on advance,
// no redundant analysis of the same ContentID, no unbounded Task spawning, cache-first.

public actor LookAheadScheduler {
    private let pipeline: PreExposurePipeline
    private let diagnostics: Diagnostics
    private let maxLookAhead: Int
    private var profile: PersonalAlgorithmProfile
    private var safety: SafetyPolicy
    private var pending: [ContentCandidate] = []
    private var decisions: [ContentID: AdmissionDecision] = [:]

    public init(pipeline: PreExposurePipeline, diagnostics: Diagnostics,
                profile: PersonalAlgorithmProfile, safety: SafetyPolicy = .init(), maxLookAhead: Int = 3) {
        self.pipeline = pipeline
        self.diagnostics = diagnostics
        self.profile = profile
        self.safety = safety
        self.maxLookAhead = maxLookAhead
    }

    public func setProfile(_ p: PersonalAlgorithmProfile) { profile = p }

    /// Replace the look-ahead window. Stale (dropped, not-yet-decided) candidates are cancelled.
    /// V1 (002A §12): `maxDepth` lets the ResourceGovernor shrink the window (e.g. ECO → 1).
    public func update(candidates: [ContentCandidate], maxDepth: Int? = nil) {
        let ranked = rank(candidates, depth: maxDepth ?? maxLookAhead)
        let keep = Set(ranked.map { $0.id })
        for p in pending where !keep.contains(p.id) && decisions[p.id] == nil {
            diagnostics.recordCancellation()
        }
        var next: [ContentCandidate] = []
        for c in ranked {
            if decisions[c.id] != nil { diagnostics.recordDuplicatePrevented(); continue }    // no redundant analysis
            if next.contains(where: { $0.id == c.id }) { continue }
            next.append(c)
        }
        pending = next
        diagnostics.recordConcurrentTasks(pending.count)   // bounded by maxLookAhead
    }

    /// Process the current pending window concurrently with a BOUNDED structured task group.
    public func pump() async {
        let batch = pending
        guard !batch.isEmpty else { return }
        let pipeline = self.pipeline
        let profile = self.profile
        let safety = self.safety
        var produced: [(ContentID, AdmissionDecision)] = []
        await withTaskGroup(of: (ContentID, AdmissionDecision).self) { group in
            for c in batch {                                  // ≤ maxLookAhead children — bounded
                group.addTask {
                    let r = await pipeline.decide(candidate: c, profile: profile, safety: safety)
                    return (c.id, r.decision)
                }
            }
            for await pair in group { produced.append(pair) }
        }
        for (id, d) in produced { decisions[id] = d }
        pending.removeAll { p in produced.contains { $0.0 == p.id } }
    }

    public func decision(for id: ContentID) -> AdmissionDecision? { decisions[id] }
    public func decidedCount() -> Int { decisions.count }
    public func pendingCount() -> Int { pending.count }

    // Deadline-aware ranking (002A §12): imminent deadline first, then higher exposure likelihood.
    private func rank(_ candidates: [ContentCandidate], depth: Int) -> [ContentCandidate] {
        var byID: [ContentID: ContentCandidate] = [:]
        for c in candidates {
            if let e = byID[c.id] {
                if c.nextExposureLikelihood > e.nextExposureLikelihood { byID[c.id] = c }
            } else {
                byID[c.id] = c
            }
        }
        let sorted = byID.values.sorted { a, b in
            switch (a.decisionDeadlineNanos, b.decisionDeadlineNanos) {
            case let (x?, y?): return x != y ? x < y : a.nextExposureLikelihood > b.nextExposureLikelihood
            case (_?, nil):   return true                       // has deadline → more urgent
            case (nil, _?):   return false
            case (nil, nil):  return a.nextExposureLikelihood > b.nextExposureLikelihood
            }
        }
        return Array(sorted.prefix(max(0, depth)))
    }
}
