import SwiftUI
import FirebaseFirestore

struct FriendsListView: View {
    @EnvironmentObject var authService: AuthService
    @State private var friendships: [Friendship] = []
    @State private var incomingRequests: [FriendRequest] = []
    @State private var showAddFriend = false
    @State private var showFriendRequests = false
    @State private var error: String?

    @State private var friendshipsListener: ListenerRegistration?
    @State private var requestsListener: ListenerRegistration?

    var body: some View {
        NavigationStack {
            List {
                if !incomingRequests.isEmpty {
                    Section {
                        Button(action: { showFriendRequests = true }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundStyle(.blue)
                                Text("\(incomingRequests.count) pending request\(incomingRequests.count == 1 ? "" : "s")")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Friends") {
                    if friendships.isEmpty {
                        ContentUnavailableView(
                            "No Friends Yet",
                            systemImage: "person.2",
                            description: Text("Add friends to request screen time from them.")
                        )
                    } else {
                        ForEach(friendships) { friendship in
                            NavigationLink {
                                FriendDetailView(
                                    friendship: friendship,
                                    currentUserId: authService.uid ?? ""
                                )
                            } label: {
                                FriendRow(
                                    friendship: friendship,
                                    currentUserId: authService.uid ?? ""
                                )
                            }
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    try? await FriendshipService.shared.removeFriendship(friendships[index])
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddFriend = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView(authService: authService)
            }
            .sheet(isPresented: $showFriendRequests) {
                FriendRequestsSheet(
                    requests: incomingRequests
                )
            }
            .onAppear { startListening() }
            .onDisappear { stopListening() }
        }
    }

    private func startListening() {
        guard let uid = authService.uid else { return }

        friendshipsListener = FriendshipService.shared.listenToFriendships(userId: uid) { friendships in
            self.friendships = friendships
        }

        requestsListener = FriendshipService.shared.listenToIncomingRequests(userId: uid) { requests in
            self.incomingRequests = requests
        }
    }

    private func stopListening() {
        friendshipsListener?.remove()
        requestsListener?.remove()
    }
}
