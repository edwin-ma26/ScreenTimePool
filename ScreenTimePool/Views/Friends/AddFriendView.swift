import SwiftUI

struct AddFriendView: View {
    let authService: AuthService
    @State private var searchQuery = ""
    @State private var searchResults: [FirestoreUserProfile] = []
    @State private var isSearching = false
    @State private var error: String?
    @State private var successMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("Search by display name...", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { Task { await search() } }

                    Button("Search") {
                        Task { await search() }
                    }
                    .disabled(searchQuery.count < 2)
                }
                .padding()

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                if let successMessage {
                    Text(successMessage)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal)
                }

                if isSearching {
                    ProgressView()
                        .padding()
                } else {
                    List(searchResults, id: \.uid) { user in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(user.displayName)
                                    .font(.body.bold())
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Add") {
                                Task { await sendRequest(to: user) }
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle("Add Friend")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func search() async {
        guard searchQuery.count >= 2 else { return }
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

    private func sendRequest(to user: FirestoreUserProfile) async {
        guard let uid = authService.uid,
              let name = authService.displayName ?? authService.email else { return }

        error = nil
        successMessage = nil

        do {
            let existing = try await FriendshipService.shared.existingFriendship(userId: uid, friendId: user.uid)
            if existing != nil {
                error = "Already friends with \(user.displayName)"
                return
            }

            let hasPending = try await FriendshipService.shared.hasPendingRequest(from: uid, to: user.uid)
            if hasPending {
                error = "Request already pending"
                return
            }

            try await FriendshipService.shared.sendFriendRequest(
                from: (uid: uid, name: name),
                to: (uid: user.uid, name: user.displayName)
            )
            successMessage = "Request sent to \(user.displayName)"
        } catch {
            self.error = error.localizedDescription
        }
    }
}
