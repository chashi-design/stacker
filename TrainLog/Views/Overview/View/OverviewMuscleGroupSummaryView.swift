import SwiftUI

// 部位別の集計画面を表示する画面
struct OverviewMuscleGroupSummaryView: View {
    let muscleGroup: String
    let segment: MuscleGroupSegment
    let displayName: String
    let exercises: [ExerciseCatalog]
    let workouts: [Workout]
    @EnvironmentObject private var favoritesStore: ExerciseFavoritesStore
    @Environment(\.weightUnit) private var weightUnit

    @State private var chartPeriod: PartsChartPeriod = .week
    @State private var filter: PartsFilter = .all
    @State private var navigationFeedbackTrigger = 0
    @State private var exerciseFeedbackTrigger = 0
    @State private var selectedWeekItem: WeekListItem?
    @State private var selectedExerciseItem: ExerciseVolume?
    @State private var selectedWeeklyListItem: WeeklyListDestination?
    private struct WeeklyListDestination: Identifiable, Hashable {
        let id = UUID()
    }
    private let calendar = Calendar.appCurrent
    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }
    private var strings: OverviewMuscleGroupStrings {
        OverviewMuscleGroupStrings(isJapanese: isJapaneseLocale)
    }
    private var locale: Locale { strings.locale }
    private var trackingType: ExerciseTrackingType {
        OverviewMetrics.trackingType(for: muscleGroup, segment: segment)
    }

    private var exerciseVolumes: [ExerciseVolume] {
        OverviewMetrics.exerciseVolumesForCurrentWeek(
            workouts: workouts,
            exercises: exercises,
            muscleGroup: muscleGroup,
            calendar: calendar
        )
    }

    private var weeklySeries: [VolumePoint] {
        OverviewMetrics.weeklyMuscleGroupVolumes(
            muscleGroup: muscleGroup,
            workouts: workouts,
            exercises: exercises,
            calendar: calendar,
            weeks: 8,
            trackingType: trackingType
        )
    }

    private var chartSeries: [VolumePoint] {
        switch chartPeriod {
        case .day:
            return OverviewMetrics.dailyMuscleGroupVolumes(
                muscleGroup: muscleGroup,
                workouts: workouts,
                exercises: exercises,
                calendar: calendar,
                days: 7,
                trackingType: trackingType
            )
        case .week:
            return OverviewMetrics.weeklyMuscleGroupVolumes(
                muscleGroup: muscleGroup,
                workouts: workouts,
                exercises: exercises,
                calendar: calendar,
                weeks: 5,
                trackingType: trackingType
            )
        case .month:
            return OverviewMetrics.monthlyMuscleGroupVolumes(
                muscleGroup: muscleGroup,
                workouts: workouts,
                exercises: exercises,
                calendar: calendar,
                months: 6,
                trackingType: trackingType
            )
        }
    }

    private var chartData: [(label: String, value: Double)] {
        chartSeries
            .sorted { $0.date < $1.date }
            .map { (chartLabel(for: $0.date, period: chartPeriod), chartMetricValue(from: $0.volume)) }
    }

    private var recentWeeklyListData: [WeekListItem] {
        OverviewMetrics.weeklyMuscleGroupVolumesAll(
            muscleGroup: muscleGroup,
            workouts: workouts,
            exercises: exercises,
            calendar: calendar,
            trackingType: trackingType
        )
        .sorted { $0.date > $1.date }
        .prefix(3)
        .map {
            let start = calendar.startOfWeek(for: $0.date) ?? $0.date
            return WeekListItem(
                start: start,
                label: weekRangeLabel(for: start),
                volume: $0.volume,
                muscleGroup: muscleGroup,
                displayName: displayName
            )
        }
    }

    private var weeklyListData: [WeekListItem] {
        OverviewMetrics.weeklyMuscleGroupVolumesAll(
            muscleGroup: muscleGroup,
            workouts: workouts,
            exercises: exercises,
            calendar: calendar,
            trackingType: trackingType
        )
            .map {
                let start = calendar.startOfWeek(for: $0.date) ?? $0.date
                return WeekListItem(
                    start: start,
                    label: weekRangeLabel(for: start),
                    volume: $0.volume,
                    muscleGroup: muscleGroup,
                    displayName: displayName
                )
            }
    }

    var body: some View {
        List {
            Section(strings.totalMetricSectionTitle(trackingType: trackingType)) {
                Picker(strings.periodPickerTitle, selection: $chartPeriod) {
                    ForEach(PartsChartPeriod.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .segmentedHaptic(trigger: chartPeriod)

                ExerciseVolumeChart(
                    data: chartData,
                    barColor: MuscleGroupColor.color(for: muscleGroup),
                    animateOnAppear: true,
                    animateOnTrigger: true,
                    animationTrigger: chartPeriod.hashValue,
                    yValueLabel: strings.metricValueLabel(trackingType: trackingType, unit: weightUnit.unitLabel),
                    yAxisLabel: strings.metricAxisLabel(trackingType: trackingType, unit: weightUnit.unitLabel)
                )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if !recentWeeklyListData.isEmpty {
                Section {
                    ForEach(recentWeeklyListData) { item in
                        Button {
                            selectedWeekItem = item
                        } label: {
                            HStack {
                                Text(item.label)
                                    .font(.headline)
                                Spacer()
                                let parts = VolumeFormatter.metricParts(
                                    from: item.volume,
                                    trackingType: trackingType,
                                    locale: locale,
                                    unit: weightUnit
                                )
                                let unitText = parts.unit.isEmpty ? "" : " \(parts.unit)"
                                ValueWithUnitText(
                                    value: parts.value,
                                    unit: unitText,
                                    valueFont: .body,
                                    unitFont: .subheadline,
                                    valueColor: .secondary,
                                    unitColor: .secondary
                                )
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                                    .imageScale(.small)
                                    .font(.system(size: 17))
                                    .fontWeight(.semibold)
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text(strings.weeklyRecordsTitle)
                        Spacer()
                        Button {
                            selectedWeeklyListItem = WeeklyListDestination()
                        } label: {
                            Text(strings.viewAllTitle)
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section(strings.exerciseRecordsSectionTitle) {
                Picker(strings.filterPickerTitle, selection: $filter) {
                    ForEach(PartsFilter.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .segmentedHaptic(trigger: filter)
                ForEach(filteredExercises, id: \.exercise.id) { item in
                    Button {
                        selectedExerciseItem = item
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayName(for: item.exercise))
                                    .font(.headline)
                                Text(currentWeekLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                            }
                            Spacer()
                            let itemTrackingType = item.exercise.trackingType
                            let parts = VolumeFormatter.metricParts(
                                from: item.volume,
                                trackingType: itemTrackingType,
                                locale: locale,
                                unit: weightUnit
                            )
                            let unitText = parts.unit.isEmpty ? "" : " \(parts.unit)"
                            ValueWithUnitText(
                                value: parts.value,
                                unit: unitText,
                                valueFont: .body,
                                unitFont: .subheadline,
                                valueColor: .secondary,
                                unitColor: .secondary
                            )
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .imageScale(.small)
                                .font(.system(size: 17))
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if filteredExercises.isEmpty {
                    Text(strings.noExerciseText)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(displayName)
                    .font(.headline)
            }
        }
        .listSectionSpacing(10)
        .navigationDestination(item: $selectedWeekItem) { item in
            OverviewMuscleGroupWeekDetailView(
                weekStart: item.start,
                muscleGroup: item.muscleGroup,
                displayName: item.displayName,
                trackingType: trackingType,
                workouts: workouts,
                exercises: exercises
            )
        }
        .navigationDestination(item: $selectedWeeklyListItem) { _ in
            OverviewMuscleGroupWeeklyListView(
                title: strings.weeklyRecordsTitle,
                items: weeklyListData,
                trackingType: trackingType,
                workouts: workouts,
                exercises: exercises
            )
        }
        .navigationDestination(item: $selectedExerciseItem) { item in
            OverviewExerciseSummaryView(
                exercise: item.exercise,
                workouts: workouts
            )
        }
        .onChange(of: selectedWeekItem) { _, newValue in
            if newValue != nil {
                navigationFeedbackTrigger += 1
            }
        }
        .onChange(of: selectedExerciseItem) { _, newValue in
            if newValue != nil {
                exerciseFeedbackTrigger += 1
            }
        }
        .onChange(of: selectedWeeklyListItem) { _, newValue in
            if newValue != nil {
                navigationFeedbackTrigger += 1
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: navigationFeedbackTrigger)
        .sensoryFeedback(.impact(weight: .light), trigger: exerciseFeedbackTrigger)
    }

    private var filteredExercises: [ExerciseVolume] {
        switch filter {
        case .all:
            return exerciseVolumes
        case .favorites:
            return exerciseVolumes.filter { favoritesStore.favoriteIDs.contains($0.exercise.id) }
        }
    }

    private func weekRangeLabel(for date: Date) -> String {
        let start = calendar.startOfWeek(for: date) ?? date
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = strings.weekRangeDateFormat
        return strings.weekRangeLabel(base: formatter.string(from: start))
    }

    private var currentWeekLabel: String {
        let start = calendar.startOfWeek(for: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = strings.currentWeekDateFormat
        return strings.weekRangeLabel(base: formatter.string(from: start))
    }

    private func chartLabel(for date: Date, period: PartsChartPeriod) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        switch period {
        case .day:
            formatter.dateFormat = strings.dayChartDateFormat
            return formatter.string(from: date)
        case .week:
            let start = calendar.startOfWeek(for: date) ?? date
            formatter.dateFormat = strings.weekChartDateFormat
            return strings.weekRangeLabel(base: formatter.string(from: start))
        case .month:
            formatter.dateFormat = strings.monthChartDateFormat
            return formatter.string(from: date)
        }
    }

    private func chartMetricValue(from value: Double) -> Double {
        switch trackingType {
        case .weightReps:
            return weightUnit.displayValue(fromKg: value)
        case .repsOnly:
            return value
        case .durationOnly:
            return value / 60
        }
    }

    private func displayName(for exercise: ExerciseCatalog) -> String {
        exercise.displayName(isJapanese: isJapaneseLocale)
    }
}

enum PartsChartPeriod: CaseIterable {
    case day
    case week
    case month

    var title: String {
        let isJapanese = Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
        switch self {
        case .day: return isJapanese ? "日" : "Day"
        case .week: return isJapanese ? "週" : "Week"
        case .month: return isJapanese ? "月" : "Month"
        }
    }
}

enum PartsFilter: CaseIterable {
    case all
    case favorites

    var title: String {
        let isJapanese = Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
        switch self {
        case .all: return isJapanese ? "すべて" : "All"
        case .favorites: return isJapanese ? "お気に入り" : "Favorites"
        }
    }
}

private struct OverviewMuscleGroupStrings {
    let isJapanese: Bool

    var locale: Locale { isJapanese ? Locale(identifier: "ja_JP") : Locale(identifier: "en_US") }
    func totalMetricSectionTitle(trackingType: ExerciseTrackingType) -> String {
        switch trackingType {
        case .weightReps:
            return isJapanese ? "総ボリューム" : "Total Volume"
        case .repsOnly:
            return isJapanese ? "合計回数" : "Total Reps"
        case .durationOnly:
            return isJapanese ? "合計時間" : "Total Time"
        }
    }
    var periodPickerTitle: String { isJapanese ? "期間" : "Period" }
    var weeklyRecordsTitle: String { isJapanese ? "週ごとの記録" : "Weekly Records" }
    var viewAllTitle: String { isJapanese ? "すべて表示" : "View All" }
    var exerciseRecordsSectionTitle: String { isJapanese ? "種目ごとの記録" : "Exercises" }
    var filterPickerTitle: String { isJapanese ? "表示" : "Filter" }
    var noExerciseText: String { isJapanese ? "対象の種目がありません" : "No exercises found." }
    var weekRangeDateFormat: String { isJapanese ? "yyyy年MM月dd日" : "MMM d, yyyy" }
    var currentWeekDateFormat: String { isJapanese ? "M/d" : "MMM d" }
    var dayChartDateFormat: String { "M/d" }
    var weekChartDateFormat: String { isJapanese ? "M/d" : "MMM d" }
    var monthChartDateFormat: String { isJapanese ? "M月" : "MMM" }
    func weekRangeLabel(base: String) -> String {
        isJapanese ? "\(base)週" : "\(base) W"
    }
    func metricValueLabel(trackingType: ExerciseTrackingType, unit: String) -> String {
        switch trackingType {
        case .weightReps:
            return isJapanese ? "ボリューム(\(unit))" : "Volume (\(unit))"
        case .repsOnly:
            return isJapanese ? "回数(回)" : "Reps"
        case .durationOnly:
            return isJapanese ? "時間(分)" : "Time (min)"
        }
    }
    func metricAxisLabel(trackingType: ExerciseTrackingType, unit: String) -> String {
        switch trackingType {
        case .weightReps:
            return unit
        case .repsOnly:
            return isJapanese ? "回" : "reps"
        case .durationOnly:
            return isJapanese ? "分" : "min"
        }
    }
}
