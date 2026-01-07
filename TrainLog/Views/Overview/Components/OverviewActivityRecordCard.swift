import SwiftUI

// Overviewの活動記録カード
struct OverviewActivityRecordCard: View {
    let workouts: [Workout]
    let calendar: Calendar

    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private var strings: OverviewActivityRecordCardStrings {
        OverviewActivityRecordCardStrings(isJapanese: isJapaneseLocale)
    }

    private var currentYear: Int {
        calendar.component(.year, from: Date())
    }

    private var activityByDay: [Date: Int] {
        guard let range = ActivityRecordMetrics.yearRange(year: currentYear, calendar: calendar) else { return [:] }
        return ActivityRecordMetrics.dailyExerciseCounts(
            workouts: workouts,
            calendar: calendar,
            range: range
        )
    }

    private var yearLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = isJapaneseLocale ? "yyyy年" : "yyyy"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            HStack(spacing: 4) {
                Text(strings.title)
                    .font(.subheadline .weight(.semibold))
                    .foregroundStyle(.blue)
                Spacer()
                Text(yearLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .imageScale(.small)
                    .font(.system(size: 17, weight: .semibold))
            }

            ActivityYearHeatmapView(
                year: currentYear,
                calendar: calendar,
                activityByDay: activityByDay,
                cellSize: 16,
                spacing: 4,
                cornerRadius: 4
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }
}

private struct OverviewActivityRecordCardStrings {
    let isJapanese: Bool

    var title: String { isJapanese ? "活動記録" : "Activity Record" }
}

#Preview {
    OverviewActivityRecordCard(
        workouts: [],
        calendar: .appCurrent
    )
    .padding()
}
