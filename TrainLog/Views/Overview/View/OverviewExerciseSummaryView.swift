import SwiftUI

// 種目ごとの集計画面を表示する画面
struct OverviewExerciseSummaryView: View {
    let exercise: ExerciseCatalog
    let workouts: [Workout]

    @Environment(\.weightUnit) private var weightUnit
    @State private var chartPeriod: ExerciseChartPeriod = .week
    @State private var navigationFeedbackTrigger = 0
    @State private var selectedWeekItem: ExerciseWeekListItem?
    private let calendar = Calendar.appCurrent
    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }
    private var strings: OverviewExerciseStrings {
        OverviewExerciseStrings(isJapanese: isJapaneseLocale)
    }
    private var locale: Locale { strings.locale }
    private var displayName: String {
        exercise.displayName(isJapanese: isJapaneseLocale)
    }
    private var trackingType: ExerciseTrackingType {
        exercise.trackingType
    }

    private var chartData: [(label: String, value: Double)] {
        let series = OverviewMetrics.exerciseChartSeries(
            for: exercise.id,
            workouts: workouts,
            period: chartPeriod,
            calendar: calendar,
            trackingType: trackingType
        )
        return series.map { point in
            (axisLabel(for: point.date, period: chartPeriod), chartMetricValue(from: point.volume))
        }
    }

    private var hasAnyHistory: Bool {
        workouts.contains { workout in
            workout.sets.contains { OverviewMetrics.matches(set: $0, exerciseId: exercise.id) }
        }
    }

    private var weeklyListData: [ExerciseWeekListItem] {
        OverviewMetrics.weeklyExerciseVolumesAll(
            for: exercise.id,
            workouts: workouts,
            calendar: calendar,
            trackingType: trackingType
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
                Section(strings.totalMetricSectionTitle(trackingType: trackingType)) {
                    Picker(strings.periodPickerTitle, selection: $chartPeriod) {
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
                        animationTrigger: chartPeriod.hashValue,
                        yValueLabel: strings.metricValueLabel(trackingType: trackingType, unit: weightUnit.unitLabel),
                        yAxisLabel: strings.metricAxisLabel(trackingType: trackingType, unit: weightUnit.unitLabel)
                    )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }

            Section(strings.weeklyRecordsTitle) {
                ForEach(weeklyListData) { item in
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
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if weeklyListData.isEmpty {
                    Text(strings.noHistoryText)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(displayName)
                    .font(.headline)
            }
        }
        .navigationDestination(item: $selectedWeekItem) { item in
            OverviewExerciseWeekDetailView(
                weekStart: item.start,
                exerciseId: exercise.id,
                displayName: displayName,
                trackingType: trackingType,
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
        formatter.dateFormat = strings.weekRangeDateFormat
        return strings.weekRangeLabel(base: formatter.string(from: start))
    }

    private func axisLabel(for date: Date, period: ExerciseChartPeriod) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        switch period {
        case .day:
            formatter.dateFormat = strings.dayAxisDateFormat
        case .week:
            formatter.dateFormat = strings.weekAxisDateFormat
        case .month:
            formatter.dateFormat = strings.monthAxisDateFormat
        }
        let base = formatter.string(from: date)
        return period == .week ? strings.weekAxisLabel(base: base) : base
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
}

struct ExerciseWeekListItem: Identifiable, Hashable {
    var id: Date { start }
    let start: Date
    let label: String
    let volume: Double
}

private struct OverviewExerciseStrings {
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
    var noHistoryText: String { isJapanese ? "期間内の記録がありません" : "No records in this period." }
    var weekRangeDateFormat: String { isJapanese ? "yyyy年MM月dd日" : "MMM d, yyyy" }
    var dayAxisDateFormat: String { "M/d" }
    var weekAxisDateFormat: String { isJapanese ? "M/d" : "MMM d" }
    var monthAxisDateFormat: String { isJapanese ? "M月" : "MMM" }
    func weekRangeLabel(base: String) -> String {
        isJapanese ? "\(base)週" : "Week of \(base)"
    }
    func weekAxisLabel(base: String) -> String {
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
