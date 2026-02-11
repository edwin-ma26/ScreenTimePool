import SwiftUI

struct FriendDetailView: View {
    let friendship: Friendship
    let currentUserId: String
    @State private var deductsOnGrant: Bool
    @State private var showRemoveConfirmation = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(friendship: Friendship, currentUserId: String) {
        self.friendship = friendship
        self.currentUserId = currentUserId
        _deductsOnGrant = State(initialValue: friendship.deductsOnGrant(for: currentUserId))
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(friendship.friendDisplayName(for: currentUserId))
                            .font(.title2.bold())
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Pool Sharing") {
                Toggle("Deduct from my pool when granting time", isOn: $deductsOnGrant)
                    .onChange(of: deductsOnGrant) { _, newValue in
                        Task { await updateDeduction(newValue) }
                    }

                Text("When enabled, time you grant to this friend will be deducted from your own daily pool.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Remove Friend", role: .destructive) {
                    showRemoveConfirmation = true
                }
            }

            if let error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Friend Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Remove Friend", isPresented: $showRemoveConfirmation) {
            Button("Remove", role: .destructive) {
                Task {
                    try? await FriendshipService.shared.removeFriendship(friendship)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove \(friendship.friendDisplayName(for: currentUserId)) as a friend?")
        }
    }

    private func updateDeduction(_ value: Bool) async {
        guard let docId = friendship.id else { return }
        let field = currentUserId == friendship.user1Id ? "user1DeductsOnGrant" : "user2DeductsOnGrant"
        do {
            try await FriendshipService.shared.updateDeductionToggle(
                friendshipId: docId,
                field: field,
                value: value
            )
        } catch {
            self.error = error.localizedDescription
            deductsOnGrant = !value
        }
    }
}
