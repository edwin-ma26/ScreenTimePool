import Foundation
import FirebaseFirestore

struct FriendRequest: Codable, Identifiable {
    @DocumentID var id: String?
    var fromUserId: String
    var fromDisplayName: String
    var toUserId: String
    var toDisplayName: String
    var status: String // pending, accepted, declined, cancelled

    var documentId: String { id ?? "" }
}

struct Friendship: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var userIds: [String]
    var user1Id: String
    var user2Id: String
    var user1DisplayName: String
    var user2DisplayName: String
    var user1DeductsOnGrant: Bool
    var user2DeductsOnGrant: Bool
    var status: String

    var documentId: String { id ?? "" }

    func friendId(for currentUserId: String) -> String {
        currentUserId == user1Id ? user2Id : user1Id
    }

    func friendDisplayName(for currentUserId: String) -> String {
        currentUserId == user1Id ? user2DisplayName : user1DisplayName
    }

    func deductsOnGrant(for currentUserId: String) -> Bool {
        currentUserId == user1Id ? user1DeductsOnGrant : user2DeductsOnGrant
    }

    mutating func setDeductsOnGrant(for currentUserId: String, value: Bool) {
        if currentUserId == user1Id {
            user1DeductsOnGrant = value
        } else {
            user2DeductsOnGrant = value
        }
    }
}

final class FriendshipService {
    static let shared = FriendshipService()

    private let db = Firestore.firestore()
    private let friendRequestsCollection = "friend_requests"
    private let friendshipsCollection = "friendships"

    private init() {}

    // MARK: - Friend Requests

    func sendFriendRequest(from: (uid: String, name: String), to: (uid: String, name: String)) async throws {
        let request = FriendRequest(
            fromUserId: from.uid,
            fromDisplayName: from.name,
            toUserId: to.uid,
            toDisplayName: to.name,
            status: "pending"
        )
        _ = try db.collection(friendRequestsCollection).addDocument(from: request)
    }

    func acceptFriendRequest(_ request: FriendRequest) async throws {
        guard let docId = request.id else { return }
        try await db.collection(friendRequestsCollection).document(docId).updateData([
            "status": "accepted"
        ])
    }

    func declineFriendRequest(_ request: FriendRequest) async throws {
        guard let docId = request.id else { return }
        try await db.collection(friendRequestsCollection).document(docId).updateData([
            "status": "declined"
        ])
    }

    func cancelFriendRequest(_ request: FriendRequest) async throws {
        guard let docId = request.id else { return }
        try await db.collection(friendRequestsCollection).document(docId).updateData([
            "status": "cancelled"
        ])
    }

    func listenToIncomingRequests(userId: String, onChange: @escaping ([FriendRequest]) -> Void) -> ListenerRegistration {
        db.collection(friendRequestsCollection)
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else {
                    onChange([])
                    return
                }
                let requests = docs.compactMap { try? $0.data(as: FriendRequest.self) }
                onChange(requests)
            }
    }

    func listenToOutgoingRequests(userId: String, onChange: @escaping ([FriendRequest]) -> Void) -> ListenerRegistration {
        db.collection(friendRequestsCollection)
            .whereField("fromUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else {
                    onChange([])
                    return
                }
                let requests = docs.compactMap { try? $0.data(as: FriendRequest.self) }
                onChange(requests)
            }
    }

    // MARK: - Friendships

    func listenToFriendships(userId: String, onChange: @escaping ([Friendship]) -> Void) -> ListenerRegistration {
        db.collection(friendshipsCollection)
            .whereField("userIds", arrayContains: userId)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else {
                    onChange([])
                    return
                }
                let friendships = docs.compactMap { try? $0.data(as: Friendship.self) }
                onChange(friendships)
            }
    }

    func updateDeductionToggle(friendshipId: String, field: String, value: Bool) async throws {
        try await db.collection(friendshipsCollection).document(friendshipId).updateData([
            field: value
        ])
    }

    func removeFriendship(_ friendship: Friendship) async throws {
        guard let docId = friendship.id else { return }
        try await db.collection(friendshipsCollection).document(docId).delete()
    }

    // MARK: - Check Existing

    func existingFriendship(userId: String, friendId: String) async throws -> Friendship? {
        let sorted = [userId, friendId].sorted()
        let docId = "\(sorted[0])_\(sorted[1])"
        let doc = try await db.collection(friendshipsCollection).document(docId).getDocument()
        return try? doc.data(as: Friendship.self)
    }

    func hasPendingRequest(from: String, to: String) async throws -> Bool {
        let snapshot = try await db.collection(friendRequestsCollection)
            .whereField("fromUserId", isEqualTo: from)
            .whereField("toUserId", isEqualTo: to)
            .whereField("status", isEqualTo: "pending")
            .limit(to: 1)
            .getDocuments()
        return !snapshot.documents.isEmpty
    }
}
