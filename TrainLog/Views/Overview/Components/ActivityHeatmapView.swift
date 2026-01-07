import SwiftUI

struct ActivityHeatmapView: View {
    let month: Date
    let calendar: Calendar
    let activityByDay: [Date: Int]
    var cellSize: CGFloat = 16
    var spacing: CGFloat = 6
    var cornerRadius: CGFloat = 4

    var body: some View {
        let days = gridDays(for: month)
        LazyVGrid(columns: columns, alignment: .center, spacing: spacing) {
            ForEach(days.indices, id: \.self) { index in
                if let date = days[index] {
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
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: 7)
    }

    private func gridDays(for month: Date) -> [Date?] {
        guard
            let range = calendar.range(of: .day, in: .month, for: month),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingEmptyCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingEmptyCount)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        let remainder = days.count % 7
        if remainder != 0 {
            days.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }

        return days
    }
}

enum ActivityHeatmapPalette {
    static func color(for count: Int) -> Color {
        if count <= 0 {
            return .gray.opacity(0.2)
        }
        if count <= 2 {
            return .blue.opacity(0.25)
        }
        if count <= 4 {
            return .blue.opacity(0.5)
        }
        return .blue
    }
}

#Preview {
    ActivityHeatmapView(
        month: Date(),
        calendar: .appCurrent,
        activityByDay: [:]
    )
    .padding()
}
