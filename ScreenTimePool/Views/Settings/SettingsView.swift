import SwiftUI
import FamilyControls

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @EnvironmentObject var sessionManager: SessionManager
    @State private var dailyPoolMinutes: Int
    @State private var sessionDurationMinutes: Int
    @State private var downtimeDurationMinutes: Int
    @State private var showAppPicker = false
    @State private var showDeleteConfirmation = false
    @State private var familyActivitySelection: FamilyActivitySelection
    @State private var isSaving = false
    @State private var error: String?
    @State private var expandedPicker: String?
    @State private var resetDowntimeAfterSession: Bool

    // Passcode state
    @State private var showPasscodePrompt = false
    @State private var showAppPickerPasscodePrompt = false
    @State private var showSetPasscode = false
    @State private var enteredPasscode = ""
    @State private var newPasscode = ""
    @State private var confirmPasscode = ""
    @State private var currentPasscodeForChange = ""
    @State private var passcodeError: String?

    init() {
        let store = AppGroupDataStore.shared
        _dailyPoolMinutes = State(initialValue: store.dailyPoolMinutes)
        _sessionDurationMinutes = State(initialValue: store.sessionDurationMinutes)
        _downtimeDurationMinutes = State(initialValue: store.downtimeDurationMinutes)
        _familyActivitySelection = State(initialValue: FamilyActivitySelection())
        _resetDowntimeAfterSession = State(initialValue: store.resetDowntimeAfterSession)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Pool Configuration") {
                    TimePickerRow(
                        title: "Daily Pool",
                        detail: "Total screen time per day",
                        minutes: $dailyPoolMinutes,
                        maxMinutes: 1380,
                        isExpanded: expandedPicker == "pool",
                        onTap: { togglePicker("pool") }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    TimePickerRow(
                        title: "Session Duration",
                        detail: "Length of each session",
                        minutes: $sessionDurationMinutes,
                        maxMinutes: 1380,
                        isExpanded: expandedPicker == "session",
                        onTap: { togglePicker("session") }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    TimePickerRow(
                        title: "Downtime",
                        detail: "Break between sessions",
                        minutes: $downtimeDurationMinutes,
                        maxMinutes: 1380,
                        isExpanded: expandedPicker == "downtime",
                        onTap: { togglePicker("downtime") }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    Toggle("Reset downtime after bonus session", isOn: $resetDowntimeAfterSession)

                    Button(action: {
                        if AppGroupDataStore.shared.settingsPasscode != nil {
                            enteredPasscode = ""
                            passcodeError = nil
                            showPasscodePrompt = true
                        } else {
                            Task { await saveSettings() }
                        }
                    }) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Save Changes")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving)

                    Button(action: {
                        currentPasscodeForChange = ""
                        newPasscode = ""
                        confirmPasscode = ""
                        passcodeError = nil
                        showSetPasscode = true
                    }) {
                        HStack {
                            Spacer()
                            Text(AppGroupDataStore.shared.settingsPasscode != nil ? "Change Passcode" : "Set Passcode")
                            Spacer()
                        }
                    }
                }

                Section("App Selection") {
                    Button("Change Managed Apps") {
                        showAppPicker = true
                    }
                }

                Section("Account") {
                    if let email = authService.email {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(email)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let name = authService.displayName {
                        HStack {
                            Text("Display Name")
                            Spacer()
                            Text(name)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Sign Out", role: .destructive) {
                        try? authService.signOut()
                        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    }

                    Button("Delete Account", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showAppPicker) {
                NavigationStack {
                    FamilyActivityPicker(selection: $familyActivitySelection)
                        .navigationTitle("Select Apps")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    if AppGroupDataStore.shared.settingsPasscode != nil {
                                        enteredPasscode = ""
                                        passcodeError = nil
                                        showAppPickerPasscodePrompt = true
                                    } else {
                                        screenTimeManager.saveSelection(familyActivitySelection)
                                        sessionManager.reapplyCurrentShields()
                                        showAppPicker = false
                                    }
                                }
                            }
                        }
                        .alert("Enter Passcode", isPresented: $showAppPickerPasscodePrompt) {
                            TextField("Passcode", text: $enteredPasscode)
                                .keyboardType(.numberPad)
                            Button("Confirm") {
                                if enteredPasscode == AppGroupDataStore.shared.settingsPasscode {
                                    screenTimeManager.saveSelection(familyActivitySelection)
                                    sessionManager.reapplyCurrentShields()
                                    showAppPicker = false
                                } else {
                                    passcodeError = "Incorrect passcode"
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            if let passcodeError {
                                Text(passcodeError)
                            } else {
                                Text("Enter your passcode to save app selection.")
                            }
                        }
                }
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
            .alert("Enter Passcode", isPresented: $showPasscodePrompt) {
                TextField("Passcode", text: $enteredPasscode)
                    .keyboardType(.numberPad)
                Button("Confirm") {
                    if enteredPasscode == AppGroupDataStore.shared.settingsPasscode {
                        Task { await saveSettings() }
                    } else {
                        passcodeError = "Incorrect passcode"
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let passcodeError {
                    Text(passcodeError)
                } else {
                    Text("Enter your passcode to save settings.")
                }
            }
            .alert(AppGroupDataStore.shared.settingsPasscode != nil ? "Change Passcode" : "Set Passcode", isPresented: $showSetPasscode) {
                if AppGroupDataStore.shared.settingsPasscode != nil {
                    TextField("Current Passcode", text: $currentPasscodeForChange)
                        .keyboardType(.numberPad)
                }
                TextField("New Passcode", text: $newPasscode)
                    .keyboardType(.numberPad)
                TextField("Confirm Passcode", text: $confirmPasscode)
                    .keyboardType(.numberPad)
                Button("Save") {
                    if let existing = AppGroupDataStore.shared.settingsPasscode {
                        guard currentPasscodeForChange == existing else {
                            passcodeError = "Current passcode is incorrect"
                            return
                        }
                    }
                    guard !newPasscode.isEmpty else {
                        passcodeError = "Passcode cannot be empty"
                        return
                    }
                    guard newPasscode == confirmPasscode else {
                        passcodeError = "Passcodes do not match"
                        return
                    }
                    AppGroupDataStore.shared.settingsPasscode = newPasscode
                    passcodeError = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let passcodeError {
                    Text(passcodeError)
                } else if AppGroupDataStore.shared.settingsPasscode != nil {
                    Text("Enter your current passcode, then set a new one.")
                } else {
                    Text("Set a passcode to protect settings.")
                }
            }
            .onAppear {
                if let selection = screenTimeManager.loadSelection() {
                    familyActivitySelection = selection
                }
            }
        }
    }

    private func togglePicker(_ name: String) {
        withAnimation(.easeInOut(duration: 0.25)) {
            expandedPicker = expandedPicker == name ? nil : name
        }
    }

    private func saveSettings() async {
        isSaving = true
        error = nil

        let store = AppGroupDataStore.shared
        store.dailyPoolMinutes = dailyPoolMinutes
        store.sessionDurationMinutes = sessionDurationMinutes
        store.downtimeDurationMinutes = downtimeDurationMinutes
        store.resetDowntimeAfterSession = resetDowntimeAfterSession

        if let uid = authService.uid {
            do {
                try await FirestoreService.shared.updateSettings(
                    uid: uid,
                    dailyPoolMinutes: dailyPoolMinutes,
                    sessionDurationMinutes: sessionDurationMinutes,
                    downtimeDurationMinutes: downtimeDurationMinutes
                )
            } catch {
                self.error = error.localizedDescription
            }
        }

        isSaving = false
    }

    private func deleteAccount() async {
        if let uid = authService.uid {
            try? await FirestoreService.shared.deleteUser(uid: uid)
        }
        try? await authService.deleteAccount()
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
}
