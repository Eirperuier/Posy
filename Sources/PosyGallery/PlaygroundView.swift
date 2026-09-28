import DemoSupport
import Posy
import SwiftUI

/// A live cluster to add, remove, and promote members in, for judging how
/// changes animate.
struct PlaygroundView: View {
    private static let promotedImportance = 1.3

    @State private var members = Array(DemoMember.roster.prefix(6))
    @State private var spacing: CGFloat = 5

    var body: some View {
        VStack(spacing: 16) {
            PosyLayout(spacing: spacing) {
                ForEach(members) { member in
                    AvatarView(member)
                        .posyImportance(member.importance)
                        .transition(.scale.combined(with: .opacity))
                        .onTapGesture { promote(member) }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DemoPalette.background)
            .animation(.spring(response: 0.45, dampingFraction: 0.72), value: members)

            HStack(spacing: 12) {
                Button("Add member", action: add)
                    .disabled(members.count == DemoMember.roster.count)
                Button("Remove member", action: removeRandom)
                    .disabled(members.count <= 1)
                Button("Reset") { members = Array(DemoMember.roster.prefix(6)) }
                Divider().frame(height: 18)
                Text("Spacing")
                Slider(value: $spacing, in: 0...16)
                    .frame(width: 160)
                Spacer()
                Text("Tap a member to promote it")
                    .foregroundStyle(.secondary)
            }
            .padding([.horizontal, .bottom], 16)
        }
    }

    private func add() {
        guard let next = DemoMember.roster.first(where: { candidate in !members.contains { $0.id == candidate.id } }) else {
            return
        }
        members.append(next)
    }

    private func removeRandom() {
        guard members.count > 1 else { return }
        members.remove(at: Int.random(in: 1..<members.count))
    }

    private func promote(_ member: DemoMember) {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        let wasPromoted = members[index].importance == Self.promotedImportance
        let defaults = Dictionary(uniqueKeysWithValues: DemoMember.roster.map { ($0.id, $0.importance) })
        for other in members.indices {
            members[other].importance = defaults[members[other].id] ?? members[other].importance
        }
        if !wasPromoted {
            members[index].importance = Self.promotedImportance
        }
    }
}
