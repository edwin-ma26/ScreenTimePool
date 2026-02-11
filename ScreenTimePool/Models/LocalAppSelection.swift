import Foundation
import SwiftData

@Model
final class LocalAppSelection {
    var selectionData: Data?
    var lastUpdated: Date

    init(selectionData: Data? = nil, lastUpdated: Date = .now) {
        self.selectionData = selectionData
        self.lastUpdated = lastUpdated
    }
}
