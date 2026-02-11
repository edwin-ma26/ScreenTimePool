import Foundation
import SwiftData

@Model
final class LocalUserProfile {
    @Attribute(.unique) var uid: String
    var displayName: String
    var email: String
    var dailyPoolMinutes: Int
    var sessionDurationMinutes: Int
    var downtimeDurationMinutes: Int
    var remainingPoolSeconds: Int
    var lastPoolResetDate: Date

    init(
        uid: String,
        displayName: String = "",
        email: String = "",
        dailyPoolMinutes: Int = 120,
        sessionDurationMinutes: Int = 25,
        downtimeDurationMinutes: Int = 5,
        remainingPoolSeconds: Int = 7200,
        lastPoolResetDate: Date = .now
    ) {
        self.uid = uid
        self.displayName = displayName
        self.email = email
        self.dailyPoolMinutes = dailyPoolMinutes
        self.sessionDurationMinutes = sessionDurationMinutes
        self.downtimeDurationMinutes = downtimeDurationMinutes
        self.remainingPoolSeconds = remainingPoolSeconds
        self.lastPoolResetDate = lastPoolResetDate
    }
}
