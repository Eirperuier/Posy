import SwiftUI

struct PosyImportanceKey: LayoutValueKey {
    static let defaultValue: Double = 1
}

extension View {
    /// Sets how prominent this view is inside a ``PosyLayout``.
    ///
    /// A view's area is proportional to its importance: a view of importance
    /// `0.25` has half the diameter of one with importance `1`. Values are
    /// clamped to `0.01...100`. Views without an importance use `1`.
    ///
    /// - Parameter importance: The view's relative prominence.
    public func posyImportance(_ importance: Double) -> some View {
        layoutValue(key: PosyImportanceKey.self, value: importance)
    }
}
