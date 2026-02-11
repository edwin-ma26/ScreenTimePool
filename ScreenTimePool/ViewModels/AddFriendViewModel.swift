import Foundation

@MainActor
final class AddFriendViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [FirestoreUserProfile] = []
    @Published var isSearching = false
    @Published var isSending = false
    @Published var error: String?
    @Published var successMessage: String?

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func search() async {
        guard searchQuery.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true
        error = nil

        do {
            let results = try await FirestoreService.shared.searchUsers(query: searchQuery)
            searchResults = results.filter { $0.uid != authService.uid }
        } catch {
            self.error = error.localizedDescription
        }

        isSearching = false
    }

    func sendFriendRequest(to user: FirestoreUserProfile) async {
        guard let uid = authService.uid,
              let name = authService.displayName ?? authService.email else { return }

        isSending = true
        error = nil
        successMessage = nil

        do {
            let existing = try await FriendshipService.shared.existingFriendship(userId: uid, friendId: user.uid)
            if existing != nil {
                error = "You're already friends with \(user.displayName)"
                isSending = false
                return
            }

            let hasPending = try await FriendshipService.shared.hasPendingRequest(from: uid, to: user.uid)
            if hasPending {
                error = "You already have a pending request to \(user.displayName)"
                isSending = false
                return
            }

            try await FriendshipService.shared.sendFriendRequest(
                from: (uid: uid, name: name),
                to: (uid: user.uid, name: user.displayName)
            )
            successMessage = "Friend request sent to \(user.displayName)"
        } catch {
            self.error = error.localizedDescription
        }

        isSending = false
    }
}
