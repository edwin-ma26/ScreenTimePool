import SwiftUI

struct FriendRequestsSheet: View {
    let requests: [FriendRequest]
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if requests.isEmpty {
                    ContentUnavailableView(
                        "No Pending Requests",
                        systemImage: "person.badge.clock",
                        description: Text("You don't have any pending friend requests.")
                    )
                } else {
                    ForEach(requests) { request in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(request.fromDisplayName)
                                    .font(.body.bold())
                                Text("Wants to be friends")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            HStack(spacing: 8) {
                                Button {
                                    Task {
                                        try? await FriendshipService.shared.acceptFriendRequest(request)
                                    }
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.title2)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    Task {
                                        try? await FriendshipService.shared.declineFriendRequest(request)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.title2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Friend Requests")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
