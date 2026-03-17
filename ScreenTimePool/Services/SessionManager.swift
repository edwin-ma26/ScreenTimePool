import Foundation
import Combine
import SwiftData
import FirebaseFirestore
import FamilyControls
import ManagedSettings
import UIKit

@MainActor
final class SessionManager: ObservableObject {
    @Published var phase: SessionPhase = .idle
    @Published var remainingSessionSeconds: Int = 0
    @Published var remainingDowntimeSeconds: Int = 0
    @Published var remainingPoolSeconds: Int = 0
    @Published var totalSessionSeconds: Int = 0
    @Published var totalDowntimeSeconds: Int = 0
    @Published var isBonusSession: Bool = false
    @Published var downtimeRunningDuringSession: Bool = false

    var isOvertime: Bool { isBonusSession && remainingPoolSeconds <= 0 }

    private var timer: Timer?
    private let appGroupStore = AppGroupDataStore.shared
    private var screenTimeManager: ScreenTimeManager?
    private var modelContext: ModelContext?
    private var approvedListener: ListenerRegistration?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTimer: Timer?

    var sessionDurationMinutes: Int {
        appGroupStore.sessionDurationMinutes
    }

    var downtimeDurationMinutes: Int {
        appGroupStore.downtimeDurationMinutes
    }

    var dailyPoolMinutes: Int {
        appGroupStore.dailyPoolMinutes
    }

    var resetDowntimeAfterSession: Bool {
        appGroupStore.resetDowntimeAfterSession
    }

    func configure(screenTimeManager: ScreenTimeManager, modelContext: ModelContext) {
        self.screenTimeManager = screenTimeManager
        self.modelContext = modelContext
        restoreState()
        checkMidnightReset()
        startApprovedRequestListener()
    }

    func startApprovedRequestListener() {
        approvedListener?.remove()
        guard let uid = AuthServiceProvider.shared?.uid else {
            print("[SessionManager] startApprovedRequestListener: no uid, skipping")
            return
        }
        print("[SessionManager] startApprovedRequestListener: listening for uid=\(uid)")
        approvedListener = TimeRequestService.shared.listenToApprovedRequests(userId: uid) { [weak self] requests in
            Task { @MainActor in
                for request in requests {
                    let minutes = request.grantedMinutes ?? request.requestedMinutes
                    let appsData = request.grantedAppsData ?? request.requestedAppsData
                    print("[SessionManager] processing approved request: \(minutes)m, hasAppsData=\(appsData != nil)")
                    self?.addBonusTime(minutes: minutes, grantedAppsData: appsData)
                    try? await TimeRequestService.shared.markAsProcessed(request)
                }
            }
        }
    }

    // MARK: - State Machine

    func startSession() {
        print("[SessionManager] startSession: phase=\(phase), screenTimeManager=\(screenTimeManager != nil), pool=\(remainingPoolSeconds)")
        guard phase == .idle else {
            print("[SessionManager] startSession: not idle, aborting")
            return
        }
        let sessionSeconds = sessionDurationMinutes * 60

        guard remainingPoolSeconds > 0 else {
            print("[SessionManager] startSession: no pool left, going exhau t   sted")
            transitionTo(.exhausted)
            return
        }

        print("[SessionManager] startSession: starting \(sessionSeconds)s session")
        remainingSessionSeconds = sessionSeconds
        totalSessionSeconds = sessionSeconds
        appGroupStore.poolSecondsAtSessionStart = remainingPoolSeconds
        screenTimeManager?.stopAllMonitoring()
        screenTimeManager?.removeAllShields()
        screenTimeManager?.scheduleUsageEvent(durationMinutes: sessionDurationMinutes)
        transitionTo(.active)
        startTimer()
    }

    func stopSession() {
        stopTimer()
        remainingSessionSeconds = 0
        screenTimeManager?.stopAllMonitoring()
        enterDowntimeAfterSession()
    }

    func addBonusTime(minutes: Int, grantedAppsData: Data? = nil) {
        let bonusSeconds = minutes * 60
        print("[SessionManager] addBonusTime: \(minutes)m, phase=\(phase), screenTimeManager=\(screenTimeManager != nil), pool=\(remainingPoolSeconds)")

        // Try to decode the granted apps selection for selective unblocking
        let grantedApps: FamilyActivitySelection? = {
            guard let data = grantedAppsData else { return nil }
            return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        }()

        switch phase {
        case .downtime:
            // Start bonus session immediately — do NOT add to pool
            stopTimer()
            screenTimeManager?.stopAllMonitoring()
            // Persist bonus flag BEFORE removing shields so extension won't race
            isBonusSession = true
            downtimeRunningDuringSession = true
            appGroupStore.poolSecondsAtSessionStart = 0
            persistState()
            if let grantedApps {
                screenTimeManager?.removeAllShields()
                screenTimeManager?.applySelectiveBonusShield(grantedApps: grantedApps)
            } else {
                screenTimeManager?.removeAllShields()
            }
            remainingSessionSeconds = bonusSeconds
            totalSessionSeconds = bonusSeconds
            screenTimeManager?.scheduleUsageEvent(durationMinutes: minutes)
            print("[SessionManager] addBonusTime: bonus from downtime, starting \(bonusSeconds)s session")
            transitionTo(.active)
            startTimer()

        case .exhausted:
            // Start bonus session immediately — do NOT add to pool
            // Persist bonus flag BEFORE removing shields so extension won't race
            isBonusSession = true
            downtimeRunningDuringSession = false
            appGroupStore.poolSecondsAtSessionStart = 0
            persistState()
            if let grantedApps {
                screenTimeManager?.removeAllShields()
                screenTimeManager?.applySelectiveBonusShield(grantedApps: grantedApps)
            } else {
                screenTimeManager?.removeAllShields()
            }
            remainingSessionSeconds = bonusSeconds
            totalSessionSeconds = bonusSeconds
            screenTimeManager?.scheduleUsageEvent(durationMinutes: minutes)
            print("[SessionManager] addBonusTime: bonus from exhausted, starting \(bonusSeconds)s session")
            transitionTo(.active)
            startTimer()

        case .idle, .active:
            // Normal behavior: add to pool
            remainingPoolSeconds += bonusSeconds
            appGroupStore.remainingPoolSeconds = remainingPoolSeconds
            print("[SessionManager] addBonusTime: added \(bonusSeconds)s to pool, new pool=\(remainingPoolSeconds)")
        }

        syncToFirestore()
        persistState()
    }

    private func enterDowntimeAfterSession() {
        stopTimer()
        screenTimeManager?.cancelExpiryNotifications()
        screenTimeManager?.removeBonusShield()
        let wasBonusSession = isBonusSession
        let wasDowntimeRunning = downtimeRunningDuringSession
        isBonusSession = false
        downtimeRunningDuringSession = false

        if wasBonusSession && wasDowntimeRunning {
            if resetDowntimeAfterSession {
                let downtimeSeconds = downtimeDurationMinutes * 60
                remainingDowntimeSeconds = downtimeSeconds
                totalDowntimeSeconds = downtimeSeconds
                screenTimeManager?.applyDowntimeShield()
                screenTimeManager?.scheduleDowntimeMonitoring(durationSeconds: downtimeSeconds)
                transitionTo(.downtime)
                startTimer()
            } else if remainingDowntimeSeconds > 0 {
                totalDowntimeSeconds = remainingDowntimeSeconds
                screenTimeManager?.applyDowntimeShield()
                screenTimeManager?.scheduleDowntimeMonitoring(durationSeconds: remainingDowntimeSeconds)
                transitionTo(.downtime)
                startTimer()
            } else if remainingPoolSeconds <= 0 {
                screenTimeManager?.applyExhaustedShield()
                transitionTo(.exhausted)
            } else {
                screenTimeManager?.applyIdleShield()
                transitionTo(.idle)
            }
        } else {
            // Normal break end or bonus from exhausted
            if remainingPoolSeconds <= 0 {
                screenTimeManager?.applyExhaustedShield()
                transitionTo(.exhausted)
            } else {
                let downtimeSeconds = downtimeDurationMinutes * 60
                remainingDowntimeSeconds = downtimeSeconds
                totalDowntimeSeconds = downtimeSeconds
                screenTimeManager?.applyDowntimeShield()
                screenTimeManager?.scheduleDowntimeMonitoring(durationSeconds: downtimeSeconds)
                transitionTo(.downtime)
                startTimer()
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        switch phase {
        case .active:
            remainingSessionSeconds -= 1

            if remainingPoolSeconds > 0 {
                remainingPoolSeconds -= 1
                appGroupStore.remainingPoolSeconds = remainingPoolSeconds
            }

            // Pool takes priority — block immediately when exhausted
            if remainingPoolSeconds <= 0 && !isBonusSession {
                stopTimer()
                screenTimeManager?.stopAllMonitoring()
                screenTimeManager?.applyExhaustedShield()
                transitionTo(.exhausted)
                persistState()
                return
            }

            if downtimeRunningDuringSession && !resetDowntimeAfterSession {
                remainingDowntimeSeconds = max(0, remainingDowntimeSeconds - 1)
            }

            if remainingSessionSeconds <= 0 {
                enterDowntimeAfterSession()
                return
            }

        case .downtime:
            remainingDowntimeSeconds -= 1
            if remainingDowntimeSeconds <= 0 {
                stopTimer()
                screenTimeManager?.stopAllMonitoring()
                screenTimeManager?.removeDowntimeShield()
                screenTimeManager?.applyIdleShield()
                transitionTo(.idle)
            }

        default:
            stopTimer()
        }

        persistState()
    }

    // MARK: - State Transitions

    private func transitionTo(_ newPhase: SessionPhase) {
        phase = newPhase
        persistState()
    }

    // MARK: - Persistence (App Group)

    private func persistState() {
        appGroupStore.syncSessionState(
            phase: phase,
            sessionSeconds: remainingSessionSeconds,
            downtimeSeconds: remainingDowntimeSeconds,
            poolSeconds: remainingPoolSeconds,
            totalSession: totalSessionSeconds,
            totalDowntime: totalDowntimeSeconds,
            isBonusSession: isBonusSession,
            downtimeRunningDuringSession: downtimeRunningDuringSession
        )
        persistToSwiftData()
    }

    func pauseForBackground() {
        stopTimer()
        persistState()
        startBackgroundEnforcement()
    }

    func resumeFromBackground() {
        stopBackgroundEnforcement()
        restoreState()
        // Re-establish listener if it was lost
        if approvedListener == nil {
            startApprovedRequestListener()
        }
    }

    // MARK: - Background Enforcement

    private func startBackgroundEnforcement() {
        guard phase == .active || phase == .downtime else { return }

        let remaining: Int
        switch phase {
        case .active: remaining = remainingSessionSeconds
        case .downtime: remaining = remainingDowntimeSeconds
        default: return
        }

        guard remaining > 0 else { return }

        print("[SessionManager] startBackgroundEnforcement: \(remaining)s remaining in \(phase)")

        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            // System is reclaiming — must end synchronously
            print("[SessionManager] backgroundTask expired by system")
            guard let self else { return }
            self.backgroundTimer?.invalidate()
            self.backgroundTimer = nil
            let taskID = self.backgroundTaskID
            self.backgroundTaskID = .invalid
            UIApplication.shared.endBackgroundTask(taskID)
        }

        // Schedule a timer to fire when the session/downtime should end
        let t = Timer(timeInterval: TimeInterval(remaining), repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                print("[SessionManager] backgroundTimer fired, phase=\(self.phase)")
                switch self.phase {
                case .active:
                    self.remainingSessionSeconds = 0
                    self.enterDowntimeAfterSession()
                case .downtime:
                    self.remainingDowntimeSeconds = 0
                    self.screenTimeManager?.stopAllMonitoring()
                    self.screenTimeManager?.removeDowntimeShield()
                    self.screenTimeManager?.applyIdleShield()
                    self.transitionTo(.idle)
                default:
                    break
                }
                self.stopBackgroundEnforcement()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        backgroundTimer = t
    }

    private func stopBackgroundEnforcement() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        if backgroundTaskID != .invalid {
            let taskID = backgroundTaskID
            backgroundTaskID = .invalid
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }

    private func restoreState() {
        // Debug: check extension callbacks
        print("[Debug] ===== restoreState called =====")
        let dbg = UserDefaults(suiteName: AppGroupDataStore.appGroupIdentifier)
        print("[Debug] intervalStartedAt: \(dbg?.string(forKey: "debug_intervalStartedAt") ?? "nil")")
        print("[Debug] thresholdFiredAt: \(dbg?.string(forKey: "debug_thresholdFiredAt") ?? "nil")")
        print("[Debug] thresholdState: \(dbg?.string(forKey: "debug_thresholdState") ?? "nil")")

        phase = appGroupStore.sessionPhase
        remainingSessionSeconds = appGroupStore.remainingSessionSeconds
        remainingDowntimeSeconds = appGroupStore.remainingDowntimeSeconds
        remainingPoolSeconds = appGroupStore.remainingPoolSeconds
        isBonusSession = appGroupStore.isBonusSession
        downtimeRunningDuringSession = appGroupStore.downtimeRunningDuringSession

        // Resume timer if needed
        let elapsed = Int(Date().timeIntervalSince(appGroupStore.lastUpdated))

        switch phase {
        case .active:
            remainingSessionSeconds = max(0, remainingSessionSeconds - elapsed)
            totalSessionSeconds = appGroupStore.totalSessionSeconds

            // Tick pool down (but not below 0)
            let poolElapsed = min(elapsed, remainingPoolSeconds)
            remainingPoolSeconds = max(0, remainingPoolSeconds - poolElapsed)

            // Tick downtime if running alongside bonus session
            if downtimeRunningDuringSession && !resetDowntimeAfterSession {
                remainingDowntimeSeconds = max(0, remainingDowntimeSeconds - elapsed)
            }

            if remainingPoolSeconds <= 0 && !isBonusSession {
                transitionTo(.exhausted)
                screenTimeManager?.applyExhaustedShield()
            } else if remainingSessionSeconds <= 0 {
                enterDowntimeAfterSession()
            } else {
                startTimer()
            }

        case .downtime:
            remainingDowntimeSeconds = max(0, remainingDowntimeSeconds - elapsed)
            totalDowntimeSeconds = appGroupStore.totalDowntimeSeconds
            if remainingDowntimeSeconds <= 0 {
                screenTimeManager?.removeDowntimeShield()
                screenTimeManager?.applyIdleShield()
                transitionTo(.idle)
            } else {
                startTimer()
            }

        case .exhausted:
            screenTimeManager?.applyExhaustedShield()

        case .idle:
            screenTimeManager?.applyIdleShield()
        }
    }

    // MARK: - Debug Reset

    func resetAll() {
        stopTimer()
        stopBackgroundEnforcement()
        screenTimeManager?.stopAllMonitoring()
        screenTimeManager?.removeAllShields()
        ManagedSettingsStore(named: .init("test")).clearAllSettings()
        remainingSessionSeconds = 0
        remainingDowntimeSeconds = 0
        isBonusSession = false
        downtimeRunningDuringSession = false
        let poolSeconds = dailyPoolMinutes * 60
        remainingPoolSeconds = poolSeconds
        appGroupStore.remainingPoolSeconds = poolSeconds
        transitionTo(.idle)
        syncToFirestore()
    }

    // MARK: - Live App Selection

    /// Reapply shields for the current phase using the latest app selection.
    func reapplyCurrentShields() {
        switch phase {
        case .idle:
            screenTimeManager?.removeAllShields()
            screenTimeManager?.applyIdleShield()
        case .downtime:
            screenTimeManager?.removeAllShields()
            screenTimeManager?.applyDowntimeShield()
        case .exhausted:
            screenTimeManager?.removeAllShields()
            screenTimeManager?.applyExhaustedShield()
        case .active:
            break // No shields during break (apps are accessible)
        }
    }

    // MARK: - Midnight Reset

    func checkMidnightReset() {
        let lastReset = appGroupStore.lastPoolResetDate
        if !lastReset.isToday {
            let poolSeconds = dailyPoolMinutes * 60
            remainingPoolSeconds = poolSeconds
            appGroupStore.remainingPoolSeconds = poolSeconds
            appGroupStore.lastPoolResetDate = .now

            if phase == .exhausted {
                screenTimeManager?.removeExhaustedShield()
                screenTimeManager?.applyIdleShield()
                transitionTo(.idle)
            }

            syncToFirestore()
            persistState()
        }
    }

    // MARK: - SwiftData Persistence

    private func persistToSwiftData() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<LocalSessionState>()
        if let existing = try? context.fetch(descriptor).first {
            existing.phase = phase
            existing.remainingSessionSeconds = remainingSessionSeconds
            existing.remainingDowntimeSeconds = remainingDowntimeSeconds
            existing.remainingPoolSeconds = remainingPoolSeconds
            existing.lastUpdated = .now
        } else {
            let state = LocalSessionState(
                phase: phase,
                remainingSessionSeconds: remainingSessionSeconds,
                remainingDowntimeSeconds: remainingDowntimeSeconds,
                remainingPoolSeconds: remainingPoolSeconds
            )
            context.insert(state)
        }
        try? context.save()
    }

    // MARK: - Firestore Sync

    private func syncToFirestore() {
        Task {
            guard let uid = try? await AuthServiceProvider.shared?.uid else { return }
            try? await FirestoreService.shared.updateRemainingPool(uid: uid, seconds: remainingPoolSeconds)
        }
    }
}

// Helper to avoid circular dependency - set from app entry point
enum AuthServiceProvider {
    @MainActor static var shared: AuthService?
}
