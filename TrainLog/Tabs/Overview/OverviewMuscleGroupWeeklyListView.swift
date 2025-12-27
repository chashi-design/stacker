import SwiftUI

struct WeekListItem: Identifiable, Hashable {
    var id: Date { start }
    let start: Date
    let label: String
    let volume: Double
    let muscleGroup: String
    let displayName: String
}

// 部位ごとの週別記録一覧を表示する画面
struct OverviewMuscleGroupWeeklyListView: View {
    let title: String
    let items: [WeekListItem]
    let workouts: [Workout]
    let exercises: [ExerciseCatalog]

    @Environment(\.weightUnit) private var weightUnit
    private let locale = Locale(identifier: "ja_JP")
    @State private var navigationFeedbackTrigger = 0
    @State private var selectedWeekItem: WeekListItem?

    var body: some View {
        List {
            ForEach(items) { item in
                Button {
                    selectedWeekItem = item
                } label: {
                    HStack {
                        Text(item.label)
                            .font(.headline)
                        Spacer()
                        let parts = VolumeFormatter.volumeParts(from: item.volume, locale: locale, unit: weightUnit)
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .contentMargins(.top, 4, for: .scrollContent)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedWeekItem) { item in
            OverviewMuscleGroupWeekDetailView(
                weekStart: item.start,
                muscleGroup: item.muscleGroup,
                displayName: item.displayName,
                workouts: workouts,
                exercises: exercises
            )
        }
        .onChange(of: selectedWeekItem) { _, newValue in
            if newValue != nil {
                navigationFeedbackTrigger += 1
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: navigationFeedbackTrigger)
    }
}
