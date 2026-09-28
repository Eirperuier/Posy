import Foundation
@testable import PosyCore

struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

func randomItems(count: Int, seed: UInt64) -> [ClusterItem] {
    var generator = SplitMix64(seed: seed)
    return (0..<count).map { _ in ClusterItem(importance: Double.random(in: 0.05...1, using: &generator)) }
}

func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    hypot(a.x - b.x, a.y - b.y)
}

/// Gap between the outlines of two circular placements.
func gap(_ a: ClusterPlacement, _ b: ClusterPlacement) -> CGFloat {
    distance(a.center, b.center) - (a.diameter + b.diameter) / 2
}

func boundingBox(of packing: ClusterPacking) -> CGRect {
    packing.placements.map(\.frame).reduce(CGRect.null) { $0.union($1) }
}

func pairs(_ count: Int) -> [(Int, Int)] {
    (0..<count).flatMap { i in ((i + 1)..<count).map { (i, $0) } }
}

/// A shape made of two disks side by side, used to exercise non-circular
/// collision geometry.
struct PillShape: ClusterShape {
    var collisionDisks: [CollisionDisk] {
        [
            CollisionDisk(center: CGPoint(x: -0.5, y: 0), radius: 0.5),
            CollisionDisk(center: CGPoint(x: 0.5, y: 0), radius: 0.5),
        ]
    }
}

struct InvalidShape: ClusterShape {
    var collisionDisks: [CollisionDisk] {
        [
            CollisionDisk(center: .zero, radius: 0),
            CollisionDisk(center: CGPoint(x: 2, y: 0), radius: 0.5),
            CollisionDisk(center: .zero, radius: .nan),
        ]
    }
}
