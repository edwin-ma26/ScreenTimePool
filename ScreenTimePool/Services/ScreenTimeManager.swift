import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import UserNotifications

@MainActor
final class ScreenTimeManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var authorizationError: String?

    private let center = AuthorizationCenter.shared
    private let idleStore = ManagedSettingsStore(named: .idle)
    private let downtimeStore = ManagedSettingsStore(named: .downtime)
    private let exhaustedStore = ManagedSettingsStore(named: .exhausted)
    private let bonusStore = ManagedSettingsStore(named: .bonus)
    private let activityCenter = DeviceActivityCenter()
    private let appGroupStore = AppGroupDataStore.shared

    init() {
        isAuthorized = center.authorizationStatus == .approved
        print("[ScreenTimeManager] init: authorized=\(isAuthorized), status=\(center.authorizationStatus)")
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            isAuthorized = true
            authorizationError = nil
        } catch {
            authorizationError = error.localizedDescription
            isAuthorized = false
        }
    }

    // MARK: - Selection Persistence

    func saveSelection(_ selection: FamilyActivitySelection) {
        let encoder = PropertyListEncoder()
        if let data = try? encoder.encode(selection) {
            appGroupStore.familyActivitySelectionData = data
            print("[ScreenTimeManager] saveSelection: saved \(data.count) bytes, apps=\(selection.applicationTokens.count), categories=\(selection.categoryTokens.count)")
        } else {
            print("[ScreenTimeManager] saveSelection: FAILED to encode")
        }
    }

    func loadSelection() -> FamilyActivitySelection? {
        guard let data = appGroupStore.familyActivitySelectionData else { return nil }
        let decoder = PropertyListDecoder()
        return try? decoder.decode(FamilyActivitySelection.self, from: data)
    }

    // MARK: - Shield Management

    func applyIdleShield() {
        guard let selection = loadSelection() else {
            print("[ScreenTimeManager] applyIdleShield: NO selection found")
            return
        }
        print("[ScreenTimeManager] applyIdleShield: apps=\(selection.applicationTokens.count), categories=\(selection.categoryTokens.count)")
        idleStore.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        idleStore.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        idleStore.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    func removeIdleShield() {
        idleStore.clearAllSettings()
    }

    func applyDowntimeShield() {
        guard let selection = loadSelection() else {
            print("[ScreenTimeManager] applyDowntimeShield: NO selection found")
            return
        }
        print("[ScreenTimeManager] applyDowntimeShield: apps=\(selection.applicationTokens.count), categories=\(selection.categoryTokens.count), domains=\(selection.webDomainTokens.count)")
        downtimeStore.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        downtimeStore.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        downtimeStore.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    func removeDowntimeShield() {
        downtimeStore.clearAllSettings()
    }

    func applyExhaustedShield() {
        guard let selection = loadSelection() else {
            print("[ScreenTimeManager] applyExhaustedShield: NO selection found")
            return
        }
        print("[ScreenTimeManager] applyExhaustedShield: apps=\(selection.applicationTokens.count), categories=\(selection.categoryTokens.count)")
        exhaustedStore.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        exhaustedStore.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        exhaustedStore.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    func removeExhaustedShield() {
        exhaustedStore.clearAllSettings()
    }

    func removeAllShields() {
        print("[ScreenTimeManager] removeAllShields: clearing idle, downtime, exhausted, bonus stores")
        idleStore.clearAllSettings()
        downtimeStore.clearAllSettings()
        exhaustedStore.clearAllSettings()
        bonusStore.clearAllSettings()
    }

    // MARK: - Bonus Shield (Selective Unblock)

    /// Shields only the apps NOT in the granted selection.
    /// managedApps - grantedApps = apps that stay blocked.
    func applySelectiveBonusShield(grantedApps: FamilyActivitySelection) {
        guard let managed = loadSelection() else {
            print("[ScreenTimeManager] applySelectiveBonusShield: no managed selection, skipping")
            return
        }

        let remainingAppTokens = managed.applicationTokens.subtracting(grantedApps.applicationTokens)
        let remainingCatTokens = managed.categoryTokens.subtracting(grantedApps.categoryTokens)
        let remainingWebTokens = managed.webDomainTokens.subtracting(grantedApps.webDomainTokens)

        if remainingAppTokens.isEmpty && remainingCatTokens.isEmpty && remainingWebTokens.isEmpty {
            print("[ScreenTimeManager] applySelectiveBonusShield: all apps granted, no bonus shield needed")
            return
        }

        print("[ScreenTimeManager] applySelectiveBonusShield: shielding \(remainingAppTokens.count) apps, \(remainingCatTokens.count) categories")
        bonusStore.shield.applications = remainingAppTokens.isEmpty ? nil : remainingAppTokens
        bonusStore.shield.applicationCategories = remainingCatTokens.isEmpty
            ? nil
            : .specific(remainingCatTokens)
        bonusStore.shield.webDomains = remainingWebTokens.isEmpty ? nil : remainingWebTokens
    }

    func removeBonusShield() {
        bonusStore.clearAllSettings()
    }

    // MARK: - DeviceActivity Scheduling

    func scheduleUsageEvent(durationMinutes: Int) {
        guard let selection = loadSelection() else {
            print("[ScreenTimeManager] scheduleUsageEvent: NO selection found")
            return
        }

        // Stop previous session monitoring so usage counter resets
        activityCenter.stopMonitoring([.session])

        // Broad schedule: start now, end 1 hour later
        let now = Date()
        let end = now.addingTimeInterval(3600)

        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now),
            intervalEnd: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: end),
            repeats: false
        )

        let event: DeviceActivityEvent
        if #available(iOS 17.4, *) {
            event = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: durationMinutes),
                includesPastActivity: false
            )
            print("[ScreenTimeManager] scheduleUsageEvent: using includesPastActivity=false (iOS 17.4+)")
        } else {
            event = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: durationMinutes)
            )
            print("[ScreenTimeManager] scheduleUsageEvent: WARNING - includesPastActivity not available (pre-iOS 17.4)")
        }

        do {
            try activityCenter.startMonitoring(
                .session,
                during: schedule,
                events: [.sessionThreshold: event]
            )
            print("[ScreenTimeManager] scheduleUsageEvent: scheduled \(durationMinutes)m threshold, apps=\(selection.applicationTokens.count), categories=\(selection.categoryTokens.count), start=\(now)")
        } catch {
            print("[ScreenTimeManager] scheduleUsageEvent: FAILED \(error)")
        }

        let durationSeconds = durationMinutes * 60
        scheduleExpiryNotification(identifier: "session_expiry", seconds: durationSeconds, title: "Session Ended", body: "Your session is over. Break time has started.")
    }

    func scheduleDowntimeMonitoring(durationSeconds: Int) {
        // DeviceActivity requires >= 15 min intervals. For shorter downtimes,
        // skip the schedule — shields are already applied, and the in-app timer
        // or restoreState() handles removal. The notification still fires.
        if durationSeconds >= 900 {
            let now = Date()
            let end = now.addingTimeInterval(TimeInterval(durationSeconds))

            let schedule = DeviceActivitySchedule(
                intervalStart: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now),
                intervalEnd: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: end),
                repeats: false
            )

            do {
                try activityCenter.startMonitoring(.downtimePeriod, during: schedule)
                print("[ScreenTimeManager] scheduleDowntimeMonitoring: scheduled \(durationSeconds)s")
            } catch {
                print("[ScreenTimeManager] scheduleDowntimeMonitoring: FAILED \(error)")
            }
        } else {
            print("[ScreenTimeManager] scheduleDowntimeMonitoring: \(durationSeconds)s < 15min, skipping DeviceActivity (shields already applied)")
        }

        scheduleExpiryNotification(identifier: "downtime_expiry", seconds: durationSeconds, title: "Break Over", body: "Your break is done. Open ScreenTimePool to start a new session.")
    }

    private func scheduleExpiryNotification(identifier: String, seconds: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[ScreenTimeManager] scheduleExpiryNotification: FAILED \(error)")
            }
        }
    }

    func cancelExpiryNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["session_expiry", "downtime_expiry"])
    }

    func stopAllMonitoring() {
        activityCenter.stopMonitoring()
        cancelExpiryNotifications()
    }

    // MARK: - Revocation Check

    func checkAuthorization() {
        isAuthorized = center.authorizationStatus == .approved
    }

    // MARK: - Token Stability Workaround

    func reloadSelectionOnLaunch() {
        if let selection = loadSelection() {
            saveSelection(selection)
        }
    }
}
