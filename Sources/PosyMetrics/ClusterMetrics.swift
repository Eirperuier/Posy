import Foundation
import PosyCore

/// Numbers that make "does this cluster look good" comparable across
/// algorithms and inputs.
///
/// Each item is treated as a disc of its placement's diameter.
public struct ClusterMetrics: Sendable, Equatable {
    /// The share of the bounding box covered by items, in `0...1`. Higher is
    /// tighter; a single disc scores `pi / 4`.
    public var coverage: Double

    /// How far the area-weighted centroid sits from the middle of the bounding
    /// box, relative to half its diagonal. `0` is perfectly balanced.
    public var imbalance: Double

    /// The fraction of differently sized pairs in which the larger item is
    /// closer to the middle. `1` means strictly larger-inside.
    public var centrality: Double

    /// How far the largest item sits from the middle of the bounding box,
    /// relative to half its diagonal. `0` means the most important item is
    /// exactly centered.
    public var leadOffset: Double

    /// Measures a packing.
    public init(_ packing: ClusterPacking) {
        let placements = packing.placements
        let bounds = placements.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        guard !placements.isEmpty, bounds.width > 0, bounds.height > 0 else {
            self.init(coverage: 0, imbalance: 0, centrality: 1, leadOffset: 0)
            return
        }

        let middle = CGPoint(x: bounds.midX, y: bounds.midY)
        let areas = placements.map { Double.pi * Double($0.diameter * $0.diameter) / 4 }
        let totalArea = areas.reduce(0, +)

        let centroid = zip(placements, areas).reduce(CGPoint.zero) { sum, pair in
            CGPoint(x: sum.x + pair.0.center.x * pair.1 / totalArea, y: sum.y + pair.0.center.y * pair.1 / totalArea)
        }
        let halfDiagonal = hypot(bounds.width, bounds.height) / 2

        let offsets = placements.map { hypot($0.center.x - middle.x, $0.center.y - middle.y) }
        var ordered = 0
        var compared = 0
        for i in placements.indices {
            for j in placements.indices where j > i && placements[i].diameter != placements[j].diameter {
                compared += 1
                let (larger, smaller) = placements[i].diameter > placements[j].diameter ? (i, j) : (j, i)
                if offsets[larger] <= offsets[smaller] {
                    ordered += 1
                }
            }
        }

        let lead = placements.indices.max { placements[$0].diameter < placements[$1].diameter } ?? 0

        self.init(
            coverage: totalArea / Double(bounds.width * bounds.height),
            imbalance: Double(hypot(centroid.x - middle.x, centroid.y - middle.y) / halfDiagonal),
            centrality: compared > 0 ? Double(ordered) / Double(compared) : 1,
            leadOffset: Double(offsets[lead] / halfDiagonal)
        )
    }

    /// Creates metrics from known values.
    public init(coverage: Double, imbalance: Double, centrality: Double, leadOffset: Double) {
        self.coverage = coverage
        self.imbalance = imbalance
        self.centrality = centrality
        self.leadOffset = leadOffset
    }

    /// How far items move between two packings, as a fraction of their mean
    /// diameter.
    ///
    /// Each packing is centered on its reported size first, the way a layout
    /// presents it, so a cluster that only grows around its existing items
    /// scores close to `0`.
    ///
    /// - Parameters:
    ///   - old: The packing before the change.
    ///   - new: The packing after the change.
    ///   - matches: Pairs of indices that refer to the same item in `old` and
    ///     `new`. Out-of-range pairs are ignored.
    /// - Returns: The mean distance moved divided by the mean diameter, or `0`
    ///   when nothing matches.
    public static func displacement(
        from old: ClusterPacking,
        to new: ClusterPacking,
        matching matches: [(old: Int, new: Int)]
    ) -> Double {
        let valid = matches.filter { old.placements.indices.contains($0.old) && new.placements.indices.contains($0.new) }
        guard !valid.isEmpty else { return 0 }

        func centered(_ packing: ClusterPacking, _ index: Int) -> CGPoint {
            let center = packing.placements[index].center
            return CGPoint(x: center.x - packing.size.width / 2, y: center.y - packing.size.height / 2)
        }

        let moved = valid.reduce(0.0) { sum, match in
            let a = centered(old, match.old)
            let b = centered(new, match.new)
            return sum + Double(hypot(a.x - b.x, a.y - b.y))
        }
        let diameter = valid.reduce(0.0) { $0 + Double(old.placements[$1.old].diameter) }
        return diameter > 0 ? moved / diameter : 0
    }
}
