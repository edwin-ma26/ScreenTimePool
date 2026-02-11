import Foundation
import SwiftData

enum SessionPhase: String, Codable {
    case idle
    case active
    case downtime
    case exhausted
}

@Model
final class LocalSessionState {
    var phase: SessionPhase
    var remainingSessionSeconds: Int
    var remainingDowntimeSeconds: Int
    var remainingPoolSeconds: Int
    var lastUpdated: Date

    init(
        phase: SessionPhase = .idle,
        remainingSessionSeconds: Int = 0,
        remainingDowntimeSeconds: Int = 0,
        remainingPoolSeconds: Int = 7200,
        lastUpdated: Date = .now
    ) {
        self.phase = phase
        self.remainingSessionSeconds = remainingSessionSeconds
        self.remainingDowntimeSeconds = remainingDowntimeSeconds
        self.remainingPoolSeconds = remainingPoolSeconds
        self.lastUpdated = lastUpdated
    }
}
