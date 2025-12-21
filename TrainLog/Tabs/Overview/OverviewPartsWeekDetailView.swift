import SwiftUI

// 週ごとの詳細（曜日別のセット/ボリューム内訳）
struct OverviewPartsWeekDetailView: View {
    let weekStart: Date
    let muscleGroup: String
    let displayName: String
    let workouts: [Workout]
    let exercises: [ExerciseCatalog]

    private let calendar = Calendar.appCurrent
    private let locale = Locale(identifier: "ja_JP")

    private var normalizedWeekStart: Date {
        calendar.startOfWeek(for: weekStart) ?? weekStart
    }

    private var dailySummaries: [DaySummary] {
        (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: normalizedWeekStart) else { return nil }
            return makeSummary(for: day)
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(dailySummaries) { summary in
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading) {
                            Text(dayLabel(for: summary.date))
                                .font(.headline)
                            HStack {
                                if summary.totalSets > 0 {
                                    Text("\(summary.totalSets)セット")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if summary.totalVolume > 0 {
                                    Text("(\(VolumeFormatter.string(from: summary.totalVolume, locale: locale)))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if summary.exercises.isEmpty {
                            Text("記録なし")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(summary.exercises) { exercise in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(exercise.name)
                                        .font(.subheadline.weight(.semibold))
                                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                                        HStack(spacing: 32) {
                                            Text("\(index + 1)セット")
                                            Spacer()
                                            if set.weight > 0 {
                                                Text("\(Int(set.weight))kg")
                                            }
                                            Text("\(set.reps)回")
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(weekRangeLabel(for: normalizedWeekStart))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func makeSummary(for date: Date) -> DaySummary {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start

        var exercisesSummary: [String: [ExerciseSet]] = [:]
        var totals = (sets: 0, reps: 0, volume: 0.0)

        for workout in workouts where workout.date >= start && workout.date < end {
            for set in workout.sets {
                let group = OverviewMetrics.lookupMuscleGroup(for: set.exerciseName, exercises: exercises)
                if muscleGroup != "other" {
                    guard group == muscleGroup else { continue }
                } else {
                    guard group == "other" else { continue }
                }
                exercisesSummary[set.exerciseName, default: []].append(set)
                totals.sets += 1
                totals.reps += set.reps
                totals.volume += set.volume
            }
        }

        let exerciseBreakdowns = exercisesSummary
            .map { key, value in
                let orderedSets = value.sorted { $0.createdAt < $1.createdAt }
                let totalVolume = orderedSets.reduce(0.0) { $0 + $1.volume }
                return ExerciseBreakdown(name: key, sets: orderedSets, totalVolume: totalVolume)
            }
            .sorted { $0.totalVolume > $1.totalVolume }

        return DaySummary(
            date: start,
            totalSets: totals.sets,
            totalVolume: totals.volume,
            totalReps: totals.reps,
            exercises: exerciseBreakdowns
        )
    }

    private func weekRangeLabel(for date: Date) -> String {
        let start = calendar.startOfWeek(for: date) ?? date
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "yyyy年MM月dd日"
        return "\(formatter.string(from: start))週"
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "yyyy年MM月dd日 E曜日"
        return formatter.string(from: date)
    }

    struct DaySummary: Identifiable {
        let id = UUID()
        let date: Date
        let totalSets: Int
        let totalVolume: Double
        let totalReps: Int
        let exercises: [ExerciseBreakdown]
    }

    struct ExerciseBreakdown: Identifiable {
        let id = UUID()
        let name: String
        let sets: [ExerciseSet]
        let totalVolume: Double
    }
}
