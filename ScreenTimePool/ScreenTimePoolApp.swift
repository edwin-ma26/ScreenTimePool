import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
struct ScreenTimePoolApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var authService = AuthService()
    @StateObject private var screenTimeManager = ScreenTimeManager()
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var pushService = PushNotificationService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalUserProfile.self,
            LocalSessionState.self,
            LocalAppSelection.self,
            LocalTimeRequest.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(screenTimeManager)
                .environmentObject(sessionManager)
                .environmentObject(pushService)
                .modelContainer(sharedModelContainer)
                .onAppear {
                    setupApp()
                }
                .onChange(of: authService.isAuthenticated) { _, isAuth in
                    if isAuth {
                        sessionManager.startApprovedRequestListener()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    sessionManager.pauseForBackground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    sessionManager.resumeFromBackground()
                    sessionManager.checkMidnightReset()
                    screenTimeManager.checkAuthorization()
                    screenTimeManager.reloadSelectionOnLaunch()
                }
        }
    }

    private func setupApp() {
        UNUserNotificationCenter.current().delegate = pushService
        AuthServiceProvider.shared = authService

        sessionManager.configure(
            screenTimeManager: screenTimeManager,
            modelContext: sharedModelContainer.mainContext
        )

        screenTimeManager.reloadSelectionOnLaunch()

        Task {
            await pushService.requestPermission()
            if let uid = authService.uid {
                await pushService.registerToken(for: uid)
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
}
