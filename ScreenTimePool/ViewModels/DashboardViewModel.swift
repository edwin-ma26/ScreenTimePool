import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var phase: SessionPhase = .idle
    @Published var remainingSessionSeconds: Int = 0
    @Published var remainingDowntimeSeconds: Int = 0
    @Published var remainingPoolSeconds: Int = 0
    @Published var dailyPoolMinutes: Int = 120
    @Published var pendingIncomingRequests: Int = 0
    @Published var showRequestTimeSheet = false

    private var cancellables = Set<AnyCancellable>()
    private var approvedListener: ListenerRegistration?
    private var incomingCountListener: ListenerRegistration?
    private let sessionManager: SessionManager
    private let authService: AuthService

    init(sessionManager: SessionManager, authService: AuthService) {
        self.sessionManager = sessionManager
        self.authService = authService

        sessionManager.$phase.assign(to: &$phase)
        sessionManager.$remainingSessionSeconds.assign(to: &$remainingSessionSeconds)
        sessionManager.$remainingDowntimeSeconds.assign(to: &$remainingDowntimeSeconds)
        sessionManager.$remainingPoolSeconds.assign(to: &$remainingPoolSeconds)

        dailyPoolMinutes = AppGroupDataStore.shared.dailyPoolMinutes

        setupListeners()
    }

    var poolProgress: Double {
        let total = Double(dailyPoolMinutes * 60)
        guard total > 0 else { return 0 }
        return Double(remainingPoolSeconds) / total
    }

    var sessionProgress: Double {
        let total = Double(sessionManager.sessionDurationMinutes * 60)
        guard total > 0 else { return 0 }
        return Double(remainingSessionSeconds) / total
    }

    var downtimeProgress: Double {
        let total = Double(sessionManager.downtimeDurationMinutes * 60)
        guard total > 0 else { return 0 }
        return Double(remainingDowntimeSeconds) / total
    }

    func startSession() {
        sessionManager.startSession()
    }

    func stopSession() {
        sessionManager.stopSession()
    }

    func requestMoreTime() {
        showRequestTimeSheet = true
    }

    private func setupListeners() {
        guard let uid = authService.uid else { return }

        approvedListener = TimeRequestService.shared.listenToApprovedRequests(userId: uid) { [weak self] requests in
            Task { @MainActor in
                for request in requests {
                    let minutes = request.grantedMinutes ?? request.requestedMinutes
                    self?.sessionManager.addBonusTime(minutes: minutes)
                    try? await TimeRequestService.shared.markAsProcessed(request)
                }
            }
        }

        incomingCountListener = TimeRequestService.shared.listenToIncomingRequests(userId: uid) { [weak self] requests in
            Task { @MainActor in
                self?.pendingIncomingRequests = requests.count
            }
        }
    }

    func onAppear() {
        sessionManager.checkMidnightReset()
    }

    deinit {
        approvedListener?.remove()
        incomingCountListener?.remove()
    }
}
