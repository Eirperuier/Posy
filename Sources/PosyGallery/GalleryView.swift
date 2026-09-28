import DemoSupport
import Posy
import PosyCore
import PosyMetrics
import SwiftUI

/// Every member count from 1 to 20 side by side, with the metrics for each.
struct GalleryView: View {
    @State private var distribution = Distribution.roster
    @State private var container = Container.wide
    @State private var spacing: CGFloat = 3

    private let counts = Array(1...20)

    var body: some View {
        VStack(spacing: 0) {
            controls
                .padding(12)
            Divider()
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: container.cell.width + 12), spacing: 12)], spacing: 12) {
                    ForEach(counts, id: \.self) { count in
                        GalleryCell(members: distribution.members(count: count), container: container, spacing: spacing)
                    }
                }
                .padding(12)
            }
            .background(DemoPalette.background)
        }
    }

    private var controls: some View {
        HStack(spacing: 20) {
            Picker("Importance", selection: $distribution) {
                ForEach(Distribution.allCases) { Text($0.title).tag($0) }
            }
            .frame(maxWidth: 260)

            Picker("Container", selection: $container) {
                ForEach(Container.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            HStack {
                Text("Spacing")
                Slider(value: $spacing, in: 0...12)
                    .frame(width: 140)
                Text("\(Int(spacing)) pt")
                    .monospacedDigit()
                    .frame(width: 40, alignment: .leading)
            }
            Spacer()
        }
    }
}

private struct GalleryCell: View {
    let members: [DemoMember]
    let container: Container
    let spacing: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            cluster
                .frame(width: container.cell.width, height: container.cell.height)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            Text(summary)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.6))
        }
    }

    private var layout: PosyLayout {
        switch container {
        case .wide, .square:
            PosyLayout(spacing: spacing, sizing: .fit)
        case .natural:
            PosyLayout(spacing: spacing, sizing: .natural(unitDiameter: Container.naturalUnit))
        }
    }

    private var cluster: some View {
        layout {
            ForEach(members) { member in
                AvatarView(member)
                    .posyImportance(member.importance)
            }
        }
    }

    /// Recomputes the packing the layout performs so the numbers describe
    /// exactly what is drawn above them.
    private var summary: String {
        let packer = ClusterPacker(spacing: spacing)
        let items = members.map { ClusterItem(importance: $0.importance) }
        let packing = switch container {
        case .wide, .square: packer.pack(items, fitting: container.cell)
        case .natural: packer.pack(items, unitDiameter: Container.naturalUnit, aspectRatio: container.cell.width / container.cell.height)
        }
        let metrics = ClusterMetrics(packing)
        return String(
            format: "n=%-2d cov %.2f imb %.2f ctr %.2f lead %.2f",
            members.count, metrics.coverage, metrics.imbalance, metrics.centrality, metrics.leadOffset
        )
    }
}

enum Distribution: String, CaseIterable, Identifiable {
    case roster, equal, host, longTail, random

    var id: Self { self }

    var title: String {
        switch self {
        case .roster: "Demo roster"
        case .equal: "All equal"
        case .host: "One host"
        case .longTail: "Long tail"
        case .random: "Random"
        }
    }

    func members(count: Int) -> [DemoMember] {
        var generator = SplitMix64(seed: UInt64(count))
        return (0..<count).map { index in
            var member = DemoMember.roster[index % DemoMember.roster.count]
            member.id = index
            switch self {
            case .roster: break
            case .equal: member.importance = 1
            case .host: member.importance = index == 0 ? 1 : 0.35
            case .longTail: member.importance = 1 / Double(index + 1)
            case .random: member.importance = Double.random(in: 0.1...1, using: &generator)
            }
            return member
        }
    }
}

enum Container: String, CaseIterable, Identifiable {
    case wide, square, natural

    static let naturalUnit: CGFloat = 56

    var id: Self { self }

    var title: String {
        switch self {
        case .wide: "Fit 3:2"
        case .square: "Fit 1:1"
        case .natural: "Natural"
        }
    }

    var cell: CGSize {
        switch self {
        case .wide: CGSize(width: 210, height: 140)
        case .square: CGSize(width: 170, height: 170)
        case .natural: CGSize(width: 260, height: 200)
        }
    }
}

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
