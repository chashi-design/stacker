import Foundation

enum LogDateHelper {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }()

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = LogDateHelper.calendar
        formatter.timeZone = LogDateHelper.calendar.timeZone
        formatter.dateFormat = "yyyy年M月d日(E)"
        return formatter
    }()

    static func normalized(_ date: Date, calendar: Calendar = LogDateHelper.calendar) -> Date {
        calendar.startOfDay(for: date)
    }

    static func label(for date: Date) -> String {
        formatter.string(from: date)
    }
}
