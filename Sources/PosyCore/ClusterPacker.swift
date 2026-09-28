import Foundation

/// Packs items of varying importance into a compact, organic cluster.
///
/// The most important items end up near the middle and smaller ones settle
/// into the pockets around them. Results are deterministic: the same items and
/// parameters always produce the same packing.
///
/// ```swift
/// let packer = ClusterPacker(spacing: 4)
/// let packing = packer.pack(
///     [ClusterItem(importance: 1), ClusterItem(importance: 0.4), ClusterItem(importance: 0.4)],
///     fitting: CGSize(width: 320, height: 200)
/// )
/// ```
public struct ClusterPacker: Sendable, Hashable {
    /// The gap between the outlines of neighboring items.
    public var spacing: CGFloat

    /// Creates a packer.
    ///
    /// - Parameter spacing: The gap between neighboring items. Negative or
    ///   non-finite values are treated as `0`.
    public init(spacing: CGFloat = 4) {
        self.spacing = spacing
    }

    /// Packs items at a fixed scale and reports the size they occupy.
    ///
    /// Use this when the cluster should take whatever room it needs.
    ///
    /// - Parameters:
    ///   - items: The items to pack.
    ///   - unitDiameter: The diameter of an item whose importance is `1`.
    ///   - aspectRatio: Width over height of the shape the cluster should grow
    ///     into. Values are clamped to `0.1...10`.
    /// - Returns: The placements and the size of their bounding rectangle.
    public func pack(
        _ items: [ClusterItem],
        unitDiameter: CGFloat,
        aspectRatio: CGFloat = 1
    ) -> ClusterPacking {
        guard !items.isEmpty else { return ClusterPacking(placements: [], size: .zero) }

        let unit = Double(unitDiameter).isFinite ? max(Double(unitDiameter), 0) : 0
        let diameters = items.map { $0.relativeDiameter * unit }
        let bodies = zip(items, diameters).map { item, diameter in
            PackingSolver.Body(disks: item.validDisks.map { disk in
                PackingSolver.Disk(offset: Vector(disk.center) * (diameter / 2), radius: Double(disk.radius) * diameter / 2)
            })
        }

        let solver = PackingSolver(spacing: sanitizedSpacing, aspectRatio: Double(aspectRatio))
        let centers = solver.solve(bodies)

        var minimum = Vector(x: Double.infinity, y: Double.infinity)
        var maximum = Vector(x: -Double.infinity, y: -Double.infinity)
        for (body, center) in zip(bodies, centers) {
            for disk in body.disks {
                let position = center + disk.offset
                minimum = Vector(x: min(minimum.x, position.x - disk.radius), y: min(minimum.y, position.y - disk.radius))
                maximum = Vector(x: max(maximum.x, position.x + disk.radius), y: max(maximum.y, position.y + disk.radius))
            }
        }

        let placements = zip(centers, diameters).map { center, diameter in
            let local = center - minimum
            return ClusterPlacement(center: CGPoint(x: local.x, y: local.y), diameter: diameter)
        }
        return ClusterPacking(
            placements: placements,
            size: CGSize(width: maximum.x - minimum.x, height: maximum.y - minimum.y)
        )
    }

    /// Packs items as large as possible while fitting inside a fixed size.
    ///
    /// The cluster grows toward the aspect ratio of `size`, is scaled to fit it,
    /// and is centered within it. The spacing is honored in points; it only
    /// shrinks when `size` is too small to hold the items at any scale.
    ///
    /// - Parameters:
    ///   - items: The items to pack.
    ///   - size: The size to fit. The returned packing reports this size.
    /// - Returns: The placements, centered in `size`.
    public func pack(_ items: [ClusterItem], fitting size: CGSize) -> ClusterPacking {
        let width = Double(size.width).isFinite ? max(Double(size.width), 0) : 0
        let height = Double(size.height).isFinite ? max(Double(size.height), 0) : 0
        let target = CGSize(width: width, height: height)
        guard !items.isEmpty else { return ClusterPacking(placements: [], size: target) }
        guard width > 0, height > 0 else {
            let center = CGPoint(x: width / 2, y: height / 2)
            return ClusterPacking(
                placements: items.map { _ in ClusterPlacement(center: center, diameter: 0) },
                size: target
            )
        }

        let aspectRatio = width / height
        let totalArea = items.reduce(0) { $0 + $1.clampedImportance } * .pi / 4

        // Spacing does not scale with the unit diameter, so the bounding size is
        // not proportional to it. A few fixed-point steps converge well within a
        // point for realistic spacing; the final uniform scale absorbs the rest.
        var unit = (0.5 * width * height / totalArea).squareRoot()
        for _ in 0..<4 {
            let packing = pack(items, unitDiameter: unit, aspectRatio: aspectRatio)
            guard let scale = Self.fittingScale(of: packing.size, into: target) else { break }
            unit *= scale
        }

        let packing = pack(items, unitDiameter: unit, aspectRatio: aspectRatio)
        let scale = Self.fittingScale(of: packing.size, into: target) ?? 1
        let offset = CGPoint(
            x: (width - packing.size.width * scale) / 2,
            y: (height - packing.size.height * scale) / 2
        )
        let placements = packing.placements.map { placement in
            ClusterPlacement(
                center: CGPoint(x: placement.center.x * scale + offset.x, y: placement.center.y * scale + offset.y),
                diameter: placement.diameter * scale
            )
        }
        return ClusterPacking(placements: placements, size: target)
    }

    private var sanitizedSpacing: Double {
        Double(spacing).isFinite ? max(Double(spacing), 0) : 0
    }

    private static func fittingScale(of size: CGSize, into target: CGSize) -> Double? {
        let scale = min(target.width / size.width, target.height / size.height)
        return scale.isFinite && scale > 0 ? scale : nil
    }
}
