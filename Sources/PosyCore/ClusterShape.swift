import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The collision geometry of an item in a cluster.
///
/// The packer never assumes items are circles. It only sees the disks a shape
/// reports, so a new outline — a rounded square, a scalloped badge — can join a
/// cluster by approximating itself with a handful of disks.
///
/// Disks are expressed in a unit space where the item's square frame spans
/// `-1...1` on both axes, with the origin at the frame's center. The packer
/// scales that space by half of the item's diameter.
public protocol ClusterShape: Sendable {
    /// The disks whose union approximates the shape's outline.
    ///
    /// Every disk must have a positive radius and lie inside the unit circle.
    /// Disks that violate this are ignored; a shape that reports no usable
    /// disks is treated as a circle.
    var collisionDisks: [CollisionDisk] { get }
}

/// A disk in a shape's unit space.
public struct CollisionDisk: Sendable, Equatable {
    /// The disk's center, where the item's frame spans `-1...1` on both axes.
    public var center: CGPoint

    /// The disk's radius in the same unit space.
    public var radius: CGFloat

    /// Creates a disk from a center and radius in unit space.
    public init(center: CGPoint, radius: CGFloat) {
        self.center = center
        self.radius = radius
    }
}

/// A circle that fills its item's frame.
public struct CircleClusterShape: ClusterShape, Hashable {
    /// Creates a circle shape.
    public init() {}

    /// A single disk covering the unit circle.
    public var collisionDisks: [CollisionDisk] {
        [CollisionDisk(center: .zero, radius: 1)]
    }
}

extension ClusterShape where Self == CircleClusterShape {
    /// A circle that fills its item's frame.
    public static var circle: CircleClusterShape { CircleClusterShape() }
}
