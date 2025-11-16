import Foundation

enum LogDateHelper {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(E)"
        return formatter
    }()

    static func normalized(_ date: Date, calendar: Calendar = Calendar.current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func label(for date: Date) -> String {
        formatter.string(from: date)
    }
}
