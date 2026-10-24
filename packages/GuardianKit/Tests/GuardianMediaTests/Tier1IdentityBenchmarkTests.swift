//
//  Tier1IdentityBenchmarkTests.swift — P010 FALSIFICATION HARNESS for Tier-1 item identity.
//
//  PURPOSE (mandatory falsification step): measure, on a reproducible rights-clear synthetic fixture,
//  whether the Tier-1 prototype (Vision feature print + OCR trigram + tie-break fusion) SEPARATES
//  SAME-item internal cuts from NEW-item boundaries better than the frozen Tier-0 cheap channels —
//  which the device run (P009A_R2_MEASURED_TIER0_RESULTS.md, Outcome C) proved NOT safely separable.
//
//  FIXTURE LAW: project-owned rendered frames only (SyntheticVideo precedent). Items are distinct scenes
//  (hue/layout/caption words); internal cuts are visually AGGRESSIVE (brightness jitter, moved subjects)
//  to reproduce the measured overlap mechanism; two deliberate bright-to-bright near-collision item pairs
//  reproduce the C6 false-merge mechanism; constant top/bottom chrome bars reproduce shared app UI.
//
//  EVIDENCE CLASS: LAB_MEASURED_SYNTHETIC. Numbers here are synthetic-fixture numbers — honest tier label,
//  never device truth. The Tier-0 feature pass below is a labeled PROXY copy of SampleHandler.segmentFrame
//  (the extension target is not importable from SwiftPM tests); the grouping brain itself is the REAL
//  frozen engine (ContentItemGroupingEngineV2, .frozenTier0, .extensionFastTier0).
//
import XCTest
import CoreGraphics
import CoreText
import GuardianCore
import GuardianIntelligence
@testable import GuardianMedia
#if canImport(Vision)

final class Tier1IdentityBenchmarkTests: XCTestCase {

    // MARK: deterministic fixture

    private struct Lcg {
        var s: UInt64
        mutating func next() -> Double {   // xorshift64* — deterministic across platforms
            s ^= s >> 12; s ^= s << 25; s ^= s >> 27
            return Double((s &* 2685821657736338717) >> 11) / Double(UInt64(1) << 53)
        }
    }

    private static let itemWords: [[String]] = [
        ["COSMOS", "GALAXY", "STARS"], ["PASTA", "KITCHEN", "RECIPE"], ["HISTORY", "EMPIRE", "BATTLE"],
        ["OCEAN", "CORAL", "DIVING"], ["OCEANIC", "REEF", "SNORKEL"],          // deliberate near-collision pair 3/4
        ["GUITAR", "CHORDS", "MELODY"], ["FITNESS", "WORKOUT", "CARDIO"],
        ["GARDEN", "FLOWERS", "SPRING"], ["GARDENING", "BLOOM", "MEADOW"],     // deliberate near-collision pair 7/8
        ["ROCKET", "ORBIT", "LAUNCH"], ["PAINTING", "CANVAS", "COLORS"], ["CHESS", "OPENING", "ENDGAME"]
    ]
    private static let partWords = ["ONE", "TWO", "THREE", "FOUR", "FIVE"]
    private static let itemCount = 12, shotsPerItem = 5
    private static let W = 480, H = 270

    private static func hsb(_ h: Double, _ s: Double, _ b: Double) -> CGColor {
        let i = Int(h * 6) % 6, f = h * 6 - Double(Int(h * 6))
        let p = b * (1 - s), q = b * (1 - f * s), t = b * (1 - (1 - f) * s)
        let rgb: (Double, Double, Double)
        switch i { case 0: rgb = (b, t, p); case 1: rgb = (q, b, p); case 2: rgb = (p, b, t)
                   case 3: rgb = (p, q, b); case 4: rgb = (t, p, b); default: rgb = (b, p, q) }
        return CGColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    }

    /// Item hue table with two deliberate bright near-collisions (the measured C6 mechanism).
    private static func itemHue(_ i: Int) -> Double {
        if i == 4 { return itemHue(3) + 0.02 }
        if i == 8 { return itemHue(7) + 0.03 }
        return (Double(i) * 0.618034).truncatingRemainder(dividingBy: 1.0)
    }

    private static func caption(item: Int, shot: Int) -> String {
        let w = itemWords[item % itemWords.count]
        return "\(w[0]) \(w[1]) \(w[2]) PART \(partWords[shot % partWords.count])"
    }

    /// Render one shot keyframe. SAME item ⇒ same hue family / subject quadrant / caption words; internal
    /// cuts are visually aggressive (±0.22 brightness, subjects moved/scaled) to reproduce Outcome C overlap.
    private static func renderShot(item: Int, shot: Int) -> CGImage? {
        var rngItem = Lcg(s: UInt64(item) &* 0x9E3779B97F4A7C15 &+ 0xABCD)
        var rngShot = Lcg(s: UInt64(item) &* 1_000_003 &+ UInt64(shot) &* 7_777_777 &+ 0x1234)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let hue = itemHue(item)
        let baseB = 0.55 + (rngItem.next() - 0.5) * 0.2
        let shotB = min(0.95, max(0.15, baseB + (rngShot.next() - 0.5) * 0.44))   // aggressive internal-cut jitter
        ctx.setFillColor(hsb(hue, 0.35, shotB)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        // Item SUBJECT: quadrant + color stable per item; position/scale jitter per shot.
        let quadrant = Int(rngItem.next() * 4) % 4
        let qx = [70, 280, 70, 280][quadrant], qy = [60, 60, 150, 150][quadrant]
        let scale = 0.8 + rngShot.next() * 0.4
        let sw = 150.0 * scale, sh = 95.0 * scale
        let sx = Double(qx) + (rngShot.next() - 0.5) * 60, sy = Double(qy) + (rngShot.next() - 0.5) * 40
        ctx.setFillColor(hsb((hue + 0.5).truncatingRemainder(dividingBy: 1), 0.75, 0.85))
        ctx.fillEllipse(in: CGRect(x: sx, y: sy, width: sw, height: sh))
        // Four item-seeded accent rects with per-shot jitter.
        for _ in 0..<4 {
            let rx = rngItem.next() * Double(W - 60), ry = 35 + rngItem.next() * Double(H - 110)
            let jx = rx + (rngShot.next() - 0.5) * 50, jy = ry + (rngShot.next() - 0.5) * 36
            ctx.setFillColor(hsb((hue + 0.25 + rngItem.next() * 0.2).truncatingRemainder(dividingBy: 1), 0.6, 0.7))
            ctx.fill(CGRect(x: jx, y: jy, width: 34 + rngItem.next() * 30, height: 24 + rngItem.next() * 22))
        }
        // Shared CHROME across ALL items (top + bottom bars + constant dots) — shared-app-UI realism.
        ctx.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1))
        ctx.fill(CGRect(x: 0, y: H - 26, width: W, height: 26))
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: 22))
        ctx.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1))
        for k in 0..<5 { ctx.fillEllipse(in: CGRect(x: 30 + k * 90, y: 6, width: 10, height: 10)) }
        // Caption band + REAL rendered text (the C3 OCR leg reads this back with real Vision OCR).
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.85))
        ctx.fill(CGRect(x: 0, y: 30, width: W, height: 44))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 26, nil)
        let attr = NSAttributedString(string: caption(item: item, shot: shot), attributes: [
            kCTFontAttributeName as NSAttributedString.Key: font,
            kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(red: 1, green: 1, blue: 1, alpha: 1)])
        ctx.textPosition = CGPoint(x: 14, y: 42)
        CTLineDraw(CTLineCreateWithAttributedString(attr), ctx)
        return ctx.makeImage()
    }

    // MARK: Tier-0 PROXY feature pass — labeled copy of SampleHandler.segmentFrame (extension not importable).

    private static func proxySegmentFrame(_ cg: CGImage) -> SegmentFrameV4? {
        let w = cg.width, h = cg.height
        guard w >= 8, h >= 8 else { return nil }
        let cs = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = w * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * h)
        let drawn: Bool = data.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow, space: cs,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        // byte-0 sampling, exactly like the extension's cheap pass on its 4-byte pixels.
        func luma(_ xf: Double, _ yf: Double) -> Int {
            let x = min(w - 1, max(0, Int(xf * Double(w)))), y = min(h - 1, max(0, Int(yf * Double(h))))
            return Int(data[y * bytesPerRow + x * 4])
        }
        func regionHash(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> UInt64 {
            var s = [Int](repeating: 0, count: 64); var total = 0
            for gy in 0..<8 { for gx in 0..<8 {
                let xf = x0 + (x1 - x0) * (Double(gx) + 0.5) / 8, yf = y0 + (y1 - y0) * (Double(gy) + 0.5) / 8
                let v = luma(xf, yf); s[gy * 8 + gx] = v; total += v
            } }
            let mean = total / 64; var bits: UInt64 = 0
            for i in 0..<64 where s[i] >= mean { bits |= (UInt64(1) << UInt64(i)) }
            return bits
        }
        var hist = [0, 0, 0, 0]
        for gy in 0..<8 { for gx in 0..<8 { hist[min(3, luma((Double(gx) + 0.5) / 8, (Double(gy) + 0.5) / 8) / 64)] += 1 } }
        let regions = MultiRegionSignature(
            global: regionHash(0, 0, 1, 1), center: regionHash(0.25, 0.25, 0.75, 0.75),
            top: regionHash(0, 0, 1, 0.25), bottom: regionHash(0, 0.75, 1, 1),
            left: regionHash(0, 0, 0.25, 1), right: regionHash(0.75, 0, 1, 1), lumaHistogram: hist)
        let bins = 8
        var rows = [Double](repeating: 0, count: bins), cols = [Double](repeating: 0, count: bins)
        for b in 0..<bins {
            var rs = 0, csum = 0
            for k in 0..<bins {
                rs += luma((Double(k) + 0.5) / Double(bins), (Double(b) + 0.5) / Double(bins))
                csum += luma((Double(b) + 0.5) / Double(bins), (Double(k) + 0.5) / Double(bins))
            }
            rows[b] = Double(rs) / Double(bins) / 255.0
            cols[b] = Double(csum) / Double(bins) / 255.0
        }
        return SegmentFrameV4(regions: regions, rowProjection: rows, colProjection: cols)
    }

    // MARK: pure fusion-law unit checks (no Vision)

    func testFusionLawPure() {
        let p = Tier1IdentityPolicyV1.v1
        XCTAssertEqual(Tier1IdentityFusionV1.fuse(.init(fpDistance: 0.2, ocrSimilarity: nil, tier0ProjectionCorrelation: nil, tier0StrongNew: false), policy: p).verdict, .sameItem)
        XCTAssertEqual(Tier1IdentityFusionV1.fuse(.init(fpDistance: 1.4, ocrSimilarity: nil, tier0ProjectionCorrelation: nil, tier0StrongNew: false), policy: p).verdict, .newItem)
        // strong-new veto: fp-same may never merge against a confirmed swipe — abstains.
        XCTAssertEqual(Tier1IdentityFusionV1.fuse(.init(fpDistance: 0.2, ocrSimilarity: nil, tier0ProjectionCorrelation: nil, tier0StrongNew: true), policy: p).verdict, .unknown)
        // ambiguous band → OCR tie-break both ways; then projection; then UNKNOWN.
        let mid = (p.fpSameMax + p.fpNewMin) / 2
        XCTAssertEqual(Tier1IdentityFusionV1.fuse(.init(fpDistance: mid, ocrSimilarity: 0.6, tier0ProjectionCorrelation: nil, tier0StrongNew: false), policy: p).verdict, .sameItem)
        XCTAssertEqual(Tier1IdentityFusionV1.fuse(.init(fpDistance: mid, ocrSimilarity: 0.01, tier0ProjectionCorrelation: nil, tier0StrongNew: false), policy: p).verdict, .newItem)
        XCTAssertEqual(Tier1IdentityFusionV1.fuse(.init(fpDistance: mid, ocrSimilarity: nil, tier0ProjectionCorrelation: 0.85, tier0StrongNew: false), policy: p).verdict, .sameItem)
        XCTAssertEqual(Tier1IdentityFusionV1.fuse(.init(fpDistance: mid, ocrSimilarity: nil, tier0ProjectionCorrelation: 0.3, tier0StrongNew: false), policy: p).verdict, .unknown)
        XCTAssertEqual(Tier1IdentityFusionV1.fuse(.init(fpDistance: nil, ocrSimilarity: nil, tier0ProjectionCorrelation: nil, tier0StrongNew: false), policy: p).verdict, .unknown)
        // trigram similarity sanity
        let a = Tier1TextSimilarityV1.trigramHashes("COSMOS GALAXY STARS PART ONE")
        let b = Tier1TextSimilarityV1.trigramHashes("COSMOS GALAXY STARS PART TWO")
        let c = Tier1TextSimilarityV1.trigramHashes("PASTA KITCHEN RECIPE PART ONE")
        XCTAssertGreaterThan(Tier1TextSimilarityV1.jaccard(a, b), 0.5)
        XCTAssertLessThan(Tier1TextSimilarityV1.jaccard(a, c), 0.35)
    }

    // MARK: the measured benchmark

    private struct PairRow {
        let truthNew: Bool
        let theme, hist, chrome, regional, proj: Double
        let fp: Double?
        let ocrJ: Double?
    }

    private func bestThresholdErrors(_ rows: [PairRow], value: (PairRow) -> Double?, newIsHigh: Bool) -> (fm: Int, fs: Int, skipped: Int) {
        // sweep 400 thresholds over observed range; minimize total errors; report FM/FS at the optimum.
        let pts = rows.compactMap { r in value(r).map { (v: $0, n: r.truthNew) } }
        let skipped = rows.count - pts.count
        guard let lo = pts.map(\.v).min(), let hi = pts.map(\.v).max(), hi > lo else { return (0, 0, skipped) }
        var best = (err: Int.max, fm: 0, fs: 0)
        for k in 0...400 {
            let t = lo + (hi - lo) * Double(k) / 400
            var fm = 0, fs = 0
            for p in pts {
                let saysNew = newIsHigh ? p.v >= t : p.v <= t
                if p.n && !saysNew { fm += 1 }
                if !p.n && saysNew { fs += 1 }
            }
            if fm + fs < best.err { best = (fm + fs, fm, fs) }
        }
        return (best.fm, best.fs, skipped)
    }

    func testTier1BeatsTier0OnSyntheticFixture() throws {
        let n = Self.itemCount * Self.shotsPerItem
        var report = ["", "==== P010 TIER-1 SYNTHETIC BENCHMARK (LAB_MEASURED_SYNTHETIC; device-pending) ====",
                      "fixture: \(Self.itemCount) items x \(Self.shotsPerItem) shots = \(n) keyframes (\(Self.W)x\(Self.H)), cut-only transitions (measured Tier-0 failure mode), 2 near-collision item pairs, shared chrome"]

        for run in 1...2 {   // x2 stability: full re-extraction (fresh Vision passes), fresh engines
            var frames: [(item: Int, shot: Int, cg: CGImage, seg: SegmentFrameV4, print: Tier1FeaturePrintV1?, ocr: String?)] = []
            let ocrProvider = VisionOCRProvider()
            for i in 0..<Self.itemCount {
                for s in 0..<Self.shotsPerItem {
                    let cg = try XCTUnwrap(Self.renderShot(item: i, shot: s))
                    let seg = try XCTUnwrap(Self.proxySegmentFrame(cg))
                    let fp = Tier1FeaturePrintExtractorV1.featurePrint(cgImage: cg)
                    let ocr = ocrProvider.recognizeText(cgImage: cg).value?.text
                    frames.append((i, s, cg, seg, fp, (ocr?.isEmpty ?? true) ? nil : ocr))
                }
            }
            let fpOK = frames.filter { $0.print != nil }.count
            let ocrOK = frames.filter { $0.ocr != nil }.count
            XCTAssertGreaterThanOrEqual(fpOK, n * 95 / 100, "feature-print extraction must be near-universal on the fixture")
            report.append(String(format: "run %d: featurePrint ok=%d/%d, realOCR nonempty=%d/%d", run, fpOK, n, ocrOK, n))

            // Timeline: seeded dwell 1.6–4.8 s between committed shots.
            var rng = Lcg(s: 0xFEED5EED)
            var startMs: [Double] = []; var t = 0.0
            for _ in 0..<n { startMs.append(t); t += 1600 + rng.next() * 3200 }

            // (a) PAIR SEPARABILITY — adjacent pairs, every channel vs feature print vs OCR.
            var rows: [PairRow] = []
            for k in 1..<n {
                let a = frames[k - 1], b = frames[k]
                let d = b.seg.regions.distances(to: a.seg.regions)
                let theme = 0.7 * d.center + 0.3 * d.global
                let hist = CrossShotHistogramContinuityV1.distance(b.seg, a.seg)
                let chrome = (d.top + d.bottom) / 2
                let regional = CrossShotRegionalContinuityV1.distance(b.seg, a.seg)
                let proj = CrossShotProjectionContinuityV1.score(b.seg, a.seg)
                let fp: Double? = {
                    guard let pa = a.print, let pb = b.print else { return nil }
                    return pb.distance(to: pa)
                }()
                let ocrJ: Double? = {
                    guard let ta = a.ocr, let tb = b.ocr else { return nil }
                    let ha = Tier1TextSimilarityV1.trigramHashes(ta), hb = Tier1TextSimilarityV1.trigramHashes(tb)
                    guard ha.count >= 8, hb.count >= 8 else { return nil }
                    return Tier1TextSimilarityV1.jaccard(ha, hb)
                }()
                rows.append(PairRow(truthNew: a.item != b.item, theme: theme, hist: hist, chrome: chrome,
                                    regional: regional, proj: proj, fp: fp, ocrJ: ocrJ))
            }
            let sameRows = rows.filter { !$0.truthNew }, newRows = rows.filter { $0.truthNew }
            func med(_ xs: [Double]) -> Double { let s = xs.sorted(); return s.isEmpty ? .nan : s[s.count / 2] }
            func line(_ name: String, _ v: @escaping (PairRow) -> Double?, newHigh: Bool) -> String {
                let sv = sameRows.compactMap(v), nv = newRows.compactMap(v)
                let e = bestThresholdErrors(rows, value: v, newIsHigh: newHigh)
                return String(format: "  %-9@ SAME med=%.3f [%.3f..%.3f]  NEW med=%.3f [%.3f..%.3f]  bestThreshold FM=%d FS=%d (of %d NEW / %d SAME pairs)",
                              name as NSString, med(sv), sv.min() ?? .nan, sv.max() ?? .nan,
                              med(nv), nv.min() ?? .nan, nv.max() ?? .nan, e.fm, e.fs, newRows.count, sameRows.count)
            }
            report.append("run \(run) — PAIR SEPARABILITY (best single threshold per channel):")
            report.append(line("theme", { $0.theme }, newHigh: true))
            report.append(line("hist", { $0.hist }, newHigh: true))
            report.append(line("chrome", { $0.chrome }, newHigh: true))
            report.append(line("regional", { $0.regional }, newHigh: true))
            report.append(line("proj", { $0.proj }, newHigh: false))
            report.append(line("FEATPRINT", { $0.fp }, newHigh: true))
            report.append(line("OCR-J", { $0.ocrJ }, newHigh: false))

            // (b) SEQUENTIAL SYSTEM SIMULATION — the real frozen Tier-0 brain vs the Tier-1 prototype.
            let tier0 = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
            let t1Policy = Tier1IdentityPolicyV1(minIntervalMs: 0)   // lab cadence — throttle law tested elsewhere
            let fpOnly = Tier1ItemIdentityV1(policy: t1Policy)       // feature print alone (no OCR, no tie-break)
            let fused = Tier1ItemIdentityV1(policy: t1Policy)        // full fusion (real OCR + Tier-0 tie-breaks)
            var t0FM = 0, t0FS = 0, fpFM = 0, fpFS = 0, fpUnk = 0, fuFM = 0, fuFS = 0, fuUnk = 0
            for k in 0..<n {
                let f = frames[k]
                let shot = ShotDescriptorV1(shotID: ShotID(UInt64(k + 1)), observationID: ObservationID(99),
                                            startMs: startMs[k], endMs: startMs[k] + 1500, representative: f.seg,
                                            transitionIn: k == 0 ? .sessionStart : .cut, swipeGate: .noSwipe,
                                            replacementRatioIn: 0.85, confidenceIn: 0.9)
                let d0 = tier0.process(shot)
                let truthNew = k == 0 || frames[k - 1].item != f.item
                if k > 0 {
                    if truthNew && !d0.openedNewItem { t0FM += 1 }
                    if !truthNew && d0.openedNewItem { t0FS += 1 }
                }
                let aFP = fpOnly.assess(cgImage: f.cg, ocrText: nil, tier0OpenedNewItem: d0.openedNewItem,
                                        tier0StrongNew: false, tier0ProjectionCorrelation: nil)
                let aFU = fused.assess(cgImage: f.cg, ocrText: f.ocr, tier0OpenedNewItem: d0.openedNewItem,
                                       tier0StrongNew: d0.channels?.strongNew ?? false,
                                       tier0ProjectionCorrelation: d0.channels?.projectionCorrelation)
                guard k > 0 else { continue }
                func score(_ a: Tier1IdentityAssessmentV1, _ fm: inout Int, _ fs: inout Int, _ unk: inout Int) {
                    // system semantics: UNKNOWN keeps the Tier-0 proposal (Tier-0 proposes, Tier-1 overrides)
                    let saysNew: Bool
                    switch a.verdict {
                    case .newItem: saysNew = true
                    case .sameItem: saysNew = false
                    case .unknown: unk += 1; saysNew = a.tier0OpenedNewItem
                    }
                    if truthNew && !saysNew { fm += 1 }
                    if !truthNew && saysNew { fs += 1 }
                }
                score(aFP, &fpFM, &fpFS, &fpUnk)
                score(aFU, &fuFM, &fuFS, &fuUnk)
            }
            let pairs = n - 1
            report.append("run \(run) — SEQUENTIAL SYSTEM (falseMerge FM / falseSplit FS over \(pairs) transitions; truth: \(Self.itemCount - 1) NEW, \(pairs - Self.itemCount + 1) SAME):")
            report.append("  Tier-0 alone (REAL frozen engine, proxy features): FM=\(t0FM) FS=\(t0FS)")
            report.append("  Tier-1 feature-print alone (UNKNOWN→Tier-0):       FM=\(fpFM) FS=\(fpFS) unknown=\(fpUnk)")
            report.append("  FUSED Tier-1 (fp+realOCR+tie-breaks, UNKNOWN→T0):  FM=\(fuFM) FS=\(fuFS) unknown=\(fuUnk)")
            report.append("  verdict counters fused: same=\(fused.sameCount) new=\(fused.newCount) unknown=\(fused.unknownCount) disagreeWithTier0=\(fused.disagreementCount)")
        }
        // The report IS the evidence — printed verbatim; no invented pass/fail beyond harness integrity.
        print(report.joined(separator: "\n"))
        let attachment = XCTAttachment(string: report.joined(separator: "\n"))
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
