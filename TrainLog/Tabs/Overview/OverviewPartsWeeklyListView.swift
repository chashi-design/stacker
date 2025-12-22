import SwiftUI

struct WeekListItem: Identifiable, Hashable {
    var id: Date { start }
    let start: Date
    let label: String
    let volume: Double
    let muscleGroup: String
    let displayName: String
}

struct OverviewPartsWeeklyListView: View {
    let title: String
    let items: [WeekListItem]
    let workouts: [Workout]
    let exercises: [ExerciseCatalog]

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
                        Spacer()
                        Text(VolumeFormatter.string(from: item.volume, locale: locale))
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedWeekItem) { item in
            OverviewPartsWeekDetailView(
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
