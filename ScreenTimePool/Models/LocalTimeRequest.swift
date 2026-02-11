import Foundation
import SwiftData

enum TimeRequestStatus: String, Codable {
    case pending
    case approved
    case denied
    case modified
    case expired
}

@Model
final class LocalTimeRequest {
    @Attribute(.unique) var requestId: String
    var fromUserId: String
    var fromDisplayName: String
    var toUserId: String
    var toDisplayName: String
    var requestedMinutes: Int
    var grantedMinutes: Int?
    var status: TimeRequestStatus
    var deductsFromGranter: Bool
    var expiresAt: Date
    var createdAt: Date

    init(
        requestId: String = UUID().uuidString,
        fromUserId: String,
        fromDisplayName: String,
        toUserId: String,
        toDisplayName: String,
        requestedMinutes: Int,
        grantedMinutes: Int? = nil,
        status: TimeRequestStatus = .pending,
        deductsFromGranter: Bool = false,
        expiresAt: Date = Date().addingTimeInterval(3600),
        createdAt: Date = .now
    ) {
        self.requestId = requestId
        self.fromUserId = fromUserId
        self.fromDisplayName = fromDisplayName
        self.toUserId = toUserId
        self.toDisplayName = toDisplayName
        self.requestedMinutes = requestedMinutes
        self.grantedMinutes = grantedMinutes
        self.status = status
        self.deductsFromGranter = deductsFromGranter
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }
}
