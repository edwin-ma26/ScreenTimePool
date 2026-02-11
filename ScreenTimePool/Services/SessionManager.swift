import Foundation
import Combine
import SwiftData
import FirebaseFirestore

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
                    print("[SessionManager] processing approved request: \(minutes)m")
                    self?.addBonusTime(minutes: minutes)
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
            print("[SessionManager] startSession: no pool left, going exhausted")
            transitionTo(.exhausted)
            return
        }

        print("[SessionManager] startSession: starting \(sessionSeconds)s session")
        remainingSessionSeconds = sessionSeconds
        totalSessionSeconds = sessionSeconds
        screenTimeManager?.removeAllShields()
        screenTimeManager?.scheduleSessionMonitoring(durationSeconds: sessionSeconds)
        transitionTo(.active)
        startTimer()
    }

    func stopSession() {
        stopTimer()
        remainingSessionSeconds = 0
        screenTimeManager?.stopAllMonitoring()
        enterDowntimeAfterSession()
    }

    func addBonusTime(minutes: Int) {
        let bonusSeconds = minutes * 60
        print("[SessionManager] addBonusTime: \(minutes)m, phase=\(phase), screenTimeManager=\(screenTimeManager != nil), pool=\(remainingPoolSeconds)")

        switch phase {
        case .downtime:
            // Start bonus session immediately — do NOT add to pool
            stopTimer()
            screenTimeManager?.stopAllMonitoring()
            // Persist bonus flag BEFORE removing shields so extension won't race
            isBonusSession = true
            downtimeRunningDuringSession = true
            persistState()
            screenTimeManager?.removeAllShields()
            remainingSessionSeconds = bonusSeconds
            totalSessionSeconds = bonusSeconds
            screenTimeManager?.scheduleSessionMonitoring(durationSeconds: bonusSeconds)
            print("[SessionManager] addBonusTime: bonus from downtime, starting \(bonusSeconds)s session")
            transitionTo(.active)
            startTimer()

        case .exhausted:
            // Start bonus session immediately — do NOT add to pool
            // Persist bonus flag BEFORE removing shields so extension won't race
            isBonusSession = true
            downtimeRunningDuringSession = false
            persistState()
            screenTimeManager?.removeAllShields()
            remainingSessionSeconds = bonusSeconds
            totalSessionSeconds = bonusSeconds
            screenTimeManager?.scheduleSessionMonitoring(durationSeconds: bonusSeconds)
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
        screenTimeManager?.stopAllMonitoring()
        let wasBonusSession = isBonusSession
        let wasDowntimeRunning = downtimeRunningDuringSession
        isBonusSession = false
        downtimeRunningDuringSession = false

        if wasBonusSession && wasDowntimeRunning {
            if resetDowntimeAfterSession {
                // Start fresh downtime
                let downtimeSeconds = downtimeDurationMinutes * 60
                remainingDowntimeSeconds = downtimeSeconds
                totalDowntimeSeconds = downtimeSeconds
                screenTimeManager?.applyDowntimeShield()
                screenTimeManager?.scheduleDowntimeMonitoring(durationSeconds: downtimeSeconds)
                transitionTo(.downtime)
                startTimer()
            } else if remainingDowntimeSeconds > 0 {
                // Resume remaining downtime
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
            // Normal session end or bonus from exhausted
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
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
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

    func resumeFromBackground() {
        restoreState()
        // Re-establish listener if it was lost
        if approvedListener == nil {
            startApprovedRequestListener()
        }
    }

    private func restoreState() {
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
