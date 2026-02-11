import Foundation

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isSameDayAs: (Date) -> Bool {
        { other in Calendar.current.isDate(self, inSameDayAs: other) }
    }

    func adding(minutes: Int) -> Date {
        addingTimeInterval(TimeInterval(minutes * 60))
    }

    func adding(seconds: Int) -> Date {
        addingTimeInterval(TimeInterval(seconds))
    }

    static func minutesUntilMidnight() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.startOfDay(for: now.addingTimeInterval(86400))
        return Int(tomorrow.timeIntervalSince(now) / 60)
    }
}
