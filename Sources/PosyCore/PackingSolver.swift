import Foundation

/// Greedy packing: bodies are placed largest first, each at the free position
/// where it touches the cluster and scores best on two terms: distance to an
/// anchor near the cluster's middle, and how far the placement would push the
/// bounding box off the first body.
///
/// Every candidate position either touches two placed disks (a pocket) or one
/// placed disk (a fallback for the first contacts). Because larger bodies claim
/// the center first and smaller ones settle into the remaining pockets, the
/// result reads as a single rounded mass with the most important items inside.
///
/// Placement order is the only thing that depends on the input as a whole, so
/// appending a body that is no larger than the existing ones leaves their
/// relative positions untouched.
struct PackingSolver {
    struct Disk {
        var offset: Vector
        var radius: Double
    }

    struct Body {
        var disks: [Disk]

        /// Distance from the body's center to the farthest point of its outline.
        var extent: Double {
            disks.reduce(0) { max($0, $1.offset.length + $1.radius) }
        }
    }

    private struct PlacedDisk {
        var center: Vector
        /// Includes half of the spacing, so tangency between two inflated disks
        /// leaves exactly one spacing between their outlines.
        var radius: Double
    }

    /// Directions tried for single-contact candidates. Twelve keeps the first few
    /// placements symmetric without adding measurable cost.
    private static let contactDirections: [Vector] = (0..<12).map { step in
        let angle = Double(step) * .pi / 6
        return Vector(x: cos(angle), y: sin(angle))
    }

    private static let relativeTolerance = 1e-9

    /// How far the anchor moves from the first body toward the area-weighted
    /// centroid of everything placed. Anchoring on the first body alone keeps
    /// the most important item central but grows lopsided rows; anchoring on
    /// the centroid alone rounds the outline but lets the largest item drift to
    /// an edge. Halfway keeps both properties in the gallery at every count.
    private static let centroidPull = 0.5

    /// Weight of the penalty for moving the middle of the bounding box away
    /// from the first body. Layouts center the bounding box, so without it the
    /// most important item drifts toward one side and the satellites pile up
    /// on the other. At 10 the first body stays centered from about six items
    /// on; lower values leave visibly lopsided clusters, higher ones cost
    /// compactness without further gain in the gallery metrics.
    private static let centeringWeight = 10.0

    var spacing: Double
    /// Width over height of the region the cluster should grow into.
    var aspectRatio: Double

    /// Returns the center of each body, in input order, relative to the center
    /// of the first body placed.
    func solve(_ bodies: [Body]) -> [Vector] {
        guard !bodies.isEmpty else { return [] }

        let extents = bodies.map(\.extent)
        let order = bodies.indices.sorted { lhs, rhs in
            extents[lhs] != extents[rhs] ? extents[lhs] > extents[rhs] : lhs < rhs
        }

        var centers = [Vector](repeating: .zero, count: bodies.count)
        var placed: [PlacedDisk] = []
        placed.reserveCapacity(bodies.reduce(0) { $0 + $1.disks.count })
        var mass = MassSummary()

        for (step, index) in order.enumerated() {
            let body = bodies[index]
            let center = step == 0 ? .zero : position(for: body, around: placed, mass: mass)
            centers[index] = center
            placed.append(contentsOf: inflated(body).disks.map { PlacedDisk(center: center + $0.offset, radius: $0.radius) })
            mass.add(body, at: center)
        }
        return centers
    }

    private func inflated(_ body: Body) -> Body {
        Body(disks: body.disks.map { Disk(offset: $0.offset, radius: $0.radius + spacing / 2) })
    }

    private func position(for outline: Body, around placed: [PlacedDisk], mass: MassSummary) -> Vector {
        let body = inflated(outline)
        let anchor = mass.centroid * Self.centroidPull
        let axisScale = axisScale
        var selector = CandidateSelector()

        func offer(_ center: Vector) {
            let offset = center - anchor
            let x = offset.x / axisScale.x
            let y = offset.y / axisScale.y
            let score = x * x + y * y + Self.centeringWeight * mass.middleOffsetSquared(adding: outline, at: center)
            if selector.wouldAccept(center, score: score), fits(body, at: center, among: placed) {
                selector.accept(center, score: score)
            }
        }

        for first in placed.indices {
            for second in placed.indices where second > first {
                for disk in body.disks {
                    for contact in Self.pocketPoints(placed[first], placed[second], radius: disk.radius) {
                        offer(contact - disk.offset)
                    }
                }
            }
        }

        for neighbor in placed {
            for disk in body.disks {
                let distance = neighbor.radius + disk.radius
                for direction in Self.contactDirections {
                    offer(neighbor.center + direction * distance - disk.offset)
                }
            }
        }

        return selector.best ?? outsidePosition(for: body, around: placed)
    }

    /// Scales the ellipse used as the distance metric so the cluster grows into
    /// the requested aspect ratio while keeping its area.
    ///
    /// The ellipse is only half as eccentric as the target. At full strength a
    /// 3:2 frame already lines the first three or five items up in a row, which
    /// fills the frame but no longer reads as a cluster; large counts still
    /// stretch clearly toward the target.
    private var axisScale: Vector {
        let ratio = aspectRatio.isFinite && aspectRatio > 0 ? min(max(aspectRatio, 0.1), 10) : 1
        let stretch = pow(ratio, 0.25)
        return Vector(x: stretch, y: 1 / stretch)
    }

    private func fits(_ body: Body, at center: Vector, among placed: [PlacedDisk]) -> Bool {
        for disk in body.disks {
            let position = center + disk.offset
            for other in placed {
                let minimum = (disk.radius + other.radius) * (1 - Self.relativeTolerance)
                if (position - other.center).lengthSquared < minimum * minimum {
                    return false
                }
            }
        }
        return true
    }

    /// A position to the right of everything placed so far, which is always free.
    /// Only reachable for shapes whose disks leave no pocket or contact point open.
    private func outsidePosition(for body: Body, around placed: [PlacedDisk]) -> Vector {
        let rightEdge = placed.reduce(-Double.infinity) { max($0, $1.center.x + $1.radius) }
        return Vector(x: rightEdge + body.extent, y: 0)
    }

    /// Centers of a disk of `radius` that touches both `a` and `b`.
    private static func pocketPoints(_ a: PlacedDisk, _ b: PlacedDisk, radius: Double) -> [Vector] {
        let reachA = a.radius + radius
        let reachB = b.radius + radius
        let delta = b.center - a.center
        let distance = delta.length
        guard distance > 0, distance <= reachA + reachB, distance >= abs(reachA - reachB) else {
            return []
        }

        let along = (distance * distance + reachA * reachA - reachB * reachB) / (2 * distance)
        let across = max(reachA * reachA - along * along, 0).squareRoot()
        let unit = delta * (1 / distance)
        let base = a.center + unit * along
        let normal = Vector(x: -unit.y, y: unit.x)
        return [base + normal * across, base - normal * across]
    }
}

/// Running area-weighted centroid and bounding box of the placed outlines.
private struct MassSummary {
    private var weightedSum = Vector.zero
    private var totalWeight = 0.0
    private var minimum = Vector(x: .infinity, y: .infinity)
    private var maximum = Vector(x: -.infinity, y: -.infinity)

    var centroid: Vector {
        totalWeight > 0 ? weightedSum * (1 / totalWeight) : .zero
    }

    mutating func add(_ body: PackingSolver.Body, at center: Vector) {
        for disk in body.disks {
            let position = center + disk.offset
            let weight = disk.radius * disk.radius
            weightedSum = weightedSum + position * weight
            totalWeight += weight
            minimum = Vector(x: min(minimum.x, position.x - disk.radius), y: min(minimum.y, position.y - disk.radius))
            maximum = Vector(x: max(maximum.x, position.x + disk.radius), y: max(maximum.y, position.y + disk.radius))
        }
    }

    /// Squared distance from the first body's center to the middle of the
    /// bounding box, if `body` were added at `center`.
    func middleOffsetSquared(adding body: PackingSolver.Body, at center: Vector) -> Double {
        var summary = self
        summary.add(body, at: center)
        return ((summary.minimum + summary.maximum) * 0.5).lengthSquared
    }
}

/// Keeps the lowest-scoring candidate seen so far, with a deterministic
/// tie-break so that mirror-symmetric pockets resolve the same way regardless
/// of the order in which they were generated.
private struct CandidateSelector {
    private(set) var best: Vector?
    private var bestScore = Double.infinity

    func wouldAccept(_ candidate: Vector, score: Double) -> Bool {
        guard let best else { return true }
        let tolerance = 1e-9 * max(abs(score), abs(bestScore), 1e-12)
        if score < bestScore - tolerance { return true }
        if score > bestScore + tolerance { return false }
        return Self.precedes(candidate, best)
    }

    mutating func accept(_ candidate: Vector, score: Double) {
        best = candidate
        bestScore = score
    }

    /// Prefers the upper candidate, then the leading one.
    private static func precedes(_ lhs: Vector, _ rhs: Vector) -> Bool {
        let tolerance = 1e-9 * max(abs(lhs.x), abs(lhs.y), abs(rhs.x), abs(rhs.y), 1)
        if abs(lhs.y - rhs.y) > tolerance { return lhs.y < rhs.y }
        return lhs.x < rhs.x - tolerance
    }
}
