import Charts
import SwiftUI

// 活動記録画面
struct OverviewActivityRecordView: View {
    let workouts: [Workout]
    let calendar: Calendar

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedYear: Int
    @State private var isShowingYearPicker = false
    @State private var yearPickerValue: Int
    @State private var cachedFirstWeekday: Int
    private let monthColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private var strings: OverviewActivityRecordViewStrings {
        OverviewActivityRecordViewStrings(isJapanese: isJapaneseLocale)
    }

    init(workouts: [Workout], calendar: Calendar) {
        self.workouts = workouts
        self.calendar = calendar
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        _selectedYear = State(initialValue: currentYear)
        _yearPickerValue = State(initialValue: currentYear)
        _cachedFirstWeekday = State(initialValue: calendar.firstWeekday)
    }

    var body: some View {
        let yearRange = ActivityRecordMetrics.yearRange(year: selectedYear, calendar: calendar)
        let activityByDay = yearRange.map {
            ActivityRecordMetrics.dailyExerciseCounts(
                workouts: workouts,
                calendar: calendar,
                range: $0
            )
        } ?? [:]
        let activeDays = activityByDay.count
        let totalDays = ActivityRecordMetrics.totalDaysInYear(year: selectedYear, calendar: calendar)
        let percentText = percentText(activeDays: activeDays, totalDays: totalDays)
        let months = monthsInYear(for: selectedYear)

        return List {
            Section {
                VStack(alignment: .center, spacing: 8) {
                    summaryBarChart(activeDays: activeDays, totalDays: totalDays)
                    Text(strings.summaryValue(activeDays: activeDays, totalDays: totalDays, percentText: percentText))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets(top: 28, leading: 20, bottom: 20, trailing: 20))
            } header: {
                Text(strings.summarySectionTitle)
            }

            Section {
                LazyVGrid(columns: monthColumns, alignment: .leading, spacing: 32) {
                    ForEach(months) { month in
                        monthCell(for: month.date, activityByDay: activityByDay)
                    }
                }
                .id(cachedFirstWeekday)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } header: {
                Text(strings.monthSectionTitle)
            }

            Section {
                heatmapLegend
                    .padding(.vertical, 4)
            } header: {
                Text(strings.legendSectionTitle)
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, 4, for: .scrollContent)
        .navigationTitle(strings.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HapticButton {
                    isShowingYearPicker = true
                } label: {
                    Text(yearLabel(for: selectedYear))
                        .foregroundStyle(.primary)
                }
                .tint(.primary)
            }
        }
        .onChange(of: isShowingYearPicker) { _, isShowing in
            if isShowing {
                yearPickerValue = selectedYear
            }
        }
        .sheet(isPresented: $isShowingYearPicker) {
            NavigationStack {
                VStack(spacing: 12) {
                    Picker(strings.yearPickerLabel, selection: $yearPickerValue) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(yearLabel(for: year))
                                .monospacedDigit()
                                .tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 160)
                }
                .padding(.horizontal, 24)
                .navigationTitle(strings.yearPickerTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        HapticButton {
                            isShowingYearPicker = false
                        } label: {
                            Text(strings.cancelTitle)
                                .foregroundStyle(.primary)
                        }
                        .tint(.primary)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        HapticButton {
                            selectedYear = yearPickerValue
                            isShowingYearPicker = false
                        } label: {
                            Label(strings.doneTitle, systemImage: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            updateFirstWeekdayIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
            updateFirstWeekdayIfNeeded()
        }
    }

    private var availableYears: [Int] {
        let years = Set(workouts.map { calendar.component(.year, from: $0.date) })
        let currentYear = calendar.component(.year, from: Date())
        return Array(years.union([currentYear])).sorted()
    }

    private func monthsInYear(for year: Int) -> [MonthSlot] {
        (1...12).compactMap { month in
            guard let date = ActivityRecordMetrics.monthStart(year: year, month: month, calendar: calendar) else {
                return nil
            }
            return MonthSlot(month: month, date: date)
        }
    }

    private func updateFirstWeekdayIfNeeded() {
        let firstWeekday = calendar.firstWeekday
        if firstWeekday != cachedFirstWeekday {
            cachedFirstWeekday = firstWeekday
        }
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = isJapaneseLocale ? "M月" : "MMM"
        return formatter.string(from: date)
    }

    private func percentText(activeDays: Int, totalDays: Int) -> String {
        guard totalDays > 0 else { return "0%" }
        let ratio = Double(activeDays) / Double(totalDays)
        return ratio.formatted(.percent.precision(.fractionLength(0)))
    }

    private func summaryBarChart(activeDays: Int, totalDays: Int) -> some View {
        let total = max(totalDays, 1)
        let active = min(activeDays, total)

        return Chart {
            BarMark(
                xStart: .value("Start", 0),
                xEnd: .value("Total", total),
                y: .value("Row", "activity")
            )
            .foregroundStyle(Color.gray.opacity(0.2))

            BarMark(
                xStart: .value("Start", 0),
                xEnd: .value("Active", active),
                y: .value("Row", "activity")
            )
            .foregroundStyle(Color.accentColor)
        }
        .chartXScale(domain: 0...Double(total))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(height: 18)
    }

    private var heatmapLegend: some View {
        LazyVGrid(columns: legendColumns, alignment: .leading, spacing: 8) {
            legendItem(color: ActivityHeatmapPalette.color(for: 0), label: strings.legendZeroLabel)
            legendItem(color: ActivityHeatmapPalette.color(for: 1), label: strings.legendOneLabel)
            legendItem(color: ActivityHeatmapPalette.color(for: 3), label: strings.legendThreeLabel)
            legendItem(color: ActivityHeatmapPalette.color(for: 5), label: strings.legendFiveLabel)
        }
    }

    private var legendColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func monthCell(for month: Date, activityByDay: [Date: Int]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(monthLabel(for: month))
                .font(.subheadline.weight(.semibold))
            ActivityHeatmapView(
                month: month,
                calendar: calendar,
                activityByDay: activityByDay,
                cellSize: 10,
                spacing: 4,
                cornerRadius: 3
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func yearLabel(for year: Int) -> String {
        isJapaneseLocale ? "\(year)年" : String(year)
    }
}

private struct MonthSlot: Identifiable {
    let month: Int
    let date: Date
    var id: Int { month }
}

private struct OverviewActivityRecordViewStrings {
    let isJapanese: Bool

    var title: String { isJapanese ? "活動記録" : "Activity Record" }
    var yearPickerTitle: String { isJapanese ? "年を選択" : "Select Year" }
    var yearPickerLabel: String { isJapanese ? "年" : "Year" }
    var cancelTitle: String { isJapanese ? "キャンセル" : "Cancel" }
    var doneTitle: String { isJapanese ? "完了" : "Done" }
    var summarySectionTitle: String { isJapanese ? "活動割合" : "Activity" }
    var monthSectionTitle: String { isJapanese ? "月別" : "By Month" }
    var legendSectionTitle: String { isJapanese ? "凡例" : "Legend" }
    var summaryLabel: String { isJapanese ? "活動割合" : "Activity" }
    var legendZeroLabel: String { isJapanese ? "0種目" : "0 exercises" }
    var legendOneLabel: String { isJapanese ? "1-2種目" : "1-2 exercises" }
    var legendThreeLabel: String { isJapanese ? "3-4種目" : "3-4 exercises" }
    var legendFiveLabel: String { isJapanese ? "5種目以上" : "5+ exercises" }

    func summaryValue(activeDays: Int, totalDays: Int, percentText: String) -> String {
        if isJapanese {
            return "\(activeDays)/\(totalDays)日・\(percentText)"
        }
        return "\(activeDays)/\(totalDays) days · \(percentText)"
    }
}

#Preview {
    NavigationStack {
        OverviewActivityRecordView(workouts: [], calendar: .appCurrent)
    }
}
