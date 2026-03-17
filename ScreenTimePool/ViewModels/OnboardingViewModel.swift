import Foundation
import FamilyControls

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case auth
    case familyControls
    case appSelection
    case poolConfig
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isLoading = false
    @Published var error: String?

    // Auth fields
    @Published var email = ""
    @Published var password = ""
    @Published var displayName = ""
    @Published var isSignUp = true

    // Pool config fields
    @Published var dailyPoolMinutes: Int = 120
    @Published var sessionDurationMinutes: Int = 25
    @Published var downtimeDurationMinutes: Int = 5

    // App selection
    @Published var familyActivitySelection = FamilyActivitySelection()

    private let authService: AuthService
    private let screenTimeManager: ScreenTimeManager

    init(authService: AuthService, screenTimeManager: ScreenTimeManager) {
        self.authService = authService
        self.screenTimeManager = screenTimeManager
    }

    func nextStep() {
        guard let nextIndex = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextIndex
    }

    func previousStep() {
        guard let prevIndex = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prevIndex
    }

    // MARK: - Auth

    func authenticate() async {
        isLoading = true
        error = nil

        do {
            if isSignUp {
                try await authService.signUp(email: email, password: password, displayName: displayName)
                if let uid = authService.uid {
                    let profile = FirestoreUserProfile(
                        uid: uid,
                        displayName: displayName,
                        displayNameLowercase: displayName.lowercased(),
                        email: email,
                        dailyPoolMinutes: dailyPoolMinutes,
                        sessionDurationMinutes: sessionDurationMinutes,
                        downtimeDurationMinutes: downtimeDurationMinutes,
                        remainingPoolSeconds: dailyPoolMinutes * 60,
                        lastPoolResetDate: Date()
                    )
                    try await FirestoreService.shared.createUser(profile)
                }
            } else {
                try await authService.signIn(email: email, password: password)
            }
            nextStep()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Family Controls

    func requestFamilyControlsAuth() async {
        await screenTimeManager.requestAuthorization()
        if screenTimeManager.isAuthorized {
            nextStep()
        } else {
            error = screenTimeManager.authorizationError
        }
    }

    // MARK: - App Selection

    func saveAppSelection() {
        screenTimeManager.saveSelection(familyActivitySelection)
        screenTimeManager.applyIdleShield()
        nextStep()
    }

    // MARK: - Pool Config

    func completeOnboarding() async {
        isLoading = true

        let store = AppGroupDataStore.shared
        store.dailyPoolMinutes = dailyPoolMinutes
        store.sessionDurationMinutes = sessionDurationMinutes
        store.downtimeDurationMinutes = downtimeDurationMinutes
        store.remainingPoolSeconds = dailyPoolMinutes * 60
        store.lastPoolResetDate = .now

        if let uid = authService.uid {
            try? await FirestoreService.shared.updateSettings(
                uid: uid,
                dailyPoolMinutes: dailyPoolMinutes,
                sessionDurationMinutes: sessionDurationMinutes,
                downtimeDurationMinutes: downtimeDurationMinutes
            )
        }

        screenTimeManager.applyIdleShield()
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        isLoading = false
    }
}
