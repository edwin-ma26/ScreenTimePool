import Foundation
import FirebaseFirestore

@MainActor
final class TimeRequestsViewModel: ObservableObject {
    @Published var incomingRequests: [TimeRequest] = []
    @Published var outgoingRequests: [TimeRequest] = []
    @Published var isLoading = false
    @Published var showRequestSheet = false
    @Published var error: String?

    // Modify request
    @Published var modifyMinutes: Int = 15
    @Published var showModifySheet = false
    @Published var selectedRequest: TimeRequest?

    private var incomingListener: ListenerRegistration?
    private var outgoingListener: ListenerRegistration?
    private let authService: AuthService
    private let sessionManager: SessionManager

    init(authService: AuthService, sessionManager: SessionManager) {
        self.authService = authService
        self.sessionManager = sessionManager
    }

    func startListening() {
        guard let uid = authService.uid else { return }

        incomingListener = TimeRequestService.shared.listenToIncomingRequests(userId: uid) { [weak self] requests in
            Task { @MainActor in
                self?.incomingRequests = requests
            }
        }

        outgoingListener = TimeRequestService.shared.listenToOutgoingRequests(userId: uid) { [weak self] requests in
            Task { @MainActor in
                self?.outgoingRequests = requests
            }
        }
    }

    func approveRequest(_ request: TimeRequest) async {
        do {
            try await TimeRequestService.shared.approveRequest(request)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func denyRequest(_ request: TimeRequest) async {
        do {
            try await TimeRequestService.shared.denyRequest(request)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func modifyRequest(_ request: TimeRequest, grantedMinutes: Int) async {
        do {
            try await TimeRequestService.shared.modifyRequest(request, grantedMinutes: grantedMinutes)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func stopListening() {
        incomingListener?.remove()
        outgoingListener?.remove()
    }
}
