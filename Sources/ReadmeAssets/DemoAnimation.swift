import DemoSupport
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// A looping clip of a group chat filling up, reshuffling when one member is
/// promoted, and emptying again.
///
/// Positions come from `ClusterPacker`; the transitions interpolate between
/// consecutive packings the way SwiftUI animates a `Layout` change.
enum DemoAnimation {
    static let size = CGSize(width: 520, height: 320)
    static let inset: CGFloat = 20
    static let spacing: CGFloat = 5
    static let framesPerSecond = 25.0
    /// Keeps the GIF small enough for GitHub to inline without a click-through.
    static let renderScale: CGFloat = 1.5
    static let transitionDuration = 0.7
    static let holdDuration = 0.45

    @MainActor
    static func render(to url: URL) throws {
        let states = timeline()
        var frames: [(image: CGImage, delay: Double)] = []

        for (from, to) in zip(states, states.dropFirst() + [states[0]]) {
            let start = sprites(for: from, in: size, inset: inset, spacing: spacing)
            let end = sprites(for: to, in: size, inset: inset, spacing: spacing)

            frames.append((try renderImage(of: SceneView(sprites: start, size: size), scale: renderScale), holdDuration))
            let steps = Int(transitionDuration * framesPerSecond)
            for step in 1..<steps {
                let progress = Double(step) / Double(steps)
                let sprites = interpolate(from: start, to: end, progress: progress)
                frames.append((try renderImage(of: SceneView(sprites: sprites, size: size), scale: renderScale), 1 / framesPerSecond))
            }
        }

        try writeGIF(frames, to: url)
    }

    private static func timeline() -> [[DemoMember]] {
        let roster = DemoMember.roster
        var states: [[DemoMember]] = []
        var current = [roster[0]]
        states.append(current)

        for batch in [[2], [4], [5, 1], [3, 8], [7, 6], [10, 11, 9], [12, 13]] {
            current += batch.map { roster[$0] }
            states.append(current)
        }

        if let index = current.firstIndex(where: { $0.id == 5 }) {
            current[index].importance = 0.95
            states.append(current)
        }

        current.removeAll { [8, 3, 12].contains($0.id) }
        states.append(current)
        return states
    }

    /// An underdamped spring that settles by the end of the transition.
    private static func spring(_ t: Double) -> Double {
        1 - exp(-7 * t) * cos(9 * t)
    }

    private static func interpolate(from start: [Sprite], to end: [Sprite], progress: Double) -> [Sprite] {
        let motion = spring(progress)
        let startByID = Dictionary(uniqueKeysWithValues: start.map { ($0.id, $0) })
        let endIDs = Set(end.map(\.id))

        let moving = end.map { target -> Sprite in
            guard let origin = startByID[target.id] else {
                var entering = target
                entering.diameter = target.diameter * max(motion, 0)
                return entering
            }
            return Sprite(
                member: target.member,
                center: CGPoint(
                    x: origin.center.x + (target.center.x - origin.center.x) * motion,
                    y: origin.center.y + (target.center.y - origin.center.y) * motion
                ),
                diameter: origin.diameter + (target.diameter - origin.diameter) * motion
            )
        }

        let leaving = start.filter { !endIDs.contains($0.id) }.map { sprite -> Sprite in
            var shrinking = sprite
            shrinking.diameter = sprite.diameter * max(1 - progress * 2.5, 0)
            return shrinking
        }
        return leaving + moving
    }

    private static func writeGIF(_ frames: [(image: CGImage, delay: Double)], to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
            throw AssetError.encodeFailed(url)
        }
        let fileProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary
        CGImageDestinationSetProperties(destination, fileProperties)
        for frame in frames {
            let properties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frame.delay]] as CFDictionary
            CGImageDestinationAddImage(destination, frame.image, properties)
        }
        guard CGImageDestinationFinalize(destination) else { throw AssetError.encodeFailed(url) }
    }
}
