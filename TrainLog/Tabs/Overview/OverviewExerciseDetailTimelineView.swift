import SwiftUI

// MARK: - Exercise detail (timeline)

struct OverviewExerciseDetailView: View {
    let exercise: ExerciseCatalog
    let workouts: [Workout]

    @State private var chartPeriod: ExerciseChartPeriod = .day
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
                        barColor: MuscleGroupColor.color(for: exercise.muscleGroup)
                    )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }

            ForEach(sectionedDailyVolumes) { section in
                Section(section.monthLabel) {
                    ForEach(section.items) { item in
                        NavigationLink {
                            OverviewExerciseDayDetailView(
                                exerciseName: exercise.name,
                                date: item.date,
                                workouts: workouts
                            )
                        } label: {
                            HStack {
                                Text(dayLabel(for: item.date))
                                Spacer()
                                Text(VolumeFormatter.string(from: item.volume, locale: locale))
                                    .font(.headline)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            if sectionedDailyVolumes.isEmpty {
                Text("期間内の記録がありません")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
    }

    private var sectionedDailyVolumes: [DailyVolumeSection] {
        let days = OverviewMetrics.dailyVolumesAll(
            for: exercise.name,
            workouts: workouts,
            calendar: calendar
        )
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "yyyy年M月"

        let grouped = Dictionary(grouping: days) { day in
            formatter.string(from: day.date)
        }

        return grouped
            .map { key, values in
                DailyVolumeSection(
                    id: key,
                    monthLabel: key,
                    items: values.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.items.first?.date ?? Date.distantFuture > $1.items.first?.date ?? Date.distantFuture }
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
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
