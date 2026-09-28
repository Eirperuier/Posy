import Foundation
import PosyCore
import PosyMetrics
import Testing

@Suite("Metrics")
struct ClusterMetricsTests {
    @Test func emptyPackingHasNeutralScores() {
        let metrics = ClusterMetrics(ClusterPacking(placements: [], size: .zero))
        #expect(metrics == ClusterMetrics(coverage: 0, imbalance: 0, centrality: 1, leadOffset: 0))
    }

    @Test func singleDiscCoversAQuarterPi() {
        let packing = ClusterPacking(placements: [ClusterPlacement(center: CGPoint(x: 5, y: 5), diameter: 10)], size: CGSize(width: 10, height: 10))
        let metrics = ClusterMetrics(packing)
        #expect(abs(metrics.coverage - .pi / 4) < 1e-12)
        #expect(metrics.imbalance == 0)
        #expect(metrics.centrality == 1)
        #expect(metrics.leadOffset == 0)
    }

    @Test func largerItemOnTheRimLowersCentrality() {
        let inside = ClusterPacking(
            placements: [
                ClusterPlacement(center: CGPoint(x: 10, y: 10), diameter: 20),
                ClusterPlacement(center: CGPoint(x: 25, y: 10), diameter: 10),
                ClusterPlacement(center: CGPoint(x: -5, y: 10), diameter: 10),
            ],
            size: CGSize(width: 40, height: 20)
        )
        let outside = ClusterPacking(
            placements: [ClusterPlacement(center: CGPoint(x: 10, y: 10), diameter: 20)]
                + [25, 35, 45, 55].map { ClusterPlacement(center: CGPoint(x: $0, y: 10), diameter: 10) },
            size: CGSize(width: 60, height: 20)
        )
        #expect(ClusterMetrics(inside).centrality == 1)
        #expect(ClusterMetrics(outside).centrality == 0.25)
        #expect(ClusterMetrics(inside).imbalance < ClusterMetrics(outside).imbalance)
        #expect(ClusterMetrics(inside).leadOffset < ClusterMetrics(outside).leadOffset)
    }

    @Test func displacementIgnoresRecentering() {
        let old = ClusterPacking(placements: [ClusterPlacement(center: CGPoint(x: 10, y: 10), diameter: 20)], size: CGSize(width: 20, height: 20))
        let new = ClusterPacking(
            placements: [
                ClusterPlacement(center: CGPoint(x: 10, y: 10), diameter: 20),
                ClusterPlacement(center: CGPoint(x: 30, y: 10), diameter: 20),
            ],
            size: CGSize(width: 40, height: 20)
        )
        #expect(ClusterMetrics.displacement(from: old, to: old, matching: [(0, 0)]) == 0)
        #expect(abs(ClusterMetrics.displacement(from: old, to: new, matching: [(0, 0)]) - 0.5) < 1e-12)
        #expect(ClusterMetrics.displacement(from: old, to: new, matching: [(3, 0)]) == 0)
    }

    /// Greedy placement cannot center the host for every count, so this bounds
    /// the worst case and the typical case separately.
    @Test(arguments: [CGSize(width: 300, height: 200), CGSize(width: 200, height: 200)])
    func hostStaysCentered(in size: CGSize) {
        let packer = ClusterPacker(spacing: 4)
        let offsets = (5...19).map { guests in
            let items = [ClusterItem(importance: 1)] + Array(repeating: ClusterItem(importance: 0.35), count: guests)
            return ClusterMetrics(packer.pack(items, fitting: size)).leadOffset
        }
        #expect(offsets.allSatisfy { $0 < 0.15 })
        #expect(offsets.reduce(0, +) / Double(offsets.count) < 0.06)
    }

    @Test func appendingToARealPackingBarelyMovesAnything() {
        let packer = ClusterPacker(spacing: 4)
        let items = (0..<12).map { ClusterItem(importance: 1 - Double($0) * 0.05) }
        let before = packer.pack(items, unitDiameter: 40)
        let after = packer.pack(items + [ClusterItem(importance: 0.2)], unitDiameter: 40)
        let matches = items.indices.map { (old: $0, new: $0) }
        #expect(ClusterMetrics.displacement(from: before, to: after, matching: matches) < 0.3)
    }
}
