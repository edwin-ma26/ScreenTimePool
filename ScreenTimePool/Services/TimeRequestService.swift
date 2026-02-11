import Foundation
import FirebaseFirestore

struct TimeRequest: Codable, Identifiable {
    @DocumentID var id: String?
    var fromUserId: String
    var fromDisplayName: String
    var toUserId: String
    var toDisplayName: String
    var requestedMinutes: Int
    var grantedMinutes: Int?
    var status: String // pending, approved, denied, modified, expired
    var deductsFromGranter: Bool
    var expiresAt: Date
    var createdAt: Date?

    var documentId: String { id ?? "" }
}

final class TimeRequestService {
    static let shared = TimeRequestService()

    private let db = Firestore.firestore()
    private let collection = "time_requests"

    private init() {}

    // MARK: - Create

    func createTimeRequest(
        from: (uid: String, name: String),
        to: (uid: String, name: String),
        minutes: Int,
        deductsFromGranter: Bool
    ) async throws {
        let request = TimeRequest(
            fromUserId: from.uid,
            fromDisplayName: from.name,
            toUserId: to.uid,
            toDisplayName: to.name,
            requestedMinutes: minutes,
            status: "pending",
            deductsFromGranter: deductsFromGranter,
            expiresAt: Date().addingTimeInterval(3600),
            createdAt: Date()
        )
        _ = try db.collection(collection).addDocument(from: request)
    }

    // MARK: - Respond

    func approveRequest(_ request: TimeRequest) async throws {
        guard let docId = request.id else { return }
        try await db.collection(collection).document(docId).updateData([
            "status": "approved",
            "grantedMinutes": request.requestedMinutes
        ])
    }

    func denyRequest(_ request: TimeRequest) async throws {
        guard let docId = request.id else { return }
        try await db.collection(collection).document(docId).updateData([
            "status": "denied"
        ])
    }

    func modifyRequest(_ request: TimeRequest, grantedMinutes: Int) async throws {
        guard let docId = request.id else { return }
        try await db.collection(collection).document(docId).updateData([
            "status": "modified",
            "grantedMinutes": grantedMinutes
        ])
    }

    // MARK: - Listeners

    func listenToIncomingRequests(userId: String, onChange: @escaping ([TimeRequest]) -> Void) -> ListenerRegistration {
        db.collection(collection)
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else {
                    onChange([])
                    return
                }
                let requests = docs.compactMap { try? $0.data(as: TimeRequest.self) }
                onChange(requests)
            }
    }

    func listenToOutgoingRequests(userId: String, onChange: @escaping ([TimeRequest]) -> Void) -> ListenerRegistration {
        db.collection(collection)
            .whereField("fromUserId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else {
                    onChange([])
                    return
                }
                let requests = docs.compactMap { try? $0.data(as: TimeRequest.self) }
                    .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
                onChange(requests)
            }
    }

    func listenToApprovedRequests(userId: String, onChange: @escaping ([TimeRequest]) -> Void) -> ListenerRegistration {
        db.collection(collection)
            .whereField("fromUserId", isEqualTo: userId)
            .whereField("status", in: ["approved", "modified"])
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else {
                    onChange([])
                    return
                }
                let requests = docs.compactMap { try? $0.data(as: TimeRequest.self) }
                onChange(requests)
            }
    }

    func markAsProcessed(_ request: TimeRequest) async throws {
        guard let docId = request.id else { return }
        try await db.collection(collection).document(docId).updateData([
            "status": "processed"
        ])
    }
}
