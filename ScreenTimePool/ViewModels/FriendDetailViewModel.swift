import Foundation

@MainActor
final class FriendDetailViewModel: ObservableObject {
    @Published var friendship: Friendship
    @Published var deductsOnGrant: Bool
    @Published var isSaving = false
    @Published var error: String?

    private let currentUserId: String

    init(friendship: Friendship, currentUserId: String) {
        self.friendship = friendship
        self.currentUserId = currentUserId
        self.deductsOnGrant = friendship.deductsOnGrant(for: currentUserId)
    }

    var friendDisplayName: String {
        friendship.friendDisplayName(for: currentUserId)
    }

    var friendId: String {
        friendship.friendId(for: currentUserId)
    }

    func toggleDeduction() async {
        guard let docId = friendship.id else { return }
        isSaving = true
        let newValue = !deductsOnGrant

        let field = currentUserId == friendship.user1Id ? "user1DeductsOnGrant" : "user2DeductsOnGrant"

        do {
            try await FriendshipService.shared.updateDeductionToggle(
                friendshipId: docId,
                field: field,
                value: newValue
            )
            deductsOnGrant = newValue
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    func removeFriendship() async {
        do {
            try await FriendshipService.shared.removeFriendship(friendship)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
