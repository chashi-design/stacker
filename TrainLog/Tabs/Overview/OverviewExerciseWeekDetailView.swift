import SwiftUI

// 種目の週詳細（週内7日分のセット一覧）を表示する画面
struct OverviewExerciseWeekDetailView: View {
    let weekStart: Date
    let exerciseName: String
    let workouts: [Workout]

    @Environment(\.weightUnit) private var weightUnit
    private let calendar = Calendar.appCurrent
    private let locale = Locale(identifier: "ja_JP")

    private var normalizedWeekStart: Date {
        calendar.startOfWeek(for: weekStart) ?? weekStart
    }

    private var dailySummaries: [ExerciseDaySummary] {
        (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: normalizedWeekStart) else { return nil }
            return makeSummary(for: day)
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(dailySummaries) { summary in
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dayLabel(for: summary.date))
                                .font(.headline)
                            if summary.sets.isEmpty {
                                Text("記録なし")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                let parts = VolumeFormatter.volumePartsWithFraction(from: summary.totalVolume, locale: locale, unit: weightUnit)
                                HStack(spacing: 4) {
                                    Text("\(summary.sets.count)セット (")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    ValueWithUnitText(
                                        value: parts.value,
                                        unit: " \(parts.unit))",
                                        valueFont: .subheadline,
                                        unitFont: .caption,
                                        valueColor: .secondary,
                                        unitColor: .secondary
                                    )
                                }
                            }
                        }
                        if !summary.sets.isEmpty {
                            ForEach(Array(summary.sets.enumerated()), id: \.element.id) { index, set in
                                HStack(spacing: 32) {
                                    Text("\(index + 1)セット")
                                    Spacer()
                                    if set.weight > 0 {
                                        let parts = VolumeFormatter.weightParts(from: set.weight, locale: locale, unit: weightUnit)
                                        ValueWithUnitText(
                                            value: parts.value,
                                            unit: parts.unit,
                                            valueFont: .subheadline,
                                            unitFont: .caption,
                                            valueColor: .secondary,
                                            unitColor: .secondary
                                        )
                                    }
                                    Text("\(set.reps)回")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .contentMargins(.top, 4, for: .scrollContent)
        .navigationTitle(weekRangeLabel(for: normalizedWeekStart))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func makeSummary(for date: Date) -> ExerciseDaySummary {
        let sets = OverviewMetrics.sets(
            for: exerciseName,
            on: date,
            workouts: workouts,
            calendar: calendar
        )
        let totalVolume = sets.reduce(0.0) { $0 + $1.volume }
        return ExerciseDaySummary(date: date, sets: sets, totalVolume: totalVolume)
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
}

struct ExerciseDaySummary: Identifiable {
    let id = UUID()
    let date: Date
    let sets: [ExerciseSet]
    let totalVolume: Double
}
