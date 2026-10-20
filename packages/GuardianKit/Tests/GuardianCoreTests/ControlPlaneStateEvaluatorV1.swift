import Foundation

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// ULU EVREN — ControlPlaneStateEvaluatorV1 (A12-F4 closure).
// Minimal deterministic state engine for Project-Twin validation. CONTROL-PLANE TOOLING ONLY:
// lives in the test target, zero app-runtime coupling, pure Foundation, operates on parsed JSON
// dictionaries so mutation tests can run on in-memory copies without touching canonical files.
//
// LAWS ENCODED (machine, not prose):
//  - Typed dependency satisfaction (dependency_contracts): LOCKED | GATE_PASS | CANDIDATE_READY.
//    There is NO global "ACTIVE == satisfied" rule. CANDIDATE_READY is one declared special edge
//    and additionally demands candidate evidence on the dependency.
//  - Gate satisfaction (gates registry), blocker law, requirement-mapping completeness,
//    forbidden global locks — all part of computed readiness.
//  - Truth-transition legality incl. CONTRADICTED-needs-resolution and axis-specific evidence.
//  - Verdict↔status coherence (a FAIL/FIX verdict can never sit under LOCKED without resolution).
// Computed readiness must equal declared status; a snapshot `status: READY` alone is never
// authoritative (validator CP12 enforces the equality).
// ═══════════════════════════════════════════════════════════════════════════════════════════════

enum ControlPlaneStateEvaluatorV1 {
    static let version = "control-plane-state-evaluator-v1"

    // Blocker registry statuses that COUNT AS BLOCKING for readiness (flagged-but-accepted
    // limitation classes do not block by themselves; they are carried visibly).
    static let blockingStatuses: Set<String> = ["OPEN", "STALE_LEDGER"]
    static let acceptedLimitationStatuses: Set<String> = ["OPEN_BY_DESIGN", "OPEN_CONTAINED", "CARRIED", "OPEN_SCOPE_LIMITATION"]

    // Axis → evidence-class compatibility (A12-F4: axis-blind checks forbidden).
    // A VERIFIED/VERIFIED_WITH_LIMITATIONS claim on an axis requires at least one ref of a
    // compatible class; human_product has NO available evidence class yet → never upgradable now.
    static let axisEvidenceLaw: [String: [String]] = [
        "functional": ["implementation.refs", "tests.refs", "evidence.implementation_refs", "evidence.test_refs"],
        "calibration": ["evidence.calibration_refs"],
        "real_device": ["evidence.device_refs"],
        "privacy": ["audit.refs", "evidence.audit_refs"],
        "security": ["audit.refs", "evidence.audit_refs"],
        "resource_performance": ["evidence.device_refs"],
        "human_product": [],
        "overall": ["implementation.refs", "tests.refs", "audit.refs", "evidence.implementation_refs",
                    "evidence.test_refs", "evidence.audit_refs", "evidence.device_refs", "evidence.calibration_refs"],
    ]

    // ── helpers over parsed twin dictionaries ──
    static func s(_ d: [String: Any], _ k: String) -> String { (d[k] as? String) ?? "" }
    static func a(_ d: [String: Any], _ k: String) -> [String] { (d[k] as? [String]) ?? [] }
    static func nodesByID(_ twin: [String: Any]) -> [String: [String: Any]] {
        Dictionary(uniqueKeysWithValues: ((twin["nodes"] as? [[String: Any]]) ?? []).map { (s($0, "id"), $0) })
    }
    static func refs(of node: [String: Any], path: String) -> [String] {
        let parts = path.components(separatedBy: ".")
        if parts.count == 2, let outer = node[parts[0]] as? [String: Any] {
            return (outer[parts[1]] as? [String]) ?? []
        }
        return []
    }

    /// Candidate evidence law for the CANDIDATE_READY edge: the dependency must carry at least one
    /// implementation ref AND one test ref (an audit candidate is implemented, tested artifacts).
    static func hasCandidateEvidence(_ dep: [String: Any]) -> Bool {
        !refs(of: dep, path: "implementation.refs").isEmpty && !refs(of: dep, path: "tests.refs").isEmpty
    }

    static func blockerStatus(_ twin: [String: Any], _ id: String) -> String? {
        ((twin["blockers"] as? [[String: Any]]) ?? []).first { s($0, "id") == id }.map { s($0, "status") }
    }

    /// Typed dependency satisfaction. `passed` = set of node IDs whose required gate/audit has PASSED
    /// (for live state, LOCKED nodes). No status shortcut exists for LOCKED/GATE_PASS contracts.
    static func dependencySatisfied(contract: [String: Any], twin: [String: Any], passed: Set<String>) -> Bool {
        let byID = nodesByID(twin)
        let depID = s(contract, "node")
        guard let dep = byID[depID] else { return false }
        switch s(contract, "requires") {
        case "LOCKED":
            // a LOCK (or simulated pass) is itself the resolution authority for the dependency's
            // carried limitations — its blockers were explicitly accepted at lock time.
            return s(dep, "status") == "LOCKED" || passed.contains(depID)
        case "GATE_PASS":
            return passed.contains(depID) || s(dep, "status") == "LOCKED"
        case "CANDIDATE_READY":
            if passed.contains(depID) { return true }
            let st = s(dep, "status")
            guard st == "ACTIVE" || st == "LOCKED" else { return false }
            // an ACTIVE candidate carrying its own BLOCKING blockers is NOT a lawful candidate
            // (A12 mutation class B: dep ACTIVE with open blocker must not unlock the child)
            for b in a(dep, "blockers") {
                if let bs = blockerStatus(twin, b), blockingStatuses.contains(bs) { return false }
            }
            return hasCandidateEvidence(dep)
        default:
            return false   // unknown contract type is NEVER satisfied (fail closed)
        }
    }

    /// Machine-computed READY set. `passed` lifts gate/audit outcomes for future-state simulation;
    /// for the live snapshot, pass the empty set (LOCKED statuses carry live truth).
    static func computedReady(twin: [String: Any], requirementMap: [String: Any]? = nil,
                              passed: Set<String> = []) -> Set<String> {
        let nodes = (twin["nodes"] as? [[String: Any]]) ?? []
        let contracts = (twin["dependency_contracts"] as? [String: [[String: Any]]]) ?? [:]
        let gates = (twin["gates"] as? [String: [String]]) ?? [:]
        let byID = nodesByID(twin)
        let mappedReqs: Set<String> = {
            guard let m = requirementMap, let recs = m["records"] as? [[String: Any]] else { return [] }
            return Set(recs.map { s($0, "requirement_id") })
        }()
        var ready = Set<String>()
        for n in nodes {
            let id = s(n, "id")
            let status = s(n, "status")
            // READY applies to not-yet-started nodes; ACTIVE is already in progress, LOCKED/RETIRED done.
            guard status != "LOCKED", status != "RETIRED", status != "ACTIVE", !passed.contains(id) else { continue }
            // (1) every typed dependency contract satisfied
            let cl = contracts[id] ?? []
            guard (a(n, "depends_on").count == cl.count),
                  cl.allSatisfy({ dependencySatisfied(contract: $0, twin: twin, passed: passed) }) else { continue }
            // (2) every gate passed
            guard (gates[id] ?? []).allSatisfy({ passed.contains($0) || s(byID[$0] ?? [:], "status") == "LOCKED" }) else { continue }
            // (3) no unresolved BLOCKING blocker on the node itself
            guard a(n, "blockers").allSatisfy({ blockerStatus(twin, $0).map { st in !blockingStatuses.contains(st) } ?? false }) else { continue }
            // (4) requirement mapping complete for the node (when a map is supplied)
            if requirementMap != nil {
                guard a(n, "requirements").allSatisfy({ mappedReqs.contains($0) }) else { continue }
            }
            // (5) prior required audit verdict must not be a standing FAIL
            let verdict = s((n["audit"] as? [String: Any]) ?? [:], "latest_verdict").uppercased()
            guard !(verdict.contains("FIX REQUIRED") || verdict.hasPrefix("FAIL")) else { continue }
            // (6) forbidden global locks: nothing user-facing/corpus-facing may be READY while the
            //     production score gate is CLOSED in CODE (checked by the caller via code truth; the
            //     graph-side law is encoded as gate/blocker structure on those nodes).
            ready.insert(id)
        }
        return ready
    }

    // ── truth-transition legality (A12-F4: machine, not prose) ──
    struct TransitionContext {
        let hasResolutionRecord: Bool
        let node: [String: Any]
    }
    /// Legal axis transition? CONTRADICTED never silently improves; verified-class targets require
    /// axis-compatible evidence; human_product is never upgradable (no evidence class exists yet).
    static func legalAxisTransition(axis: String, from: String, to: String, ctx: TransitionContext) -> Bool {
        if from == to { return true }
        if from == "CONTRADICTED" && !ctx.hasResolutionRecord { return false }
        if to == "VERIFIED" || to == "VERIFIED_WITH_LIMITATIONS" {
            let classes = axisEvidenceLaw[axis] ?? []
            if classes.isEmpty { return false }           // no evidence class exists for this axis yet
            let has = classes.contains { !refs(of: ctx.node, path: $0).isEmpty }
            if !has { return false }
            if axis == "real_device" && refs(of: ctx.node, path: "evidence.device_refs").isEmpty { return false }
            if axis == "calibration" && refs(of: ctx.node, path: "evidence.calibration_refs").isEmpty { return false }
        }
        return true
    }

    /// Verdict↔status coherence: a standing FAIL/FIX verdict can never sit under LOCKED without a
    /// resolution record (newer builder prose cannot overwrite an audit verdict — FM-003).
    static func verdictStatusCoherent(node: [String: Any], hasResolutionRecord: Bool) -> Bool {
        let verdict = s((node["audit"] as? [String: Any]) ?? [:], "latest_verdict").uppercased()
        let failing = verdict.contains("FIX REQUIRED") || verdict.hasPrefix("FAIL")
        if failing && s(node, "status") == "LOCKED" { return hasResolutionRecord }
        return true
    }

    /// Axis-specific evidence adequacy for the LIVE twin: every verified-class axis claim must carry
    /// a compatible evidence class (A12-F4 axis-blind gap closed). Returns violations.
    static func axisEvidenceViolations(twin: [String: Any]) -> [String] {
        var v: [String] = []
        for n in (twin["nodes"] as? [[String: Any]]) ?? [] {
            guard let truth = n["truth"] as? [String: Any] else { continue }
            for (axis, value) in truth {
                guard let t = value as? String,
                      t == "VERIFIED" || t == "VERIFIED_WITH_LIMITATIONS" else { continue }
                let classes = axisEvidenceLaw[axis] ?? []
                if classes.isEmpty { v.append("\(s(n, "id")).\(axis): no evidence class exists for this axis"); continue }
                if !classes.contains(where: { !refs(of: n, path: $0).isEmpty }) {
                    v.append("\(s(n, "id")).\(axis)=\(t) without compatible evidence class \(classes)")
                }
            }
        }
        return v
    }
}
