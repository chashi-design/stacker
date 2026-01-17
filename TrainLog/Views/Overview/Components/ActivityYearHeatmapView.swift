import SwiftUI

struct ActivityYearHeatmapView: View {
    let year: Int
    let calendar: Calendar
    let activityByDay: [Date: Int]
    var cellSize: CGFloat = 20
    var spacing: CGFloat = 4
    var cornerRadius: CGFloat = 1
    private let axisSpacing: CGFloat = 6
    private let axisLabelHeight: CGFloat = 14

    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private static let englishMonthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.shortMonthSymbols
    }()

    var body: some View {
        let dates = gridDates
        let labels = monthAxisLabels
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                weekdayAxis
                VStack(alignment: .leading, spacing: axisSpacing) {
                    monthAxis(labels: labels)
                    LazyHGrid(rows: rows, spacing: spacing) {
                        ForEach(dates.indices, id: \.self) { index in
                            if let date = dates[index] {
                                let count = activityByDay[calendar.startOfDay(for: date)] ?? 0
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(ActivityHeatmapPalette.color(for: count))
                                    .frame(width: cellSize, height: cellSize)
                            } else {
                                Color.clear
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                    .frame(height: fixedHeight, alignment: .topLeading)
                }
                .frame(width: gridWidth, alignment: .leading)
            }
        }
        .frame(height: fixedHeight + axisLabelHeight + axisSpacing)
    }

    private var fixedHeight: CGFloat {
        cellSize * 7 + spacing * 6
    }

    private var rows: [GridItem] {
        Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: 7)
    }

    private var gridWidth: CGFloat {
        let columns = weekStarts.count
        let totalSpacing = spacing * CGFloat(max(columns - 1, 0))
        return CGFloat(columns) * cellSize + totalSpacing
    }

    private var weekdayAxis: some View {
        let mondayIndex = weekdayIndex(for: 2)
        let wednesdayIndex = weekdayIndex(for: 4)
        let fridayIndex = weekdayIndex(for: 6)
        let labels: [Int: String] = [
            mondayIndex: weekdayLabel(for: 2),
            wednesdayIndex: weekdayLabel(for: 4),
            fridayIndex: weekdayLabel(for: 6)
        ]

        return VStack(spacing: spacing) {
            Color.clear
                .frame(height: axisLabelHeight + axisSpacing)
            ForEach(0..<7, id: \.self) { index in
                if let label = labels[index] {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: cellSize, alignment: .leading)
                } else {
                    Color.clear
                        .frame(width: 16, height: cellSize)
                }
            }
        }
    }

    private func monthAxis(labels: [String]) -> some View {
        HStack(spacing: spacing) {
            ForEach(labels.indices, id: \.self) { index in
                Text(labels[index])
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: cellSize, height: axisLabelHeight, alignment: .leading)
            }
        }
        .frame(height: axisLabelHeight, alignment: .leading)
    }

    private var gridDates: [Date?] {
        guard let range = ActivityRecordMetrics.yearRange(year: year, calendar: calendar) else { return [] }
        let weeks = weekStarts
        var dates: [Date?] = []
        for weekStart in weeks {
            for row in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: row, to: weekStart) else {
                    dates.append(nil)
                    continue
                }
                if date < range.start || date >= range.end {
                    dates.append(nil)
                } else {
                    dates.append(date)
                }
            }
        }
        return dates
    }

    private var weekStarts: [Date] {
        guard let range = ActivityRecordMetrics.yearRange(year: year, calendar: calendar) else { return [] }
        let start = range.start
        let end = calendar.date(byAdding: .day, value: -1, to: range.end) ?? start
        let startWeek = calendar.startOfWeek(for: start) ?? start
        let endWeek = calendar.startOfWeek(for: end) ?? end

        var weeks: [Date] = []
        var current = startWeek
        while current <= endWeek {
            weeks.append(current)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: current) else { break }
            current = next
        }
        return weeks
    }

    private var monthAxisLabels: [String] {
        let weeks = weekStarts
        var labels = Array(repeating: "", count: weeks.count)
        for month in 1...12 {
            guard let monthStart = ActivityRecordMetrics.monthStart(year: year, month: month, calendar: calendar) else {
                continue
            }
            if let index = weekIndex(for: monthStart, weeks: weeks) {
                labels[index] = monthAxisLabel(for: month)
            }
        }
        return labels
    }

    private func weekIndex(for date: Date, weeks: [Date]) -> Int? {
        for (index, weekStart) in weeks.enumerated() {
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { continue }
            if date >= weekStart && date < weekEnd {
                return index
            }
        }
        return nil
    }

    private func weekdayIndex(for weekday: Int) -> Int {
        (weekday - calendar.firstWeekday + 7) % 7
    }

    private func weekdayLabel(for weekday: Int) -> String {
        if isJapaneseLocale {
            switch weekday {
            case 2: return "月"
            case 4: return "水"
            case 6: return "金"
            default: return ""
            }
        }
        switch weekday {
        case 2: return "M"
        case 4: return "W"
        case 6: return "F"
        default: return ""
        }
    }

    private func monthAxisLabel(for month: Int) -> String {
        guard (1...12).contains(month) else { return "" }
        if isJapaneseLocale {
            return "\(month)月"
        }
        return Self.englishMonthSymbols[month - 1]
    }
}

#Preview {
    ActivityYearHeatmapView(
        year: 2026,
        calendar: .appCurrent,
        activityByDay: [:]
    )
    .padding()
}
