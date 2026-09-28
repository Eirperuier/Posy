import DemoSupport
import Foundation
import ImageIO
import Posy
import SwiftUI
import UniformTypeIdentifiers

/// A grid of clusters for one through twenty members, drawn by `PosyLayout`
/// itself rather than by replaying packings.
enum GalleryRenderer {
    static let columns = 5
    static let counts = Array(1...20)
    static let cell = CGSize(width: 180, height: 140)

    @MainActor
    static func render(to url: URL) throws {
        let rows = (counts.count + columns - 1) / columns
        let view = VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        if index < counts.count {
                            cellView(count: counts[index])
                        }
                    }
                }
            }
        }
        .background(DemoPalette.background)

        try writePNG(renderImage(of: view, scale: 2), to: url)
    }

    @MainActor
    private static func cellView(count: Int) -> some View {
        let members = Array(DemoMember.roster.prefix(count))
        return ZStack(alignment: .bottomLeading) {
            PosyLayout(spacing: 3) {
                ForEach(members) { member in
                    AvatarView(member)
                        .posyImportance(member.importance)
                }
            }
            .padding(18)
            .frame(width: cell.width, height: cell.height)
            Text("\(count)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(6)
        }
        .frame(width: cell.width, height: cell.height)
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw AssetError.encodeFailed(url)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw AssetError.encodeFailed(url) }
    }
}
