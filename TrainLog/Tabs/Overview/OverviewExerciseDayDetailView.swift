import SwiftUI

// MARK: - Day detail

struct OverviewExerciseDayDetailView: View {
    let exerciseName: String
    let date: Date
    let workouts: [Workout]

    private let calendar = Calendar.appCurrent
    private let locale = Locale(identifier: "ja_JP")

    private var sets: [ExerciseSet] {
        OverviewMetrics.sets(
            for: exerciseName,
            on: date,
            workouts: workouts,
            calendar: calendar
        )
    }

    var body: some View {
        List {
            if sets.isEmpty {
                Text("この日の記録はありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    HStack(spacing: 32) {
                        Text("\(index + 1)セット")
                        Spacer()
                        Text(VolumeFormatter.weightString(from: set.weight, locale: locale))
                            .fontWeight(.semibold)
                        Text("\(set.reps)回")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .navigationTitle(dayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}
