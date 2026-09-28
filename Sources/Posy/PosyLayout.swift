import PosyCore
import SwiftUI

/// A layout that packs its subviews into a compact, organic cluster.
///
/// Each subview is sized from its importance, set with
/// `posyImportance(_:)`, and placed so that the most
/// important subviews sit near the middle. Subviews receive a square proposal
/// matching their diameter, so they should be flexible — a resizable image
/// clipped to a circle, or a filled `Circle` with an overlay.
///
/// ```swift
/// PosyLayout(spacing: 6) {
///     ForEach(members) { member in
///         Avatar(member)
///             .posyImportance(member.isHost ? 1 : 0.4)
///     }
/// }
/// .frame(height: 240)
/// ```
///
/// Appending a subview that is no more important than any existing one leaves
/// their arrangement intact, so insertions animate as the cluster making room
/// rather than reshuffling.
public struct PosyLayout: Layout {
    /// How the layout chooses the scale of the cluster.
    public enum Sizing: Sendable, Hashable {
        /// Scales the cluster to fill the proposed size and centers it.
        ///
        /// When only one dimension is proposed, the cluster fills that
        /// dimension and reports the other. When neither is proposed, the
        /// layout behaves like ``natural(unitDiameter:)`` with a unit diameter
        /// of 44 points.
        case fit

        /// Uses a fixed scale and reports the size the cluster needs.
        ///
        /// - Parameter unitDiameter: The diameter of a subview whose importance
        ///   is `1`.
        case natural(unitDiameter: CGFloat)
    }

    /// Memoized packings for recently proposed sizes.
    public struct Cache {
        fileprivate var entries: [(key: CacheKey, packing: ClusterPacking)] = []
    }

    /// The gap between the outlines of neighboring subviews.
    public var spacing: CGFloat

    /// How the layout chooses the scale of the cluster.
    public var sizing: Sizing

    /// Creates a cluster layout.
    ///
    /// - Parameters:
    ///   - spacing: The gap between neighboring subviews. Defaults to 4 points.
    ///   - sizing: How the cluster is scaled. Defaults to ``Sizing/fit``.
    public init(spacing: CGFloat = 4, sizing: Sizing = .fit) {
        self.spacing = spacing
        self.sizing = sizing
    }

    /// Creates an empty cache.
    public func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    /// Reports the size of the cluster for a proposal.
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        packing(for: proposal, subviews: subviews, cache: &cache).size
    }

    /// Places each subview at its packed position, centered in `bounds`.
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        // Fitting uses the granted bounds rather than the proposal, since the
        // parent may grant a different size than it proposed.
        let resolved = sizing == .fit ? ProposedViewSize(bounds.size) : proposal
        let packing = packing(for: resolved, subviews: subviews, cache: &cache)
        let origin = CGPoint(
            x: bounds.midX - packing.size.width / 2,
            y: bounds.midY - packing.size.height / 2
        )
        for (subview, placement) in zip(subviews, packing.placements) {
            subview.place(
                at: CGPoint(x: origin.x + placement.center.x, y: origin.y + placement.center.y),
                anchor: .center,
                proposal: ProposedViewSize(width: placement.diameter, height: placement.diameter)
            )
        }
    }
}

extension PosyLayout {
    private static let fallbackUnitDiameter: CGFloat = 44

    /// SwiftUI probes a layout with several proposals per pass, so a single
    /// entry would be evicted before it is reused.
    private static let cacheCapacity = 4

    private func packing(for proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> ClusterPacking {
        let importances = subviews.map { $0[PosyImportanceKey.self] }
        let key = CacheKey(
            importances: importances,
            width: proposal.width.flatMap { $0.isFinite ? $0 : nil },
            height: proposal.height.flatMap { $0.isFinite ? $0 : nil },
            spacing: spacing,
            sizing: sizing
        )
        if let hit = cache.entries.first(where: { $0.key == key }) {
            return hit.packing
        }

        let packing = Self.pack(importances.map { ClusterItem(importance: $0) }, for: key)
        cache.entries.append((key, packing))
        if cache.entries.count > Self.cacheCapacity {
            cache.entries.removeFirst()
        }
        return packing
    }

    private static func pack(_ items: [ClusterItem], for key: CacheKey) -> ClusterPacking {
        let packer = ClusterPacker(spacing: key.spacing)

        switch key.sizing {
        case .natural(let unitDiameter):
            let aspectRatio = key.width.flatMap { width in
                key.height.flatMap { height in height > 0 && width > 0 ? width / height : nil }
            }
            return packer.pack(items, unitDiameter: unitDiameter, aspectRatio: aspectRatio ?? 1)

        case .fit:
            switch (key.width, key.height) {
            case let (width?, height?):
                return packer.pack(items, fitting: CGSize(width: width, height: height))
            case let (width?, nil):
                let natural = packer.pack(items, unitDiameter: fallbackUnitDiameter)
                let height = natural.size.width > 0 ? width * natural.size.height / natural.size.width : 0
                return packer.pack(items, fitting: CGSize(width: width, height: height))
            case let (nil, height?):
                let natural = packer.pack(items, unitDiameter: fallbackUnitDiameter)
                let width = natural.size.height > 0 ? height * natural.size.width / natural.size.height : 0
                return packer.pack(items, fitting: CGSize(width: width, height: height))
            case (nil, nil):
                return packer.pack(items, unitDiameter: fallbackUnitDiameter)
            }
        }
    }
}

private struct CacheKey: Hashable {
    var importances: [Double]
    var width: CGFloat?
    var height: CGFloat?
    var spacing: CGFloat
    var sizing: PosyLayout.Sizing
}
