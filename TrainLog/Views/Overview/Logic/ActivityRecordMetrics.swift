import Foundation

struct ActivityRecordMetrics {
    static func monthStart(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func monthStart(year: Int, month: Int, calendar: Calendar) -> Date? {
        let components = DateComponents(year: year, month: month, day: 1)
        return calendar.date(from: components)
    }

    static func monthRange(year: Int, month: Int, calendar: Calendar) -> DateInterval? {
        let components = DateComponents(year: year, month: month, day: 1)
        guard let start = calendar.date(from: components),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
        return DateInterval(start: start, end: end)
    }

    static func yearStart(year: Int, calendar: Calendar) -> Date? {
        let components = DateComponents(year: year, month: 1, day: 1)
        return calendar.date(from: components)
    }

    static func yearRange(year: Int, calendar: Calendar) -> DateInterval? {
        guard let start = yearStart(year: year, calendar: calendar),
              let end = calendar.date(byAdding: .year, value: 1, to: start) else { return nil }
        return DateInterval(start: start, end: end)
    }

    static func totalDaysInYear(year: Int, calendar: Calendar) -> Int {
        guard let start = yearStart(year: year, calendar: calendar),
              let range = calendar.range(of: .day, in: .year, for: start) else { return 365 }
        return range.count
    }

    static func dailyExerciseCounts(workouts: [Workout], calendar: Calendar, month: Date) -> [Date: Int] {
        guard let range = calendar.dateInterval(of: .month, for: month) else { return [:] }
        return dailyExerciseCounts(workouts: workouts, calendar: calendar, range: range)
    }

    static func dailyExerciseCounts(
        workouts: [Workout],
        calendar: Calendar,
        range: DateInterval
    ) -> [Date: Int] {
        var buckets: [Date: Set<String>] = [:]
        for workout in workouts where workout.date >= range.start && workout.date < range.end {
            let day = calendar.startOfDay(for: workout.date)
            for set in workout.sets {
                buckets[day, default: []].insert(set.exerciseId)
            }
        }
        return buckets.mapValues { $0.count }
    }
}
