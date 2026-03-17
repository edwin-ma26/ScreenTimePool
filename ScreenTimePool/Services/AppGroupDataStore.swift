import Foundation

final class AppGroupDataStore {
    static let shared = AppGroupDataStore()

    private let defaults: UserDefaults

    static let appGroupIdentifier = "group.com.screentimepool.shared"

    private enum Keys {
        static let sessionPhase = "sessionPhase"
        static let remainingSessionSeconds = "remainingSessionSeconds"
        static let remainingDowntimeSeconds = "remainingDowntimeSeconds"
        static let remainingPoolSeconds = "remainingPoolSeconds"
        static let sessionDurationMinutes = "sessionDurationMinutes"
        static let downtimeDurationMinutes = "downtimeDurationMinutes"
        static let dailyPoolMinutes = "dailyPoolMinutes"
        static let lastUpdated = "lastUpdated"
        static let familyActivitySelectionData = "familyActivitySelectionData"
        static let lastPoolResetDate = "lastPoolResetDate"
        static let totalSessionSeconds = "totalSessionSeconds"
        static let totalDowntimeSeconds = "totalDowntimeSeconds"
        static let resetDowntimeAfterSession = "resetDowntimeAfterSession"
        static let isBonusSession = "isBonusSession"
        static let downtimeRunningDuringSession = "downtimeRunningDuringSession"
        static let settingsPasscode = "settingsPasscode"
        static let poolSecondsAtSessionStart = "poolSecondsAtSessionStart"
    }

    private init() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) else {
            fatalError("Failed to initialize App Group UserDefaults with identifier: \(Self.appGroupIdentifier)")
        }
        self.defaults = defaults
    }

    // MARK: - Session State

    var sessionPhase: SessionPhase {
        get {
            guard let raw = defaults.string(forKey: Keys.sessionPhase),
                  let phase = SessionPhase(rawValue: raw) else {
                return .idle
            }
            return phase
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.sessionPhase) }
    }

    var remainingSessionSeconds: Int {
        get { defaults.integer(forKey: Keys.remainingSessionSeconds) }
        set { defaults.set(newValue, forKey: Keys.remainingSessionSeconds) }
    }

    var remainingDowntimeSeconds: Int {
        get { defaults.integer(forKey: Keys.remainingDowntimeSeconds) }
        set { defaults.set(newValue, forKey: Keys.remainingDowntimeSeconds) }
    }

    var remainingPoolSeconds: Int {
        get { defaults.integer(forKey: Keys.remainingPoolSeconds) }
        set { defaults.set(newValue, forKey: Keys.remainingPoolSeconds) }
    }

    var sessionDurationMinutes: Int {
        get {
            let val = defaults.integer(forKey: Keys.sessionDurationMinutes)
            return val > 0 ? val : 25
        }
        set { defaults.set(newValue, forKey: Keys.sessionDurationMinutes) }
    }

    var downtimeDurationMinutes: Int {
        get {
            let val = defaults.integer(forKey: Keys.downtimeDurationMinutes)
            return val > 0 ? val : 5
        }
        set { defaults.set(newValue, forKey: Keys.downtimeDurationMinutes) }
    }

    var dailyPoolMinutes: Int {
        get {
            let val = defaults.integer(forKey: Keys.dailyPoolMinutes)
            return val > 0 ? val : 120
        }
        set { defaults.set(newValue, forKey: Keys.dailyPoolMinutes) }
    }

    var lastUpdated: Date {
        get { defaults.object(forKey: Keys.lastUpdated) as? Date ?? .distantPast }
        set { defaults.set(newValue, forKey: Keys.lastUpdated) }
    }

    var totalSessionSeconds: Int {
        get { defaults.integer(forKey: Keys.totalSessionSeconds) }
        set { defaults.set(newValue, forKey: Keys.totalSessionSeconds) }
    }

    var totalDowntimeSeconds: Int {
        get { defaults.integer(forKey: Keys.totalDowntimeSeconds) }
        set { defaults.set(newValue, forKey: Keys.totalDowntimeSeconds) }
    }

    var resetDowntimeAfterSession: Bool {
        get {
            if defaults.object(forKey: Keys.resetDowntimeAfterSession) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.resetDowntimeAfterSession)
        }
        set { defaults.set(newValue, forKey: Keys.resetDowntimeAfterSession) }
    }

    var isBonusSession: Bool {
        get { defaults.bool(forKey: Keys.isBonusSession) }
        set { defaults.set(newValue, forKey: Keys.isBonusSession) }
    }

    var downtimeRunningDuringSession: Bool {
        get { defaults.bool(forKey: Keys.downtimeRunningDuringSession) }
        set { defaults.set(newValue, forKey: Keys.downtimeRunningDuringSession) }
    }

    var settingsPasscode: String? {
        get { defaults.string(forKey: Keys.settingsPasscode) }
        set { defaults.set(newValue, forKey: Keys.settingsPasscode) }
    }

    var poolSecondsAtSessionStart: Int {
        get { defaults.integer(forKey: Keys.poolSecondsAtSessionStart) }
        set { defaults.set(newValue, forKey: Keys.poolSecondsAtSessionStart) }
    }

    // MARK: - App Selection

    var familyActivitySelectionData: Data? {
        get { defaults.data(forKey: Keys.familyActivitySelectionData) }
        set { defaults.set(newValue, forKey: Keys.familyActivitySelectionData) }
    }

    // MARK: - Pool Reset

    var lastPoolResetDate: Date {
        get { defaults.object(forKey: Keys.lastPoolResetDate) as? Date ?? .distantPast }
        set { defaults.set(newValue, forKey: Keys.lastPoolResetDate) }
    }

    // MARK: - Sync Helper

    func syncSessionState(phase: SessionPhase, sessionSeconds: Int, downtimeSeconds: Int, poolSeconds: Int, totalSession: Int, totalDowntime: Int, isBonusSession: Bool, downtimeRunningDuringSession: Bool) {
        sessionPhase = phase
        remainingSessionSeconds = sessionSeconds
        remainingDowntimeSeconds = downtimeSeconds
        remainingPoolSeconds = poolSeconds
        totalSessionSeconds = totalSession
        totalDowntimeSeconds = totalDowntime
        self.isBonusSession = isBonusSession
        self.downtimeRunningDuringSession = downtimeRunningDuringSession
        lastUpdated = .now
    }
}
