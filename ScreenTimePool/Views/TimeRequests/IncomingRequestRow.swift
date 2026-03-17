import SwiftUI
import FamilyControls

struct IncomingRequestRow: View {
    let request: TimeRequest
    @State private var showModifySheet = false
    @State private var modifyMinutes: Int = 15
    @State private var modifyApps = FamilyActivitySelection()
    @State private var showModifyAppPicker = false

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
                    if let data = request.requestedAppsData,
                       let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
                        modifyApps = selection
                    } else if let saved = ScreenTimeManager().loadSelection() {
                        modifyApps = saved
                    }
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

                    Section("Apps to Unblock") {
                        let appCount = modifyApps.applicationTokens.count
                        let catCount = modifyApps.categoryTokens.count
                        Text("\(appCount) app\(appCount == 1 ? "" : "s"), \(catCount) categor\(catCount == 1 ? "y" : "ies") selected")
                            .foregroundStyle(.secondary)

                        Button("Choose Apps") { showModifyAppPicker = true }

                        HStack {
                            Button("Select All") {
                                if let saved = ScreenTimeManager().loadSelection() {
                                    modifyApps = saved
                                }
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)

                            Button("Deselect All") {
                                modifyApps = FamilyActivitySelection()
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }

                    Section {
                        Text("\(request.fromDisplayName) requested \(request.requestedMinutes) minutes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Modify Request")
                .familyActivityPicker(isPresented: $showModifyAppPicker, selection: $modifyApps)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showModifySheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Grant") {
                            Task {
                                let appsData = try? PropertyListEncoder().encode(modifyApps)
                                try? await TimeRequestService.shared.modifyRequest(request, grantedMinutes: modifyMinutes, grantedAppsData: appsData)
                                showModifySheet = false
                            }
                        }
                    }
                }
            }
            .presentationDetents([.large])
        }
    }
}
