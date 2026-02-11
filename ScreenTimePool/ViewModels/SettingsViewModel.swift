import Foundation
import FamilyControls

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var dailyPoolMinutes: Int
    @Published var sessionDurationMinutes: Int
    @Published var downtimeDurationMinutes: Int
    @Published var familyActivitySelection: FamilyActivitySelection
    @Published var isSaving = false
    @Published var showAppPicker = false
    @Published var showDeleteConfirmation = false
    @Published var error: String?

    private let authService: AuthService
    private let screenTimeManager: ScreenTimeManager
    private let appGroupStore = AppGroupDataStore.shared

    init(authService: AuthService, screenTimeManager: ScreenTimeManager) {
        self.authService = authService
        self.screenTimeManager = screenTimeManager

        self.dailyPoolMinutes = appGroupStore.dailyPoolMinutes
        self.sessionDurationMinutes = appGroupStore.sessionDurationMinutes
        self.downtimeDurationMinutes = appGroupStore.downtimeDurationMinutes
        self.familyActivitySelection = screenTimeManager.loadSelection() ?? FamilyActivitySelection()
    }

    func saveSettings() async {
        isSaving = true
        error = nil

        appGroupStore.dailyPoolMinutes = dailyPoolMinutes
        appGroupStore.sessionDurationMinutes = sessionDurationMinutes
        appGroupStore.downtimeDurationMinutes = downtimeDurationMinutes

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

    func saveAppSelection() {
        screenTimeManager.saveSelection(familyActivitySelection)
    }

    func signOut() {
        try? authService.signOut()
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }

    func deleteAccount() async {
        do {
            if let uid = authService.uid {
                try await FirestoreService.shared.deleteUser(uid: uid)
            }
            try await authService.deleteAccount()
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        } catch {
            self.error = error.localizedDescription
        }
    }
}
