import Foundation

/// An item to be packed into a cluster.
public struct ClusterItem: Sendable {
    /// The range importance is clamped to before sizing.
    ///
    /// An item's area is proportional to its importance, so the extremes of this
    /// range differ by a factor of 100 in diameter.
    public static let importanceRange: ClosedRange<Double> = 0.01...100

    /// How prominent the item is relative to its siblings.
    ///
    /// Area scales linearly with importance: an item of importance `1` has the
    /// unit diameter, and an item of importance `0.25` has half of it. Values
    /// outside ``importanceRange`` are clamped, and non-finite values are
    /// treated as `1`.
    public var importance: Double

    /// The item's collision geometry.
    public var shape: any ClusterShape

    /// Creates an item.
    ///
    /// - Parameters:
    ///   - importance: How prominent the item is. Defaults to `1`.
    ///   - shape: The item's collision geometry. Defaults to a circle.
    public init(importance: Double = 1, shape: any ClusterShape = .circle) {
        self.importance = importance
        self.shape = shape
    }
}

extension ClusterItem {
    var clampedImportance: Double {
        guard importance.isFinite else { return 1 }
        return min(max(importance, Self.importanceRange.lowerBound), Self.importanceRange.upperBound)
    }

    /// The diameter relative to the unit diameter.
    var relativeDiameter: Double {
        clampedImportance.squareRoot()
    }

    var validDisks: [CollisionDisk] {
        let disks = shape.collisionDisks.filter { disk in
            let reach = hypot(disk.center.x, disk.center.y) + disk.radius
            return disk.radius > 0 && disk.radius.isFinite && reach.isFinite && reach <= 1 + 1e-9
        }
        return disks.isEmpty ? CircleClusterShape().collisionDisks : disks
    }
}
