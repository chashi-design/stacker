import SwiftUI

// 種目ごとの集計画面を表示する画面
struct OverviewExerciseSummaryView: View {
    let exercise: ExerciseCatalog
    let workouts: [Workout]

    @State private var chartPeriod: ExerciseChartPeriod = .day
    @State private var navigationFeedbackTrigger = 0
    @State private var selectedWeekItem: ExerciseWeekListItem?
    private let calendar = Calendar.appCurrent
    private let locale = Locale(identifier: "ja_JP")

    private var chartData: [(label: String, value: Double)] {
        let series = OverviewMetrics.exerciseChartSeries(
            for: exercise.name,
            workouts: workouts,
            period: chartPeriod,
            calendar: calendar
        )
        return series.map { point in
            (axisLabel(for: point.date, period: chartPeriod), point.volume)
        }
    }

    private var hasAnyHistory: Bool {
        workouts.contains { workout in
            workout.sets.contains { $0.exerciseName == exercise.name }
        }
    }

    private var weeklyListData: [ExerciseWeekListItem] {
        OverviewMetrics.weeklyExerciseVolumesAll(
            for: exercise.name,
            workouts: workouts,
            calendar: calendar
        )
        .map { point in
            let start = calendar.startOfWeek(for: point.date) ?? point.date
            return ExerciseWeekListItem(
                start: start,
                label: weekRangeLabel(for: start),
                volume: point.volume
            )
        }
    }

    var body: some View {
        List {
            if hasAnyHistory {
                Section("総ボリューム") {
                    Picker("期間", selection: $chartPeriod) {
                        ForEach(ExerciseChartPeriod.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .segmentedHaptic(trigger: chartPeriod)
                    .padding(.horizontal, 4)

                    ExerciseVolumeChart(
                        data: chartData,
                        barColor: MuscleGroupColor.color(for: exercise.muscleGroup),
                        animateOnAppear: true,
                        animateOnTrigger: true,
                        animationTrigger: chartPeriod.hashValue
                    )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }

            Section("週ごとの記録") {
                ForEach(weeklyListData) { item in
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
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if weeklyListData.isEmpty {
                    Text("期間内の記録がありません")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $selectedWeekItem) { item in
            OverviewExerciseWeekDetailView(
                weekStart: item.start,
                exerciseName: exercise.name,
                workouts: workouts
            )
        }
        .onChange(of: selectedWeekItem) { _, newValue in
            if newValue != nil {
                navigationFeedbackTrigger += 1
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: navigationFeedbackTrigger)
    }

    private func weekRangeLabel(for date: Date) -> String {
        let start = calendar.startOfWeek(for: date) ?? date
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "yyyy年MM月dd日"
        return "\(formatter.string(from: start))週"
    }

    private func axisLabel(for date: Date, period: ExerciseChartPeriod) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        switch period {
        case .day:
            formatter.dateFormat = "M/d"
        case .week:
            formatter.dateFormat = "M/d週"
        case .month:
            formatter.dateFormat = "M月"
        }
        return formatter.string(from: date)
    }
}

struct ExerciseWeekListItem: Identifiable, Hashable {
    var id: Date { start }
    let start: Date
    let label: String
    let volume: Double
}
