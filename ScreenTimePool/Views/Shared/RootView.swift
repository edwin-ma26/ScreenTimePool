import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @EnvironmentObject var sessionManager: SessionManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if authService.isLoading {
                LoadingView()
            } else if !authService.isAuthenticated || !hasCompletedOnboarding {
                OnboardingFlow(authService: authService, screenTimeManager: screenTimeManager)
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
        .animation(.easeInOut, value: hasCompletedOnboarding)
    }
}

struct OnboardingFlow: View {
    @StateObject var viewModel: OnboardingViewModel

    init(authService: AuthService, screenTimeManager: ScreenTimeManager) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(
            authService: authService,
            screenTimeManager: screenTimeManager
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.currentStep {
                case .welcome:
                    WelcomeStepView(viewModel: viewModel)
                case .auth:
                    AuthStepView(viewModel: viewModel)
                case .familyControls:
                    FamilyControlsAuthView(viewModel: viewModel)
                case .appSelection:
                    AppSelectionView(viewModel: viewModel)
                case .poolConfig:
                    PoolConfigView(viewModel: viewModel)
                }
            }
        }
    }
}
