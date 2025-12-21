import SwiftUI

// SwiftUI製カレンダー（PageTabViewStyleで隣接月がスライド表示、固定高さでアニメーション安定）
struct LogCalendarSection: View {
    @Binding var selectedDate: Date
    let workoutDots: [Date: [Color]]

    @State private var months: [Date]
    @State private var selectionIndex: Int
    @State private var monthNavHapticTrigger: Int = 0
    @State private var dayTapHapticTrigger: Int = 0

    private var currentMonth: Date {
        months[safe: selectionIndex] ?? LogCalendarSection.startOfMonth(calendar, date: selectedDate)
    }

    private let today = LogDateHelper.normalized(Date())
    private let calendar = Calendar.current
    private let locale = Locale(identifier: "ja_JP")
    private let containerHeight: CGFloat = 312
    private let baseRowHeight: CGFloat = 40
    private let baseSpacing: CGFloat = 10
    private let calendarPadding: CGFloat = 8
    private let minCalendarHeight: CGFloat = 312

    init(selectedDate: Binding<Date>, workoutDots: [Date: [Color]]) {
        _selectedDate = selectedDate
        self.workoutDots = workoutDots

        let start = LogCalendarSection.startOfMonth(Calendar.current, date: selectedDate.wrappedValue)
        let built = LogCalendarSection.buildMonths(
            calendar: Calendar.current,
            today: LogDateHelper.normalized(Date()),
            workoutDots: workoutDots,
            selectedMonth: start
        )
        _months = State(initialValue: built)
        _selectionIndex = State(initialValue: built.firstIndex(of: start) ?? max(built.count - 1, 0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            monthHeader
            weekdayHeader
            pager
        }
        .sensoryFeedback(.impact(weight: .light), trigger: monthNavHapticTrigger)
        .sensoryFeedback(.impact(weight: .light), trigger: dayTapHapticTrigger)
        .padding(.vertical, 4)
        .onChange(of: selectedDate, initial: false) { _, newValue in
            let month = LogCalendarSection.startOfMonth(calendar, date: newValue)
            ensureMonthIncluded(month)
            if let idx = months.firstIndex(of: month) {
                selectionIndex = idx
            }
        }
        .onChange(of: workoutDots.count, initial: false) { _, _ in
            let currentMonth = months[safe: selectionIndex] ?? LogCalendarSection.startOfMonth(calendar, date: selectedDate)
            months = LogCalendarSection.buildMonths(
                calendar: calendar,
                today: today,
                workoutDots: workoutDots,
                selectedMonth: currentMonth
            )
            selectionIndex = months.firstIndex(of: currentMonth) ?? max(months.count - 1, 0)
        }
    }

    // MARK: Header
    private var monthHeader: some View {
        let month = months[safe: selectionIndex] ?? LogCalendarSection.startOfMonth(calendar, date: selectedDate)
        return HStack {
            Button {
                monthNavHapticTrigger += 1
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 17, weight: .bold))
            }

            Spacer()

            Text(monthTitle(for: month))
                .font(.title3.bold())

            Spacer()

            Button {
                monthNavHapticTrigger += 1
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(isNextMonthBeyondToday(month) ? Color.secondary : Color.accentColor)
                    .font(.system(size: 17, weight: .bold))
            }
            .disabled(isNextMonthBeyondToday(month))
        }
        .buttonStyle(.plain)
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(Locale.japaneseWeekdayInitials, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Pager
    private var pager: some View {
        TabView(selection: $selectionIndex) {
            ForEach(months.indices, id: \.self) { idx in
                calendarPage(for: months[idx])
                    .tag(idx)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(height: containerHeight, alignment: .top)
        .onChange(of: selectionIndex, initial: false) { _, newValue in
            guard months.indices.contains(newValue) else { return }
            let month = months[newValue]
            if !calendar.isDate(selectedDate, equalTo: month, toGranularity: .month) {
                if let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) {
                    selectedDate = LogDateHelper.normalized(first)
                }
            }
        }
    }

    private func calendarPage(for month: Date) -> some View {
        let days = daysInMonth(month: month)
        let rows = rowsInMonth(month)
        let rowHeight = rows > 0 ? max(36, min(52, containerHeight / CGFloat(rows))) : 52
        let spacing = rows > 0 ? max(4, min(12, (containerHeight - CGFloat(rows) * rowHeight) / CGFloat(max(rows - 1, 1)))) : 10
        let contentHeight = CGFloat(rows) * rowHeight + CGFloat(max(rows - 1, 0)) * spacing + calendarPadding

        return VStack(spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: spacing) {
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        dayCell(for: date)
                    } else {
                        Color.clear.frame(height: rowHeight)
                    }
                }
            }
            .padding(.horizontal, 4)
            Spacer(minLength: max(0, containerHeight - contentHeight))
        }
        .frame(height: containerHeight, alignment: .top)
    }

    private func rowsInMonth(_ month: Date) -> Int {
        let days = daysInMonth(month: month)
        return Int(ceil(Double(days.count) / 7.0))
    }

    private func gridHeight(rows: Int) -> CGFloat {
        CGFloat(rows) * baseRowHeight + CGFloat(max(rows - 1, 0)) * baseSpacing + calendarPadding
    }

    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: today)
        let dots = workoutDots[calendar.startOfDay(for: date)] ?? []

        return VStack(spacing: 6) {
            Text("\(calendar.component(.day, from: date))")
                .font(.body.weight(isSelected ? .bold : .semibold))
                .foregroundStyle(
                    isSelected ? Color.white :
                        (isToday ? Color.accentColor : Color.primary)
            
                )
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )

            HStack(spacing: 2) {
                ForEach(Array(dots.prefix(6)).indices, id: \.self) { idx in
                    Circle()
                        .fill(dots[idx])
                        .frame(width: 5.5, height: 5.5)
                }
            }
            .frame(height: 6)
        }
        .frame(height: 48)
        .contentShape(Rectangle())
        .onTapGesture {
            dayTapHapticTrigger += 1
            selectedDate = LogDateHelper.normalized(date)
        }
    }

    // MARK: Helpers
    private func daysInMonth(month: Date) -> [Date?] {
        guard
            let range = calendar.range(of: .day, in: .month, for: month),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }

    private func shiftMonth(by value: Int, allowFuture: Bool = true) {
        let newIndex = selectionIndex + value
        guard months.indices.contains(newIndex) else { return }
        let newMonth = months[newIndex]
        if !allowFuture && calendar.compare(newMonth, to: today, toGranularity: .month) == .orderedDescending {
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            selectionIndex = newIndex
        }
        if !calendar.isDate(selectedDate, equalTo: newMonth, toGranularity: .month) {
            if let first = calendar.date(from: calendar.dateComponents([.year, .month], from: newMonth)) {
                selectedDate = LogDateHelper.normalized(first)
            }
        }
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    private func isNextMonthBeyondToday(_ base: Date) -> Bool {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: base) else {
            return true
        }
        return calendar.compare(nextMonth, to: today, toGranularity: .month) == .orderedDescending
    }

    private func ensureMonthIncluded(_ month: Date) {
        if months.contains(month) { return }
        months = LogCalendarSection.buildMonths(
            calendar: calendar,
            today: today,
            workoutDots: workoutDots,
            selectedMonth: month
        )
    }

    // MARK: - Static helpers
    private static func startOfMonth(_ calendar: Calendar, date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    private static func buildMonths(
        calendar: Calendar,
        today: Date,
        workoutDots: [Date: [Color]],
        selectedMonth: Date
    ) -> [Date] {
        let earliestDot = workoutDots.keys.min()
        let historicalStart = calendar.date(byAdding: .year, value: -3, to: today) ?? today
        let start = min(
            historicalStart,
            earliestDot ?? historicalStart,
            selectedMonth
        )
        let startMonth = startOfMonth(calendar, date: min(start, selectedMonth))
        let endBase = max(today, selectedMonth)
        let endMonth = startOfMonth(calendar, date: endBase)

        var months: [Date] = []
        var cursor = startMonth
        while cursor <= endMonth {
            months.append(cursor)
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? endMonth
        }

        if !months.contains(selectedMonth) {
            months.append(selectedMonth)
            months.sort()
        }
        return months
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Locale {
    static let japaneseWeekdayInitials = ["日", "月", "火", "水", "木", "金", "土"]
}
