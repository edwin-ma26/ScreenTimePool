import SwiftUI

struct FriendRow: View {
    let friendship: Friendship
    let currentUserId: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(friendship.friendDisplayName(for: currentUserId))
                    .font(.body.bold())

                if friendship.deductsOnGrant(for: currentUserId) {
                    Text("Shared pool enabled")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}
