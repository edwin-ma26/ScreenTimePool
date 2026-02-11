import SwiftUI

struct IncomingRequestRow: View {
    let request: TimeRequest
    @State private var showModifySheet = false
    @State private var modifyMinutes: Int = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.fromDisplayName)
                        .font(.body.bold())
                    Text("Requesting \(request.requestedMinutes) minutes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if request.deductsFromGranter {
                        Text("Will deduct from your pool")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button("Approve") {
                    Task {
                        try? await TimeRequestService.shared.approveRequest(request)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button("Modify") {
                    modifyMinutes = request.requestedMinutes
                    showModifySheet = true
                }
                .buttonStyle(.bordered)

                Button("Deny") {
                    Task {
                        try? await TimeRequestService.shared.denyRequest(request)
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showModifySheet) {
            NavigationStack {
                Form {
                    Section("Grant Different Amount") {
                        Stepper("\(modifyMinutes) minutes", value: $modifyMinutes, in: 5...120, step: 5)
                    }

                    Section {
                        Text("\(request.fromDisplayName) requested \(request.requestedMinutes) minutes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Modify Request")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showModifySheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Grant") {
                            Task {
                                try? await TimeRequestService.shared.modifyRequest(request, grantedMinutes: modifyMinutes)
                                showModifySheet = false
                            }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
