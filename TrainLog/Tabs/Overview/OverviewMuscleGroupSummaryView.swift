import SwiftUI

// 部位別の集計画面を表示する画面
struct OverviewMuscleGroupSummaryView: View {
    let muscleGroup: String
    let displayName: String
    let exercises: [ExerciseCatalog]
    let workouts: [Workout]
    @EnvironmentObject private var favoritesStore: ExerciseFavoritesStore

    @State private var chartPeriod: PartsChartPeriod = .day
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
    private let locale = Locale(identifier: "ja_JP")

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
            weeks: 8
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
                days: 7
            )
        case .week:
            return OverviewMetrics.weeklyMuscleGroupVolumes(
                muscleGroup: muscleGroup,
                workouts: workouts,
                exercises: exercises,
                calendar: calendar,
                weeks: 5
            )
        case .month:
            return OverviewMetrics.monthlyMuscleGroupVolumes(
                muscleGroup: muscleGroup,
                workouts: workouts,
                exercises: exercises,
                calendar: calendar,
                months: 6
            )
        }
    }

    private var chartData: [(label: String, value: Double)] {
        chartSeries
            .sorted { $0.date < $1.date }
            .map { (chartLabel(for: $0.date, period: chartPeriod), $0.volume) }
    }

    private var recentWeeklyListData: [WeekListItem] {
        OverviewMetrics.weeklyMuscleGroupVolumesAll(
            muscleGroup: muscleGroup,
            workouts: workouts,
            exercises: exercises,
            calendar: calendar
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
            calendar: calendar
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
            Section("総ボリューム") {
                Picker("期間", selection: $chartPeriod) {
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
                    animationTrigger: chartPeriod.hashValue
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
                                let parts = VolumeFormatter.volumePartsWithFraction(from: item.volume, locale: locale)
                                ValueWithUnitText(
                                    value: parts.value,
                                    unit: " \(parts.unit)",
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
                        Text("週ごとの記録")
                        Spacer()
                        Button {
                            selectedWeeklyListItem = WeeklyListDestination()
                        } label: {
                            Text("すべて表示")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("種目ごとの記録") {
                Picker("表示", selection: $filter) {
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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.exercise.name)
                                    .font(.headline)
                                Text(currentWeekLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                            }
                            Spacer()
                            let parts = VolumeFormatter.volumePartsWithFraction(from: item.volume, locale: locale)
                            ValueWithUnitText(
                                value: parts.value,
                                unit: " \(parts.unit)",
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
                    Text("対象の種目がありません")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.large)
        .listSectionSpacing(10)
        .navigationDestination(item: $selectedWeekItem) { item in
            OverviewMuscleGroupWeekDetailView(
                weekStart: item.start,
                muscleGroup: item.muscleGroup,
                displayName: item.displayName,
                workouts: workouts,
                exercises: exercises
            )
        }
        .navigationDestination(item: $selectedWeeklyListItem) { _ in
            OverviewMuscleGroupWeeklyListView(
                title: "週ごとの記録",
                items: weeklyListData,
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
        formatter.dateFormat = "yyyy年MM月dd日"
        return "\(formatter.string(from: start))週"
    }

    private var currentWeekLabel: String {
        let start = calendar.startOfWeek(for: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: start))週"
    }

    private func chartLabel(for date: Date, period: PartsChartPeriod) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        switch period {
        case .day:
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        case .week:
            let start = calendar.startOfWeek(for: date) ?? date
            formatter.dateFormat = "M/d"
            return "\(formatter.string(from: start))週"
        case .month:
            formatter.dateFormat = "M月"
            return formatter.string(from: date)
        }
    }
}

enum PartsChartPeriod: CaseIterable {
    case day
    case week
    case month

    var title: String {
        switch self {
        case .day: return "日"
        case .week: return "週"
        case .month: return "月"
        }
    }
}

enum PartsFilter: CaseIterable {
    case all
    case favorites

    var title: String {
        switch self {
        case .all: return "すべて"
        case .favorites: return "お気に入り"
        }
    }
}
