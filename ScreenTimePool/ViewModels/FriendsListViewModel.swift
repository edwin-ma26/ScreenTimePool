import Foundation
import FirebaseFirestore

@MainActor
final class FriendsListViewModel: ObservableObject {
    @Published var friendships: [Friendship] = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var isLoading = false
    @Published var showAddFriend = false
    @Published var showFriendRequests = false
    @Published var error: String?

    private var friendshipsListener: ListenerRegistration?
    private var requestsListener: ListenerRegistration?
    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    var currentUserId: String { authService.uid ?? "" }

    func startListening() {
        guard let uid = authService.uid else { return }

        friendshipsListener = FriendshipService.shared.listenToFriendships(userId: uid) { [weak self] friendships in
            Task { @MainActor in
                self?.friendships = friendships
            }
        }

        requestsListener = FriendshipService.shared.listenToIncomingRequests(userId: uid) { [weak self] requests in
            Task { @MainActor in
                self?.incomingRequests = requests
            }
        }
    }

    func acceptRequest(_ request: FriendRequest) async {
        do {
            try await FriendshipService.shared.acceptFriendRequest(request)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func declineRequest(_ request: FriendRequest) async {
        do {
            try await FriendshipService.shared.declineFriendRequest(request)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeFriendship(_ friendship: Friendship) async {
        do {
            try await FriendshipService.shared.removeFriendship(friendship)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func stopListening() {
        friendshipsListener?.remove()
        requestsListener?.remove()
    }
}
