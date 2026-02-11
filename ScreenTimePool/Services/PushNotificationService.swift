import Foundation
import UIKit
import FirebaseMessaging
import UserNotifications

@MainActor
final class PushNotificationService: NSObject, ObservableObject {
    @Published var fcmToken: String?
    @Published var permissionGranted = false

    override init() {
        super.init()
        Messaging.messaging().delegate = self
    }

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            permissionGranted = granted
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            print("Push notification permission error: \(error)")
        }
    }

    func registerToken(for uid: String) async {
        guard let token = fcmToken else { return }
        try? await FirestoreService.shared.updateFCMToken(uid: uid, token: token)
    }
}

extension PushNotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            self.fcmToken = fcmToken
            if let token = fcmToken, let uid = AuthServiceProvider.shared?.uid {
                try? await FirestoreService.shared.updateFCMToken(uid: uid, token: token)
            }
        }
    }
}

extension PushNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            handleNotificationTap(userInfo: userInfo)
        }
        completionHandler()
    }

    @MainActor
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        if let type = userInfo["type"] as? String {
            NotificationCenter.default.post(
                name: .didReceiveDeepLink,
                object: nil,
                userInfo: ["type": type]
            )
        }
    }
}

extension Notification.Name {
    static let didReceiveDeepLink = Notification.Name("didReceiveDeepLink")
}
