import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The result of packing a list of items.
public struct ClusterPacking: Sendable, Equatable {
    /// One placement per item, in the same order as the input items.
    public var placements: [ClusterPlacement]

    /// The size of the smallest rectangle that contains every item's outline.
    ///
    /// Placements are expressed in a coordinate space whose origin is the
    /// top-left corner of this rectangle, with y increasing downward.
    public var size: CGSize

    /// Creates a packing from placements and the size that contains them.
    public init(placements: [ClusterPlacement], size: CGSize) {
        self.placements = placements
        self.size = size
    }
}

/// Where one item sits in a cluster and how large it is.
public struct ClusterPlacement: Sendable, Equatable {
    /// The center of the item's square frame.
    public var center: CGPoint

    /// The side length of the item's square frame.
    public var diameter: CGFloat

    /// Creates a placement.
    public init(center: CGPoint, diameter: CGFloat) {
        self.center = center
        self.diameter = diameter
    }

    /// The item's square frame.
    public var frame: CGRect {
        CGRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
    }
}
