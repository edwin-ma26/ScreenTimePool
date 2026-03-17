import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls
import OSLog
import UserNotifications

class ScreenTimePoolMonitor: DeviceActivityMonitor {

    private let appGroupIdentifier = "group.com.screentimepool.shared"

    private var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private let idleStore = ManagedSettingsStore(named: .init("idle"))
    private let downtimeStore = ManagedSettingsStore(named: .init("downtime"))
    private let exhaustedStore = ManagedSettingsStore(named: .init("exhausted"))
    private let testStore = ManagedSettingsStore(named: .init("test"))

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        appGroupDefaults?.set("STARTED \(activity.rawValue) at \(Date())", forKey: "debug_intervalStartedAt")

        switch activity.rawValue {
        case "com.screentimepool.session":
            // Break started — remove shields so apps are accessible
            idleStore.clearAllSettings()
            downtimeStore.clearAllSettings()
            exhaustedStore.clearAllSettings()

        case "com.screentimepool.downtime":
            // Downtime started — block apps
            applyShields(to: downtimeStore)

        default:
            break
        }
    }

    // MARK: - Usage Threshold (fires when managed app usage reaches session duration)

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        // Debug: log when threshold fires (readable from main app)
        appGroupDefaults?.set("THRESHOLD \(event.rawValue) on \(activity.rawValue) at \(Date())", forKey: "debug_thresholdFiredAt")

        if event.rawValue == "com.screentimepool.test.threshold" {
            let firedAt = Date()
            applyShields(to: testStore)
            appGroupDefaults?.set(firedAt, forKey: "testTimerEndedAt")
            appGroupDefaults?.set(false, forKey: "testTimerRunning")
            appGroupDefaults?.set(true, forKey: "testTimerBlocked")

            let content = UNMutableNotificationContent()
            content.title = "Test Block Active"
            content.body = "1 minute of usage reached. Selected apps are now blocked."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "test_timer_fired", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
            return
        }

        guard event.rawValue == "com.screentimepool.session.threshold",
              activity.rawValue == "com.screentimepool.session" else { return }

        guard let defaults = appGroupDefaults else { return }

        let isBonusSession = defaults.bool(forKey: "isBonusSession")
        let currentPhase = defaults.string(forKey: "sessionPhase")

        // Debug: log state when threshold fires
        defaults.set("phase=\(currentPhase ?? "nil") bonus=\(isBonusSession) at \(Date())", forKey: "debug_thresholdState")

        if isBonusSession && currentPhase == "active" {
            return
        }

        guard currentPhase == "active" else { return }

        // Calculate correct pool consumption from the snapshot taken at session start
        let poolAtStart = defaults.integer(forKey: "poolSecondsAtSessionStart")
        let totalSessionSeconds = defaults.integer(forKey: "totalSessionSeconds")
        let updatedPool: Int
        if isBonusSession {
            updatedPool = defaults.integer(forKey: "remainingPoolSeconds")
        } else {
            updatedPool = max(0, poolAtStart - totalSessionSeconds)
        }
        defaults.set(updatedPool, forKey: "remainingPoolSeconds")

        if updatedPool <= 0 {
            applyShields(to: exhaustedStore)
            defaults.set("exhausted", forKey: "sessionPhase")
        } else {
            // Enter downtime
            let downtimeMinutes = defaults.integer(forKey: "downtimeDurationMinutes")
            let downtimeSeconds = downtimeMinutes > 0 ? downtimeMinutes * 60 : 5 * 60
            defaults.set(downtimeSeconds, forKey: "remainingDowntimeSeconds")
            defaults.set(downtimeSeconds, forKey: "totalDowntimeSeconds")
            applyShields(to: downtimeStore)
            scheduleDowntimeMonitoring(durationSeconds: downtimeSeconds)
            defaults.set("downtime", forKey: "sessionPhase")
        }

        // Stop session monitoring so usage doesn't accumulate during downtime
        let center = DeviceActivityCenter()
        center.stopMonitoring([DeviceActivityName("com.screentimepool.session")])

        // Clear session-specific state
        defaults.set(0, forKey: "remainingSessionSeconds")
        defaults.set(false, forKey: "isBonusSession")
        defaults.set(false, forKey: "downtimeRunningDuringSession")
        defaults.set(Date(), forKey: "lastUpdated")
    }

    // MARK: - Interval End

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        guard let defaults = appGroupDefaults else { return }

        switch activity.rawValue {
        case "com.screentimepool.session":
            // Session schedule ended (broad window expired).
            // The threshold event handles session-end logic, so nothing to do here.
            break

        case "com.screentimepool.downtime":
            let currentPhase = defaults.string(forKey: "sessionPhase")
            // Guard: skip if the in-app timer already handled the transition
            guard currentPhase == "downtime" else { break }

            // Downtime ended — remove downtime shields
            downtimeStore.clearAllSettings()
            defaults.set(0, forKey: "remainingDowntimeSeconds")
            let poolSeconds = defaults.integer(forKey: "remainingPoolSeconds")
            if poolSeconds <= 0 {
                applyShields(to: exhaustedStore)
                defaults.set("exhausted", forKey: "sessionPhase")
            } else {
                applyShields(to: idleStore)
                defaults.set("idle", forKey: "sessionPhase")
            }
            defaults.set(Date(), forKey: "lastUpdated")

        case "com.screentimepool.test":
            let firedAt = Date()
            // Log to Console.app (visible on Mac via USB: open Console.app, filter by "screentimepool")
            let log = OSLog(subsystem: "com.screentimepool", category: "TestTimer")
            os_log("TEST TIMER ENDED at %{public}@", log: log, type: .info, "\(firedAt)")

            // Apply shields to block selected apps
            applyShields(to: testStore)

            // Write result to App Group so TestTimerView can show it when app reopens
            defaults.set(firedAt, forKey: "testTimerEndedAt")
            defaults.set(false, forKey: "testTimerRunning")
            defaults.set(true, forKey: "testTimerBlocked")

            // Fire a local push notification on the phone
            let content = UNMutableNotificationContent()
            content.title = "Test Block Active"
            content.body = "Timer fired at \(firedAt.formatted(date: .omitted, time: .standard)). Selected apps are now blocked."
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "test_timer_fired",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)

        default:
            break
        }
    }

    // MARK: - Downtime Scheduling

    private func scheduleDowntimeMonitoring(durationSeconds: Int) {
        // DeviceActivity requires >= 15 min intervals. For shorter downtimes,
        // shields are already applied — the in-app timer or restoreState() handles removal.
        guard durationSeconds >= 900 else { return }

        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(durationSeconds))

        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now),
            intervalEnd: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: end),
            repeats: false
        )

        let center = DeviceActivityCenter()
        let downtimeActivity = DeviceActivityName("com.screentimepool.downtime")
        do {
            try center.startMonitoring(downtimeActivity, during: schedule)
        } catch {
            // Best-effort from extension
        }
    }

    // MARK: - Shield Application

    private func applyShields(to store: ManagedSettingsStore) {
        guard let data = appGroupDefaults?.data(forKey: "familyActivitySelectionData"),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return
        }

        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        if !selection.webDomainTokens.isEmpty {
            store.shield.webDomains = selection.webDomainTokens
        }
    }
}
