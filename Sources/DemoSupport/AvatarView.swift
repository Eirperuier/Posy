import SwiftUI

/// A flexible avatar that fills whatever square it is proposed.
public struct AvatarView: View {
    private let member: DemoMember

    /// Creates an avatar for a member.
    public init(_ member: DemoMember) {
        self.member = member
    }

    /// The avatar's content.
    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let colors = DemoPalette.gradients[member.tint % DemoPalette.gradients.count]
            let fill = LinearGradient(colors: [colors.0, colors.1], startPoint: .top, endPoint: .bottom)

            ZStack {
                if member.isBadge {
                    ScallopShape(lobes: 9).fill(fill)
                } else {
                    Circle().fill(fill)
                }
                face(side: side)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }

    @ViewBuilder
    private func face(side: CGFloat) -> some View {
        switch member.face {
        case .initials(let text):
            Text(text)
                .font(.system(size: side * 0.34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.95))
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: side * 0.42, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.95))
        }
    }
}

/// A scalloped disc that stays inside the circle inscribed in its frame, so a
/// circular collision shape covers it exactly.
public struct ScallopShape: Shape {
    /// The number of lobes around the rim.
    public var lobes: Int

    /// Creates a scalloped shape.
    public init(lobes: Int) {
        self.lobes = lobes
    }

    /// The scalloped outline inside `rect`.
    public func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let depth = radius * 0.1
        let samples = max(lobes, 3) * 24

        var path = Path()
        for step in 0...samples {
            let angle = Double(step) / Double(samples) * 2 * .pi
            let reach = radius - depth + depth * cos(Double(max(lobes, 3)) * angle)
            let point = CGPoint(x: center.x + reach * cos(angle - .pi / 2), y: center.y + reach * sin(angle - .pi / 2))
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
