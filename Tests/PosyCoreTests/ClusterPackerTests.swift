import Foundation
import Testing
@testable import PosyCore

@Suite("Edge cases")
struct EdgeCaseTests {
    let packer = ClusterPacker(spacing: 4)

    @Test func emptyInputAtNaturalScale() {
        let packing = packer.pack([], unitDiameter: 40)
        #expect(packing.placements.isEmpty)
        #expect(packing.size == .zero)
    }

    @Test func emptyInputWhenFitting() {
        let packing = packer.pack([], fitting: CGSize(width: 100, height: 80))
        #expect(packing.placements.isEmpty)
        #expect(packing.size == CGSize(width: 100, height: 80))
    }

    @Test func singleItemAtNaturalScale() {
        let packing = packer.pack([ClusterItem(importance: 1)], unitDiameter: 40)
        #expect(packing.placements == [ClusterPlacement(center: CGPoint(x: 20, y: 20), diameter: 40)])
        #expect(packing.size == CGSize(width: 40, height: 40))
    }

    @Test func singleItemFillsTheShorterSide() throws {
        let packing = packer.pack([ClusterItem()], fitting: CGSize(width: 200, height: 100))
        let placement = try #require(packing.placements.first)
        #expect(abs(placement.diameter - 100) < 1e-9)
        #expect(distance(placement.center, CGPoint(x: 100, y: 50)) < 1e-9)
    }

    @Test(arguments: [CGSize.zero, CGSize(width: 0, height: 50), CGSize(width: -10, height: 50), CGSize(width: CGFloat.nan, height: 50)])
    func degenerateFittingSize(_ size: CGSize) {
        let packing = packer.pack(randomItems(count: 3, seed: 1), fitting: size)
        #expect(packing.placements.count == 3)
        #expect(packing.placements.allSatisfy { $0.diameter == 0 })
        #expect(packing.size.width >= 0 && packing.size.height >= 0)
    }

    @Test func zeroUnitDiameterStillSeparatesItemsBySpacing() {
        let packing = packer.pack(randomItems(count: 5, seed: 2), unitDiameter: 0)
        for (i, j) in pairs(5) {
            #expect(gap(packing.placements[i], packing.placements[j]) >= 4 - 1e-6)
        }
    }

    @Test(arguments: [CGFloat(-3), .nan, .infinity])
    func invalidSpacingIsTreatedAsZero(_ spacing: CGFloat) {
        let packing = ClusterPacker(spacing: spacing).pack([ClusterItem(), ClusterItem()], unitDiameter: 10)
        #expect(abs(distance(packing.placements[0].center, packing.placements[1].center) - 10) < 1e-9)
    }
}

@Suite("Sizing")
struct SizingTests {
    @Test func areaIsProportionalToImportance() {
        let items = [1, 0.25, 0.64].map { ClusterItem(importance: $0) }
        let diameters = ClusterPacker().pack(items, unitDiameter: 100).placements.map(\.diameter)
        #expect(diameters.map { ($0 * 10).rounded() / 10 } == [100, 50, 80])
    }

    @Test(arguments: [
        (0.0, 0.1),
        (-5.0, 0.1),
        (1_000_000.0, 10.0),
        (Double.nan, 1.0),
        (Double.infinity, 1.0),
    ])
    func importanceIsClamped(importance: Double, expectedDiameter: Double) throws {
        let packing = ClusterPacker().pack([ClusterItem(importance: importance)], unitDiameter: 1)
        let placement = try #require(packing.placements.first)
        #expect(abs(placement.diameter - expectedDiameter) < 1e-9)
    }
}

@Suite("Geometry")
struct GeometryTests {
    static let seeds: [UInt64] = Array(1...24)

    @Test(arguments: seeds)
    func itemsNeverOverlap(seed: UInt64) {
        let count = Int(seed % 20) + 2
        let spacing = CGFloat(seed % 3) * 3
        let packing = ClusterPacker(spacing: spacing).pack(randomItems(count: count, seed: seed), unitDiameter: 60)
        for (i, j) in pairs(count) {
            #expect(gap(packing.placements[i], packing.placements[j]) >= spacing - 1e-6)
        }
    }

    @Test(arguments: seeds)
    func everyItemTouchesTheCluster(seed: UInt64) {
        let count = Int(seed % 20) + 2
        let packing = ClusterPacker(spacing: 4).pack(randomItems(count: count, seed: seed), unitDiameter: 60)
        for (index, placement) in packing.placements.enumerated() {
            let nearest = packing.placements.indices
                .filter { $0 != index }
                .map { gap(placement, packing.placements[$0]) }
                .min() ?? 0
            #expect(abs(nearest - 4) < 1e-6)
        }
    }

    @Test(arguments: seeds)
    func sizeIsTheTightBoundingBox(seed: UInt64) {
        let packing = ClusterPacker(spacing: 4).pack(randomItems(count: 12, seed: seed), unitDiameter: 60)
        let union = boundingBox(of: packing)
        #expect(abs(union.minX) < 1e-9 && abs(union.minY) < 1e-9)
        #expect(abs(union.maxX - packing.size.width) < 1e-9)
        #expect(abs(union.maxY - packing.size.height) < 1e-9)
    }

    @Test func mostImportantItemSitsNearTheMiddle() {
        let items = Array(repeating: ClusterItem(importance: 0.3), count: 11) + [ClusterItem(importance: 1)]
        let packing = ClusterPacker(spacing: 4).pack(items, unitDiameter: 60)
        let middle = CGPoint(x: packing.size.width / 2, y: packing.size.height / 2)
        let offsets = packing.placements.map { distance($0.center, middle) }
        let largest = offsets[items.count - 1]
        #expect(offsets.filter { $0 < largest }.count <= 1)
    }

    @Test(arguments: [(CGFloat(2.5), true), (0.4, false)])
    func clusterFollowsAspectRatio(aspectRatio: CGFloat, expectWide: Bool) {
        let items = (0..<24).map { _ in ClusterItem() }
        let size = ClusterPacker(spacing: 2).pack(items, unitDiameter: 20, aspectRatio: aspectRatio).size
        #expect((size.width > size.height * 1.3) == expectWide)
        #expect((size.height > size.width * 1.3) == !expectWide)
    }
}

@Suite("Fitting")
struct FittingTests {
    static let cases: [(count: Int, size: CGSize)] = [
        (2, CGSize(width: 320, height: 200)),
        (7, CGSize(width: 200, height: 200)),
        (15, CGSize(width: 150, height: 400)),
        (20, CGSize(width: 480, height: 180)),
    ]

    @Test(arguments: cases)
    func clusterFitsAndFillsOneDimension(count: Int, size: CGSize) {
        let packing = ClusterPacker(spacing: 4).pack(randomItems(count: count, seed: UInt64(count)), fitting: size)
        #expect(packing.size == size)

        let union = boundingBox(of: packing)
        let tolerance: CGFloat = 1e-6
        #expect(union.minX >= -tolerance && union.minY >= -tolerance)
        #expect(union.maxX <= size.width + tolerance && union.maxY <= size.height + tolerance)
        #expect(abs(union.width - size.width) < tolerance || abs(union.height - size.height) < tolerance)
        #expect(abs(union.midX - size.width / 2) < tolerance && abs(union.midY - size.height / 2) < tolerance)
    }

    @Test(arguments: cases)
    func spacingIsKeptInPoints(count: Int, size: CGSize) {
        let packing = ClusterPacker(spacing: 4).pack(randomItems(count: count, seed: UInt64(count)), fitting: size)
        let gaps = pairs(count).map { gap(packing.placements[$0.0], packing.placements[$0.1]) }
        let smallest = gaps.min() ?? 0
        #expect(abs(smallest - 4) < 0.25)
    }

    @Test func spacingShrinksOnlyWhenNothingElseFits() {
        let packing = ClusterPacker(spacing: 50).pack(randomItems(count: 6, seed: 3), fitting: CGSize(width: 40, height: 40))
        let union = boundingBox(of: packing)
        #expect(union.width <= 40 + 1e-6 && union.height <= 40 + 1e-6)
        for (i, j) in pairs(6) {
            #expect(gap(packing.placements[i], packing.placements[j]) >= -1e-6)
        }
    }
}

@Suite("Stability")
struct StabilityTests {
    @Test(arguments: Array(UInt64(1)...12))
    func packingIsDeterministic(seed: UInt64) {
        let items = randomItems(count: 16, seed: seed)
        let packer = ClusterPacker(spacing: 3)
        #expect(packer.pack(items, unitDiameter: 50) == packer.pack(items, unitDiameter: 50))
        #expect(packer.pack(items, fitting: CGSize(width: 300, height: 200)) == packer.pack(items, fitting: CGSize(width: 300, height: 200)))
    }

    @Test(arguments: Array(UInt64(1)...12))
    func appendingASmallerItemKeepsTheArrangement(seed: UInt64) {
        let items = randomItems(count: Int(seed) + 3, seed: seed)
        let smallest = items.map(\.importance).min() ?? 1
        let packer = ClusterPacker(spacing: 4)

        let before = packer.pack(items, unitDiameter: 60).placements
        let after = packer.pack(items + [ClusterItem(importance: smallest * 0.8)], unitDiameter: 60).placements

        let shift = CGPoint(x: after[0].center.x - before[0].center.x, y: after[0].center.y - before[0].center.y)
        for (old, new) in zip(before, after) {
            #expect(distance(CGPoint(x: old.center.x + shift.x, y: old.center.y + shift.y), new.center) < 1e-6)
        }
    }

    @Test func equalItemsAppendWithoutReshuffling() {
        let packer = ClusterPacker(spacing: 4)
        var previous = packer.pack([ClusterItem()], unitDiameter: 40).placements
        for count in 2...20 {
            let current = packer.pack(Array(repeating: ClusterItem(), count: count), unitDiameter: 40).placements
            let shift = CGPoint(x: current[0].center.x - previous[0].center.x, y: current[0].center.y - previous[0].center.y)
            for (old, new) in zip(previous, current) {
                #expect(distance(CGPoint(x: old.center.x + shift.x, y: old.center.y + shift.y), new.center) < 1e-6)
            }
            previous = current
        }
    }
}

@Suite("Shapes")
struct ShapeTests {
    @Test func nonCircularShapesDoNotOverlap() {
        let items = (0..<8).map { index in
            ClusterItem(importance: index.isMultiple(of: 3) ? 1 : 0.5, shape: index.isMultiple(of: 2) ? PillShape() : .circle)
        }
        let packer = ClusterPacker(spacing: 2)
        let packing = packer.pack(items, unitDiameter: 80)

        let disks = zip(items, packing.placements).map { item, placement in
            item.shape.collisionDisks.map { disk in
                (
                    center: CGPoint(
                        x: placement.center.x + disk.center.x * placement.diameter / 2,
                        y: placement.center.y + disk.center.y * placement.diameter / 2
                    ),
                    radius: disk.radius * placement.diameter / 2
                )
            }
        }
        for (i, j) in pairs(items.count) {
            for a in disks[i] {
                for b in disks[j] {
                    #expect(distance(a.center, b.center) - a.radius - b.radius >= 2 - 1e-6)
                }
            }
        }
    }

    @Test func pillsNestCloserThanTheirEnclosingCircles() {
        let pills = (0..<2).map { _ in ClusterItem(shape: PillShape()) }
        let packing = ClusterPacker(spacing: 0).pack(pills, unitDiameter: 100)
        #expect(distance(packing.placements[0].center, packing.placements[1].center) < 100 - 1)
    }

    @Test func invalidDisksFallBackToACircle() {
        let invalid = ClusterPacker(spacing: 4).pack([ClusterItem(shape: InvalidShape()), ClusterItem()], unitDiameter: 40)
        let circles = ClusterPacker(spacing: 4).pack([ClusterItem(), ClusterItem()], unitDiameter: 40)
        #expect(invalid == circles)
    }
}
