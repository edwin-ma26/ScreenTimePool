import Foundation
import FirebaseFirestore

struct FirestoreUserProfile: Codable {
    var uid: String
    var displayName: String
    var displayNameLowercase: String
    var email: String
    var fcmToken: String?
    var dailyPoolMinutes: Int
    var sessionDurationMinutes: Int
    var downtimeDurationMinutes: Int
    var remainingPoolSeconds: Int
    var lastPoolResetDate: Date
}

final class FirestoreService {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()
    private let usersCollection = "users"

    private init() {}

    // MARK: - User CRUD

    func createUser(_ profile: FirestoreUserProfile) async throws {
        try db.collection(usersCollection).document(profile.uid).setData(from: profile)
    }

    func getUser(uid: String) async throws -> FirestoreUserProfile? {
        let doc = try await db.collection(usersCollection).document(uid).getDocument()
        return try doc.data(as: FirestoreUserProfile.self)
    }

    func updateUser(uid: String, data: [String: Any]) async throws {
        try await db.collection(usersCollection).document(uid).updateData(data)
    }

    func updateRemainingPool(uid: String, seconds: Int) async throws {
        try await db.collection(usersCollection).document(uid).updateData([
            "remainingPoolSeconds": seconds
        ])
    }

    func updateFCMToken(uid: String, token: String) async throws {
        try await db.collection(usersCollection).document(uid).updateData([
            "fcmToken": token
        ])
    }

    func updateSettings(uid: String, dailyPoolMinutes: Int, sessionDurationMinutes: Int, downtimeDurationMinutes: Int) async throws {
        try await db.collection(usersCollection).document(uid).updateData([
            "dailyPoolMinutes": dailyPoolMinutes,
            "sessionDurationMinutes": sessionDurationMinutes,
            "downtimeDurationMinutes": downtimeDurationMinutes,
            "remainingPoolSeconds": dailyPoolMinutes * 60
        ])
    }

    func resetDailyPool(uid: String, poolMinutes: Int) async throws {
        try await db.collection(usersCollection).document(uid).updateData([
            "remainingPoolSeconds": poolMinutes * 60,
            "lastPoolResetDate": Timestamp(date: Date())
        ])
    }

    func deleteUser(uid: String) async throws {
        try await db.collection(usersCollection).document(uid).delete()
    }

    // MARK: - User Search

    func searchUsers(query: String) async throws -> [FirestoreUserProfile] {
        let lowercased = query.lowercased()
        let snapshot = try await db.collection(usersCollection)
            .whereField("displayNameLowercase", isGreaterThanOrEqualTo: lowercased)
            .whereField("displayNameLowercase", isLessThanOrEqualTo: lowercased + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: FirestoreUserProfile.self)
        }
    }

    // MARK: - Listener

    func listenToUser(uid: String, onChange: @escaping (FirestoreUserProfile?) -> Void) -> ListenerRegistration {
        db.collection(usersCollection).document(uid).addSnapshotListener { snapshot, error in
            guard let snapshot, error == nil else {
                onChange(nil)
                return
            }
            let profile = try? snapshot.data(as: FirestoreUserProfile.self)
            onChange(profile)
        }
    }
}
