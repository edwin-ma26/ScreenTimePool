import Foundation

extension TimeInterval {
    var formattedAsMMSS: String {
        let total = Int(self)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedAsHHMMSS: String {
        let total = Int(self)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedAsHumanReadable: String {
        let total = Int(self)
        let hours = total / 3600
        let minutes = (total % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

extension Int {
    var formattedAsMMSS: String {
        TimeInterval(self).formattedAsMMSS
    }

    var formattedAsHHMMSS: String {
        TimeInterval(self).formattedAsHHMMSS
    }

    var formattedAsHumanReadable: String {
        TimeInterval(self).formattedAsHumanReadable
    }
}
