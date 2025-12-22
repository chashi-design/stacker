import Combine
import SwiftData
import SwiftUI

// 種目・重量・レップなどを入力し、一時的にドラフトへ保持する画面
struct LogView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel = LogViewModel()
    @StateObject private var favoritesStore = ExerciseFavoritesStore()
    @Query(sort: \Workout.date, order: .reverse) private var workoutsQuery: [Workout]
    private var workouts: [Workout] { workoutsQuery }
    @State private var isShowingExercisePicker = false
    @State private var pickerSelections: Set<String> = []
    @State private var editMode: EditMode = .inactive
    @State private var selectedEntriesForDeletion: Set<UUID> = []
    @State private var isShowingDeleteAlert = false
    @State private var navigationFeedbackTrigger = 0
    @State private var path: [LogRoute] = []

    private enum LogRoute: Hashable {
        case edit(UUID)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                calendarSection
                exerciseSection
            }
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: path) { oldValue, newValue in
                if newValue.count > oldValue.count {
                    navigationFeedbackTrigger += 1
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: navigationFeedbackTrigger)
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    hideKeyboard()
                }
            )
            .navigationTitle("メモ")
                .task {
                    await viewModel.loadExercises()
                    viewModel.syncDraftsForSelectedDate(context: context)
                }
            .sheet(isPresented: $isShowingExercisePicker) {
                ExercisePickerSheet(
                    exercises: viewModel.exercisesCatalog,
                    selections: $pickerSelections,
                    onCancel: {
                        pickerSelections.removeAll()
                        isShowingExercisePicker = false
                    },
                    onComplete: {
                        let ids = pickerSelections
                        for id in ids {
                            if let name = viewModel.exerciseName(forID: id) {
                                viewModel.appendExercise(name)
                            }
                        }
                        pickerSelections.removeAll()
                        isShowingExercisePicker = false
                    }
                )
                .environmentObject(favoritesStore)
            }
            .onChange(of: viewModel.selectedDate) { _, _ in
                viewModel.syncDraftsForSelectedDate(context: context)
            }
            .onReceive(viewModel.$draftRevision.dropFirst()) { _ in
                if !viewModel.isSyncingDrafts {
                    viewModel.saveWorkout(context: context)
                }
            }
            .onChange(of: editMode) { oldValue, newValue in
                if !newValue.isEditing {
                    selectedEntriesForDeletion.removeAll()
                }
            }
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if editMode.isEditing {
                        HapticButton {
                            isShowingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(selectedEntriesForDeletion.isEmpty)
                    } else {
                        HapticButton {
                            viewModel.selectedDate = LogDateHelper.normalized(Date())
                        } label: {
                            Text("今日")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !editMode.isEditing {
                        HapticButton {
                            preparePickerSelection()
                            isShowingExercisePicker = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .alert("選択した種目を削除しますか？", isPresented: $isShowingDeleteAlert) {
                Button("削除", role: .destructive) {
                    selectedEntriesForDeletion.forEach { id in
                        viewModel.removeDraftExercise(id: id)
                    }
                    selectedEntriesForDeletion.removeAll()
                    editMode = .inactive
                }
                Button("キャンセル", role: .cancel) {
                    isShowingDeleteAlert = false
                }
            } message: {
                Text("\(selectedEntriesForDeletion.count)件の種目を削除します。")
            }
            .navigationDestination(for: LogRoute.self) { route in
                switch route {
                case .edit(let id):
                    SetEditorView(viewModel: viewModel, exerciseID: id)
                }
            }
        }
    }

    private func preparePickerSelection() {
        // 初期選択はしない
    }

    private var workoutDots: [Date: [Color]] {
        let workoutsSnapshot = workouts
        let exercisesSnapshot = viewModel.exercisesCatalog
        var dots = WorkoutDotsBuilder.dotsByDay(
            workouts: workoutsSnapshot,
            exercises: exercisesSnapshot
        )

        let calendar = Calendar.appCurrent
        let selectedDay = calendar.startOfDay(for: viewModel.selectedDate)
        let draftGroups = Set(viewModel.draftExercises.map { entry in
            exercisesSnapshot.first(where: { $0.name == entry.exerciseName })?.muscleGroup ?? "other"
        })

        if draftGroups.isEmpty {
            dots[selectedDay] = nil
        } else {
            dots[selectedDay] = WorkoutDotsBuilder.colors(for: Array(draftGroups))
        }

        return dots
    }
    
    private func muscleColor(for name: String) -> Color {
        guard let exercise = viewModel.exercisesCatalog.first(where: { $0.name == name }) else {
            return .gray
        }
        return MuscleGroupColor.color(for: exercise.muscleGroup)
    }

    private var calendarSection: some View {
        LogCalendarSection(
            selectedDate: $viewModel.selectedDate,
            workoutDots: workoutDots
        )
    }

    private var exerciseSection: some View {
        Section("今回の種目") {
            if viewModel.draftExercises.isEmpty {
                Text("追加された種目はありません。＋から追加してください。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.draftExercises) { entry in
                    SwipeDeleteRow(label: "") {
                        viewModel.removeDraftExercise(id: entry.id)
                    } content: {
                        if editMode.isEditing {
                            HStack(spacing: 20) {
                                let isSelected = selectedEntriesForDeletion.contains(entry.id)
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(entry.exerciseName)
                                        .font(.headline)
                                    let weight = totalWeight(for: entry)
                                    Group {
                                        if entry.completedSetCount == 0 {
                                            Text("\(entry.completedSetCount)セット")
                                        } else {
                                            Text("\(entry.completedSetCount)セット (\(weight)kg)")
                                        }
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(for: entry.id)
                            }
                        } else {
                            NavigationLink(value: LogRoute.edit(entry.id)) {
                                HStack(spacing: 16) {
                                    Image(systemName: "circle.fill")
                                        .foregroundStyle(muscleColor(for: entry.exerciseName))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.exerciseName)
                                            .font(.headline)
                                        let weight = totalWeight(for: entry)
                                        Group {
                                            if entry.completedSetCount == 0 {
                                                Text("\(entry.completedSetCount)セット")
                                            } else {
                                                Text("\(entry.completedSetCount)セット (\(weight)kg)")
                                            }
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                        }
                    }
                }
                .onMove { indices, newOffset in
                    viewModel.moveDraftExercises(from: indices, to: newOffset)
                }
            }
        }
    }

    private func toggleSelection(for id: UUID) {
        if selectedEntriesForDeletion.contains(id) {
            selectedEntriesForDeletion.remove(id)
        } else {
            selectedEntriesForDeletion.insert(id)
        }
    }

    private func totalWeight(for entry: DraftExerciseEntry) -> Int {
        entry.sets.compactMap { set in
            guard let weight = Int(set.weightText), let reps = Int(set.repsText) else { return nil }
            return weight * reps
        }
        .reduce(0, +)
    }
}

#Preview {
    LogView()
}

private extension EditMode {
    var isEditing: Bool { self == .active }
}

enum WorkoutDotsBuilder {
    static func dotsByDay(
        workouts: [Workout],
        exercises: [ExerciseCatalog]
    ) -> [Date: [Color]] {
        let calendar = Calendar.current
        let exerciseLookup = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0.muscleGroup) })

        var buckets: [Date: Set<String>] = [:]

        for workout in workouts {
            let day = calendar.startOfDay(for: workout.date)
            var groups = workout.sets.compactMap { set in
                exerciseLookup[set.exerciseName]
            }
            // セット数0でもドットを表示するため、空の場合はデフォルトグループを付与
            if groups.isEmpty {
                groups = ["other"]
            }

            var current = buckets[day, default: []]
            current.formUnion(groups)
            buckets[day] = current
        }

        return buckets.mapValues { groups in
            colors(for: Array(groups))
        }
    }

    static func colors(for groups: [String]) -> [Color] {
        let set = Set(groups)
        let ordered = muscleOrder.compactMap { key in
            set.contains(key) ? MuscleGroupColor.color(for: key) : nil
        }
        let remaining = set
            .filter { !muscleOrder.contains($0) }
            .sorted()
        return ordered + remaining.map { MuscleGroupColor.color(for: $0) }
    }

    private static var muscleOrder: [String] {
        ["chest", "shoulders", "arms", "back", "legs", "abs"]
    }
}
