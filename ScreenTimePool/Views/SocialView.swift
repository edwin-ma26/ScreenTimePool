import SwiftUI
import FirebaseFirestore

struct SocialView: View {
    @EnvironmentObject var authService: AuthService

    @State private var friendships: [Friendship] = []
    @State private var incomingRequests: [FriendRequest] = []
    @State private var leaderboardEntries: [LeaderboardEntry] = []
    @State private var isLoading = false
    @State private var showAddFriend = false
    @State private var showFriendRequests = false

    @State private var friendshipsListener: ListenerRegistration?
    @State private var requestsListener: ListenerRegistration?

    var sortedEntries: [LeaderboardEntry] {
        leaderboardEntries.sorted {
            let used0 = ($0.dailyPoolMinutes * 60) - $0.remainingPoolSeconds
            let used1 = ($1.dailyPoolMinutes * 60) - $1.remainingPoolSeconds
            return used0 < used1
        }
    }

    var body: some View {
        NavigationStack {
            List {
                pendingRequestsSection
                leaderboardEntriesSection
                friendsSection
            }
            .navigationTitle("Social")
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
                FriendRequestsSheet(requests: incomingRequests)
            }
            .onAppear { startListening() }
            .onDisappear { stopListening() }
            .onChange(of: friendships) { _, _ in
                Task { await loadLeaderboard() }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var pendingRequestsSection: some View {
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
    }

    @ViewBuilder
    private var leaderboardEntriesSection: some View {
        Section("Leaderboard") {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if sortedEntries.isEmpty {
                ContentUnavailableView(
                    "No Friends Yet",
                    systemImage: "person.2",
                    description: Text("Add friends to see the leaderboard.")
                )
            } else {
                ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
                    let isCurrent = entry.id == (authService.uid ?? "")
                    LeaderboardRow(rank: index + 1, entry: entry, isCurrentUser: isCurrent)
                }
            }
        }
    }

    private var friendsSection: some View {
        Section("Friends") {
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

    // MARK: - Listeners

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

    private func loadLeaderboard() async {
        guard let uid = authService.uid else { return }
        isLoading = true

        var entries: [LeaderboardEntry] = []

        if let myProfile = try? await FirestoreService.shared.getUser(uid: uid) {
            entries.append(LeaderboardEntry(
                uid: uid,
                displayName: myProfile.displayName,
                remainingPoolSeconds: myProfile.remainingPoolSeconds,
                dailyPoolMinutes: myProfile.dailyPoolMinutes
            ))
        }

        for friendship in friendships {
            let friendId = friendship.friendId(for: uid)
            if let profile = try? await FirestoreService.shared.getUser(uid: friendId) {
                entries.append(LeaderboardEntry(
                    uid: friendId,
                    displayName: profile.displayName,
                    remainingPoolSeconds: profile.remainingPoolSeconds,
                    dailyPoolMinutes: profile.dailyPoolMinutes
                ))
            }
        }

        leaderboardEntries = entries
        isLoading = false
    }
}

// MARK: - Supporting Types

struct LeaderboardEntry: Identifiable {
    let id: String
    let displayName: String
    let remainingPoolSeconds: Int
    let dailyPoolMinutes: Int

    init(uid: String, displayName: String, remainingPoolSeconds: Int, dailyPoolMinutes: Int) {
        self.id = uid
        self.displayName = displayName
        self.remainingPoolSeconds = remainingPoolSeconds
        self.dailyPoolMinutes = dailyPoolMinutes
    }

    var remainingText: String {
        let hours = remainingPoolSeconds / 3600
        let minutes = (remainingPoolSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        }
        return "\(minutes)m left"
    }

    var usagePercent: Double {
        let totalSeconds = dailyPoolMinutes * 60
        guard totalSeconds > 0 else { return 0 }
        let raw = Double(totalSeconds - remainingPoolSeconds) / Double(totalSeconds)
        return min(max(raw, 0), 1)
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let entry: LeaderboardEntry
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(rankColor)
                .frame(width: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                nameRow
                ProgressView(value: entry.usagePercent)
                    .tint(progressColor)
            }

            Spacer()

            Text(entry.remainingText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var nameRow: some View {
        HStack(spacing: 4) {
            Text(entry.displayName)
                .font(.body.weight(isCurrentUser ? .bold : .regular))
            if isCurrentUser {
                Text("(You)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }

    private var progressColor: Color {
        if entry.usagePercent > 0.9 { return .red }
        if entry.usagePercent > 0.6 { return .orange }
        return .green
    }
}
