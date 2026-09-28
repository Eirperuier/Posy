import DemoSupport
import Foundation
import ImageIO
import PosyCore
import SwiftUI
import UniformTypeIdentifiers

/// Renders the images embedded in the README from real packings.
///
/// Usage: `swift run ReadmeAssets [output-directory]`
@main
struct ReadmeAssets {
    @MainActor
    static func main() throws {
        let arguments = CommandLine.arguments.dropFirst()
        let directory = URL(fileURLWithPath: arguments.first ?? "Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        try GalleryRenderer.render(to: directory.appendingPathComponent("gallery.png"))
        try DemoAnimation.render(to: directory.appendingPathComponent("demo.gif"))
        print("Wrote assets to \(directory.path)")
    }
}

struct Sprite: Identifiable {
    var member: DemoMember
    var center: CGPoint
    var diameter: CGFloat
    var id: Int { member.id }
}

struct SceneView: View {
    var sprites: [Sprite]
    var size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            DemoPalette.background
            ForEach(sprites) { sprite in
                AvatarView(sprite.member)
                    .frame(width: sprite.diameter, height: sprite.diameter)
                    .position(sprite.center)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

enum AssetError: Error {
    case renderFailed
    case encodeFailed(URL)
}

@MainActor
func renderImage(of view: some View, scale: CGFloat) throws -> CGImage {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    guard let image = renderer.cgImage else { throw AssetError.renderFailed }
    return image
}

func sprites(for members: [DemoMember], in size: CGSize, inset: CGFloat, spacing: CGFloat) -> [Sprite] {
    let packer = ClusterPacker(spacing: spacing)
    let inner = CGSize(width: size.width - inset * 2, height: size.height - inset * 2)
    let packing = packer.pack(members.map { ClusterItem(importance: $0.importance) }, fitting: inner)
    return zip(members, packing.placements).map { member, placement in
        Sprite(
            member: member,
            center: CGPoint(x: placement.center.x + inset, y: placement.center.y + inset),
            diameter: placement.diameter
        )
    }
}
