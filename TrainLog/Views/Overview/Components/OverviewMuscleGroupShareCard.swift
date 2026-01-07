import Charts
import SwiftUI

// Overviewの種目割合カード
struct OverviewMuscleGroupShareCard: View {
    let workouts: [Workout]
    let exercises: [ExerciseCatalog]
    let isLoadingExercises: Bool
    let calendar: Calendar

    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private var strings: OverviewMuscleGroupShareStrings {
        OverviewMuscleGroupShareStrings(isJapanese: isJapaneseLocale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            HStack(spacing: 4) {
                Text(strings.title)
                    .font(.subheadline .weight(.semibold))
                    .foregroundStyle(.blue)
                Spacer()
                Text(currentMonthLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .imageScale(.small)
                    .font(.system(size: 17, weight: .semibold))
            }

            if isLoadingExercises {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if shareItems.isEmpty {
                Text(strings.noDataText)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(shareItems) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 8, height: 8)
                                Text(item.label)
                                    .font(.subheadline)
                                Spacer()
                                Text(percentText(for: item.count))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Chart {
                        ForEach(shareItems) { item in
                            SectorMark(
                                angle: .value(strings.chartValueLabel, item.count),
                                innerRadius: .ratio(0.7),
                                angularInset: 2
                            )
                            .foregroundStyle(item.color)
                            .cornerRadius(3)
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(width: 80, height: 80)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }

    private var shareItems: [MuscleGroupShareItem] {
        guard let range = monthRange else { return [] }
        let exerciseLookup = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.muscleGroup) })
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

    private var totalCount: Int {
        shareItems.reduce(0) { $0 + $1.count }
    }

    private var monthRange: DateInterval? {
        calendar.dateInterval(of: .month, for: Date())
    }

    private var currentMonthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = isJapaneseLocale ? "yyyy年M月" : "MMM yyyy"
        return formatter.string(from: Date())
    }

    private func percentText(for count: Int) -> String {
        guard totalCount > 0 else { return "0%" }
        let ratio = Double(count) / Double(totalCount)
        return ratio.formatted(.percent.precision(.fractionLength(0)))
    }

}

private struct MuscleGroupShareItem: Identifiable {
    let muscleGroup: String
    let count: Int
    var id: String { muscleGroup }
    var label: String { MuscleGroupLabel.label(for: muscleGroup) }
    var color: Color { MuscleGroupColor.color(for: muscleGroup) }
}

private struct OverviewMuscleGroupShareStrings {
    let isJapanese: Bool

    var title: String { isJapanese ? "種目割合" : "Exercise Share" }
    var noDataText: String { isJapanese ? "データがありません" : "No data available." }
    var chartValueLabel: String { isJapanese ? "種目数" : "Exercises" }
}

#Preview {
    OverviewMuscleGroupShareCard(
        workouts: [],
        exercises: [],
        isLoadingExercises: false,
        calendar: .appCurrent
    )
    .padding()
}
