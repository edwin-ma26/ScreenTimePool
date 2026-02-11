import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @State private var showRequestTimeSheet = false
    @State private var pendingIncomingRequests = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    TimerRingView(
                        progress: mainProgress,
                        timeRemaining: mainTimeRemaining,
                        label: mainLabel,
                        isOvertime: sessionManager.isOvertime
                    )
                    .frame(height: 260)
                    .padding(.top, 16)

                    SessionStatusBadge(phase: sessionManager.phase)

                    poolSummary

                    QuickActionsBar(
                        phase: sessionManager.phase,
                        onStart: { sessionManager.startSession() },
                        onStop: { sessionManager.stopSession() },
                        onRequestTime: { showRequestTimeSheet = true },
                        pendingRequests: pendingIncomingRequests,
                        blockedSelection: screenTimeManager.loadSelection()
                    )
                }
                .padding(.horizontal)
            }
            .navigationTitle("Dashboard")
            .onAppear {
                sessionManager.checkMidnightReset()
            }
            .sheet(isPresented: $showRequestTimeSheet) {
                RequestTimeSheet(authService: authService, sessionManager: sessionManager)
            }
        }
    }

    private var mainProgress: Double {
        switch sessionManager.phase {
        case .active:
            let total = Double(sessionManager.totalSessionSeconds)
            return total > 0 ? Double(sessionManager.remainingSessionSeconds) / total : 0
        case .downtime:
            let total = Double(sessionManager.totalDowntimeSeconds)
            return total > 0 ? Double(sessionManager.remainingDowntimeSeconds) / total : 0
        default:
            let total = Double(AppGroupDataStore.shared.dailyPoolMinutes * 60)
            return total > 0 ? Double(sessionManager.remainingPoolSeconds) / total : 0
        }
    }

    private var mainTimeRemaining: String {
        switch sessionManager.phase {
        case .active: return sessionManager.remainingSessionSeconds.formattedAsMMSS
        case .downtime: return sessionManager.remainingDowntimeSeconds.formattedAsMMSS
        default: return sessionManager.remainingPoolSeconds.formattedAsHHMMSS
        }
    }

    private var mainLabel: String {
        switch sessionManager.phase {
        case .idle: return "Pool Remaining"
        case .active: return "Session"
        case .downtime: return "Downtime"
        case .exhausted: return "Pool Exhausted"
        }
    }

    private var poolSummary: some View {
        HStack(spacing: 24) {
            statItem(title: "Pool", value: sessionManager.remainingPoolSeconds.formattedAsHumanReadable)
            Divider().frame(height: 40)
            statItem(title: "Session", value: "\(AppGroupDataStore.shared.sessionDurationMinutes)m")
            Divider().frame(height: 40)
            if sessionManager.phase == .active && sessionManager.downtimeRunningDuringSession {
                statItem(title: "Break", value: sessionManager.remainingDowntimeSeconds.formattedAsMMSS)
            } else {
                statItem(title: "Break", value: "\(AppGroupDataStore.shared.downtimeDurationMinutes)m")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
        }
    }
}
