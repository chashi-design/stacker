import SwiftUI

struct OverviewPartsView: View {
    let muscleGroup: String
    let displayName: String
    let exercises: [ExerciseCatalog]
    let workouts: [Workout]

    @State private var chartPeriod: PartsChartPeriod = .day
    @State private var filter: PartsFilter = .all
    @State private var navigationFeedbackTrigger = 0
    @State private var exerciseFeedbackTrigger = 0
    @State private var selectedWeekStart: Date?
    @State private var selectedExerciseID: String?
    @State private var selectedWeeklyList: Bool?
    private let calendar = Calendar.appCurrent
    private let locale = Locale(identifier: "ja_JP")

    private var exerciseVolumes: [ExerciseVolume] {
        OverviewMetrics.exerciseVolumesForCurrentMonth(
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
                    barColor: MuscleGroupColor.color(for: muscleGroup)
                )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if !recentWeeklyListData.isEmpty {
                Section {
                    ForEach(recentWeeklyListData) { item in
                        NavigationLink(tag: item.start, selection: $selectedWeekStart) {
                            OverviewPartsWeekDetailView(
                                weekStart: item.start,
                                muscleGroup: item.muscleGroup,
                                displayName: item.displayName,
                                workouts: workouts,
                                exercises: exercises
                            )
                        } label: {
                            HStack {
                                Text(item.label)
                                Spacer()
                                Text(VolumeFormatter.string(from: item.volume, locale: locale))
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                    }
                } header: {
                    HStack {
                        Text("週間記録")
                        Spacer()
                        NavigationLink(tag: true, selection: $selectedWeeklyList) {
                            OverviewPartsWeeklyListView(
                                title: "週間記録",
                                items: weeklyListData,
                                workouts: workouts,
                                exercises: exercises
                            )
                        } label: {
                            Text("すべて表示")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                        }
                        .contentShape(Rectangle())
                    }
                }
            }

            Section("種目") {
                Picker("表示", selection: $filter) {
                    ForEach(PartsFilter.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .segmentedHaptic(trigger: filter)
                ForEach(filteredExercises, id: \.exercise.id) { item in
                    NavigationLink(tag: item.exercise.id, selection: $selectedExerciseID) {
                        OverviewExerciseDetailView(
                            exercise: item.exercise,
                            workouts: workouts
                        )
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.exercise.name)
                                    .font(.headline)
                                Text("累計")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(VolumeFormatter.string(from: item.volume, locale: locale))
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
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
        .onChange(of: selectedWeekStart) { _, newValue in
            if newValue != nil {
                navigationFeedbackTrigger += 1
            }
        }
        .onChange(of: selectedExerciseID) { _, newValue in
            if newValue != nil {
                exerciseFeedbackTrigger += 1
            }
        }
        .onChange(of: selectedWeeklyList) { _, newValue in
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
        case .completed:
            return exerciseVolumes.filter { $0.volume > 0 }
        }
    }

    private func weekRangeLabel(for date: Date) -> String {
        let start = calendar.startOfWeek(for: date) ?? date
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "yyyy年MM月dd日"
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
    case completed

    var title: String {
        switch self {
        case .all: return "すべて"
        case .completed: return "実施済み"
        }
    }
}
