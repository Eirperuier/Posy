import SwiftUI

/// A participant in the demo group chat.
public struct DemoMember: Identifiable, Hashable, Sendable {
    /// What is drawn inside the member's avatar.
    public enum Face: Hashable, Sendable {
        /// One or two letters.
        case initials(String)
        /// An SF Symbol name.
        case symbol(String)
    }

    /// A stable identifier.
    public var id: Int
    /// What is drawn inside the avatar.
    public var face: Face
    /// Index into ``DemoPalette/gradients``.
    public var tint: Int
    /// Whether the avatar is drawn as a scalloped badge instead of a disc.
    public var isBadge: Bool
    /// The importance handed to the layout.
    public var importance: Double

    /// Creates a member.
    public init(id: Int, face: Face, tint: Int, isBadge: Bool = false, importance: Double) {
        self.id = id
        self.face = face
        self.tint = tint
        self.isBadge = isBadge
        self.importance = importance
    }
}

extension DemoMember {
    /// A fixed roster whose first member is the host.
    public static let roster: [DemoMember] = [
        DemoMember(id: 0, face: .initials("MA"), tint: 0, importance: 1),
        DemoMember(id: 1, face: .initials("JB"), tint: 5, isBadge: true, importance: 0.4),
        DemoMember(id: 2, face: .initials("KO"), tint: 1, importance: 0.55),
        DemoMember(id: 3, face: .symbol("headphones"), tint: 2, importance: 0.22),
        DemoMember(id: 4, face: .initials("LR"), tint: 3, importance: 0.5),
        DemoMember(id: 5, face: .initials("JA"), tint: 4, importance: 0.45),
        DemoMember(id: 6, face: .symbol("music.note"), tint: 2, importance: 0.2),
        DemoMember(id: 7, face: .initials("SE"), tint: 6, importance: 0.3),
        DemoMember(id: 8, face: .initials("TI"), tint: 7, importance: 0.5),
        DemoMember(id: 9, face: .symbol("guitars.fill"), tint: 2, importance: 0.18),
        DemoMember(id: 10, face: .initials("NW"), tint: 1, importance: 0.28),
        DemoMember(id: 11, face: .initials("PD"), tint: 3, importance: 0.35),
        DemoMember(id: 12, face: .initials("HU"), tint: 5, importance: 0.25),
        DemoMember(id: 13, face: .symbol("star.fill"), tint: 4, importance: 0.16),
        DemoMember(id: 14, face: .initials("RV"), tint: 6, importance: 0.4),
        DemoMember(id: 15, face: .initials("EM"), tint: 0, importance: 0.3),
        DemoMember(id: 16, face: .symbol("camera.fill"), tint: 3, importance: 0.2),
        DemoMember(id: 17, face: .initials("OS"), tint: 7, importance: 0.38),
        DemoMember(id: 18, face: .initials("YU"), tint: 5, isBadge: true, importance: 0.26),
        DemoMember(id: 19, face: .initials("CB"), tint: 1, importance: 0.33),
    ]
}

/// Colors shared by the demo views.
public enum DemoPalette {
    /// The backdrop behind every cluster.
    public static let background = Color(red: 0.05, green: 0.10, blue: 0.20)

    /// Top and bottom colors of each avatar gradient.
    public static let gradients: [(Color, Color)] = [
        (Color(red: 0.98, green: 0.62, blue: 0.45), Color(red: 0.86, green: 0.33, blue: 0.47)),
        (Color(red: 0.62, green: 0.53, blue: 0.99), Color(red: 0.41, green: 0.30, blue: 0.86)),
        (Color(red: 0.36, green: 0.78, blue: 0.98), Color(red: 0.18, green: 0.52, blue: 0.90)),
        (Color(red: 0.43, green: 0.88, blue: 0.72), Color(red: 0.13, green: 0.62, blue: 0.58)),
        (Color(red: 0.76, green: 0.70, blue: 1.00), Color(red: 0.57, green: 0.48, blue: 0.96)),
        (Color(red: 0.72, green: 0.86, blue: 0.97), Color(red: 0.50, green: 0.67, blue: 0.90)),
        (Color(red: 0.99, green: 0.80, blue: 0.40), Color(red: 0.95, green: 0.55, blue: 0.25)),
        (Color(red: 0.95, green: 0.55, blue: 0.80), Color(red: 0.72, green: 0.31, blue: 0.70)),
    ]
}
