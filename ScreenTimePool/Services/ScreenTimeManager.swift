import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

@MainActor
final class ScreenTimeManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var authorizationError: String?

    private let center = AuthorizationCenter.shared
    private let idleStore = ManagedSettingsStore(named: .idle)
    private let downtimeStore = ManagedSettingsStore(named: .downtime)
    private let exhaustedStore = ManagedSettingsStore(named: .exhausted)
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
        idleStore.clearAllSettings()
        downtimeStore.clearAllSettings()
        exhaustedStore.clearAllSettings()
    }

    // MARK: - DeviceActivity Scheduling

    func scheduleSessionMonitoring(durationSeconds: Int) {
        let now = Date()
        let end = now.adding(seconds: durationSeconds)

        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd: Calendar.current.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )

        do {
            try activityCenter.startMonitoring(.session, during: schedule)
        } catch {
            print("Failed to schedule session monitoring: \(error)")
        }
    }

    func scheduleDowntimeMonitoring(durationSeconds: Int) {
        let now = Date()
        let end = now.adding(seconds: durationSeconds)

        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd: Calendar.current.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )

        do {
            try activityCenter.startMonitoring(.downtimePeriod, during: schedule)
        } catch {
            print("Failed to schedule downtime monitoring: \(error)")
        }
    }

    func stopAllMonitoring() {
        activityCenter.stopMonitoring()
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
