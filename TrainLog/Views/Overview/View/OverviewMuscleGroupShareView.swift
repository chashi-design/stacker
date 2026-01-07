import Charts
import SwiftUI

// 種目の割合画面
struct OverviewMuscleGroupShareView: View {
    let workouts: [Workout]
    let exercises: [ExerciseCatalog]
    let isLoadingExercises: Bool
    let calendar: Calendar

    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var isShowingMonthPicker = false
    @State private var monthPickerYear: Int
    @State private var monthPickerMonth: Int

    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private var strings: OverviewMuscleGroupShareViewStrings {
        OverviewMuscleGroupShareViewStrings(isJapanese: isJapaneseLocale)
    }

    init(
        workouts: [Workout],
        exercises: [ExerciseCatalog],
        isLoadingExercises: Bool,
        calendar: Calendar
    ) {
        self.workouts = workouts
        self.exercises = exercises
        self.isLoadingExercises = isLoadingExercises
        self.calendar = calendar
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        _selectedYear = State(initialValue: currentYear)
        _selectedMonth = State(initialValue: currentMonth)
        _monthPickerYear = State(initialValue: currentYear)
        _monthPickerMonth = State(initialValue: currentMonth)
    }

    var body: some View {
        monthPage(for: selectedMonth)
            .navigationTitle(strings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HapticButton {
                        isShowingMonthPicker = true
                    } label: {
                        Text(monthTitle(for: selectedMonth))
                            .foregroundStyle(.primary)
                    }
                    .tint(.primary)
                }
            }
            .onChange(of: isShowingMonthPicker) { _, isShowing in
                if isShowing {
                    monthPickerYear = selectedYear
                    monthPickerMonth = selectedMonth
                }
            }
            .sheet(isPresented: $isShowingMonthPicker) {
                NavigationStack {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Picker(strings.yearPickerLabel, selection: $monthPickerYear) {
                                ForEach(availableYears, id: \.self) { year in
                                    Text(yearLabel(for: year))
                                        .monospacedDigit()
                                        .tag(year)
                                }
                            }
                            .pickerStyle(.wheel)
                            .labelsHidden()

                            Picker(strings.monthPickerLabel, selection: $monthPickerMonth) {
                                ForEach(monthOptions, id: \.self) { month in
                                    Text(monthLabel(for: month))
                                        .monospacedDigit()
                                        .tag(month)
                                }
                            }
                            .pickerStyle(.wheel)
                            .labelsHidden()
                        }
                        .frame(height: 140)
                    }
                    .padding(.horizontal, 24)
                    .navigationTitle(strings.monthPickerTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            HapticButton {
                                isShowingMonthPicker = false
                            } label: {
                                Text(strings.cancelTitle)
                                    .foregroundStyle(.primary)
                            }
                            .tint(.primary)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            HapticButton {
                                selectedYear = monthPickerYear
                                selectedMonth = monthPickerMonth
                                isShowingMonthPicker = false
                            } label: {
                                Label(strings.doneTitle, systemImage: "checkmark")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
    }

    private var monthOptions: [Int] {
        Array(1...12)
    }

    private var availableYears: [Int] {
        let years = Set(workouts.map { calendar.component(.year, from: $0.date) })
        let currentYear = calendar.component(.year, from: Date())
        return Array(years.union([currentYear])).sorted()
    }

    private var exerciseLookup: [String: String] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.muscleGroup) })
    }

    private func monthPage(for month: Int) -> some View {
        let items = shareItems(for: month)
        let total = items.reduce(0) { $0 + $1.count }

        return List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    if isLoadingExercises {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if items.isEmpty {
                        Text(strings.noDataText)
                            .foregroundStyle(.secondary)
                    } else {
                        ZStack {
                            Chart {
                                ForEach(items) { item in
                                    SectorMark(
                                        angle: .value(strings.chartValueLabel, item.count),
                                        innerRadius: .ratio(0.7),
                                        angularInset: 2
                                    )
                                    .foregroundStyle(item.color)
                                    .cornerRadius(5)
                                }
                            }
                            .chartLegend(.hidden)

                            Text(monthTitle(for: month))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 220, height: 220)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }

            if !isLoadingExercises && !items.isEmpty {
                Section {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(item.color)
                            Text(item.label)
                                .font(.body)
                            Spacer()
                            Text(percentText(for: item.count, total: total))
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                } header: {
                    Text(strings.shareSectionTitle)
                } footer: {
                    Text(strings.basedOnExercisesText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, 4, for: .scrollContent)
    }

    private func shareItems(for month: Int) -> [MuscleGroupShareItem] {
        guard let range = monthRange(for: selectedYear, month: month) else { return [] }
        var countByGroup: [String: Int] = [:]

        for workout in workouts where workout.date >= range.start && workout.date < range.end {
            let exerciseIds = Set(workout.sets.map(\.exerciseId))
            for exerciseId in exerciseIds {
                let group = exerciseLookup[exerciseId] ?? "other"
                countByGroup[group, default: 0] += 1
            }
        }

        return countByGroup
            .map { MuscleGroupShareItem(muscleGroup: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.label < rhs.label
            }
    }

    private func monthRange(for year: Int, month: Int) -> DateInterval? {
        let components = DateComponents(year: year, month: month, day: 1)
        guard let start = calendar.date(from: components),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
        return DateInterval(start: start, end: end)
    }

    private func percentText(for count: Int, total: Int) -> String {
        guard total > 0 else { return "0%" }
        let ratio = Double(count) / Double(total)
        return ratio.formatted(.percent.precision(.fractionLength(0)))
    }

    private func monthTitle(for month: Int) -> String {
        let components = DateComponents(year: selectedYear, month: month, day: 1)
        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = isJapaneseLocale ? "yyyy年M月" : "MMM yyyy"
        return formatter.string(from: date)
    }

    private func monthLabel(for month: Int) -> String {
        let components = DateComponents(year: selectedYear, month: month, day: 1)
        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = isJapaneseLocale ? "M月" : "MMM"
        return formatter.string(from: date)
    }

    private func yearLabel(for year: Int) -> String {
        isJapaneseLocale ? "\(year)年" : String(year)
    }
}

private struct MuscleGroupShareItem: Identifiable {
    let muscleGroup: String
    let count: Int
    var id: String { muscleGroup }
    var label: String { MuscleGroupLabel.label(for: muscleGroup) }
    var color: Color { MuscleGroupColor.color(for: muscleGroup) }
}

private struct OverviewMuscleGroupShareViewStrings {
    let isJapanese: Bool

    var title: String { isJapanese ? "種目の割合" : "Exercise Share" }
    var noDataText: String { isJapanese ? "データがありません" : "No data available." }
    var basedOnExercisesText: String { isJapanese ? "※種目数ベース" : "Based on number of exercises" }
    var chartValueLabel: String { isJapanese ? "種目数" : "Exercises" }
    var shareSectionTitle: String { isJapanese ? "種目別" : "By Exercise" }
    var monthPickerTitle: String { isJapanese ? "年月を選択" : "Select Month" }
    var yearPickerLabel: String { isJapanese ? "年" : "Year" }
    var monthPickerLabel: String { isJapanese ? "月" : "Month" }
    var cancelTitle: String { isJapanese ? "キャンセル" : "Cancel" }
    var doneTitle: String { isJapanese ? "完了" : "Done" }
}

#Preview {
    NavigationStack {
        OverviewMuscleGroupShareView(
            workouts: [],
            exercises: [],
            isLoadingExercises: false,
            calendar: .appCurrent
        )
    }
}
