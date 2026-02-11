import SwiftUI
import FirebaseFirestore

struct RequestTimeSheet: View {
    let authService: AuthService
    let sessionManager: SessionManager
    @State private var friendships: [Friendship] = []
    @State private var selectedFriendship: Friendship?
    @State private var requestedMinutes: Int = 15
    @State private var isSending = false
    @State private var error: String?
    @State private var successMessage: String?
    @State private var listener: ListenerRegistration?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Friend") {
                    if friendships.isEmpty {
                        Text("No friends yet. Add friends first!")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(friendships) { friendship in
                            Button(action: { selectedFriendship = friendship }) {
                                HStack {
                                    Text(friendship.friendDisplayName(for: authService.uid ?? ""))
                                    Spacer()
                                    if selectedFriendship?.id == friendship.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }

                Section("Minutes") {
                    Stepper("\(requestedMinutes) minutes", value: $requestedMinutes, in: 5...120, step: 5)
                }

                if let selectedFriendship {
                    let deducts = selectedFriendship.deductsOnGrant(for: selectedFriendship.friendId(for: authService.uid ?? ""))
                    if deducts {
                        Section {
                            Label("This will deduct from your friend's pool", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                if let successMessage {
                    Text(successMessage)
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            .navigationTitle("Request Time")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task { await sendRequest() }
                    }
                    .disabled(selectedFriendship == nil || isSending)
                }
            }
            .onAppear { startListening() }
            .onDisappear { listener?.remove() }
        }
    }

    private func startListening() {
        guard let uid = authService.uid else { return }
        listener = FriendshipService.shared.listenToFriendships(userId: uid) { friendships in
            self.friendships = friendships
        }
    }

    private func sendRequest() async {
        guard let uid = authService.uid,
              let name = authService.displayName ?? authService.email,
              let friendship = selectedFriendship else { return }

        isSending = true
        error = nil
        successMessage = nil

        let friendId = friendship.friendId(for: uid)
        let friendName = friendship.friendDisplayName(for: uid)
        let deducts = friendship.deductsOnGrant(for: friendId)

        do {
            try await TimeRequestService.shared.createTimeRequest(
                from: (uid: uid, name: name),
                to: (uid: friendId, name: friendName),
                minutes: requestedMinutes,
                deductsFromGranter: deducts
            )
            successMessage = "Request sent!"
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSending = false
    }
}
