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
    @State private var selectedExerciseForEdit: DraftExerciseEntry?
    @State private var pickerSelections: Set<String> = []
    @State private var editMode: EditMode = .inactive
    @State private var selectedEntriesForDeletion: Set<UUID> = []
    @State private var isShowingDeleteAlert = false

    var body: some View {
        NavigationStack {
            Form {
                calendarSection
                exerciseSection
            }
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    hideKeyboard()
                }
            )
            .navigationTitle("トレーニングログ")
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
            .sheet(item: $selectedExerciseForEdit) { entry in
                SetEditorSheet(viewModel: viewModel, exerciseID: entry.id)
            }
            .onChange(of: viewModel.selectedDate) { _, _ in
                viewModel.syncDraftsForSelectedDate(context: context)
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
                        Button {
                            isShowingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(selectedEntriesForDeletion.isEmpty)
                    } else {
                        Button("今日") {
                            viewModel.selectedDate = LogDateHelper.normalized(Date())
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if editMode.isEditing {
                        Button {
                            editMode = .inactive
                        } label: {
                            Label("完了", systemImage: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            editMode = .active
                        } label: {
                            Text("編集")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !editMode.isEditing {
                        Button {
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
        }
    }

    private func preparePickerSelection() {
        if pickerSelections.isEmpty, let first = viewModel.exercisesCatalog.first {
            pickerSelections = [first.id]
        }
    }

    private var workoutDots: [Date: [Color]] {
        let workoutsSnapshot = workouts
        let exercisesSnapshot = viewModel.exercisesCatalog
        let dots = WorkoutDotsBuilder.dotsByDay(
            workouts: workoutsSnapshot,
            exercises: exercisesSnapshot
        )
        return dots
    }
    
    private func muscleColor(for name: String) -> Color {
        guard let exercise = viewModel.exercisesCatalog.first(where: { $0.name == name }) else {
            return .gray
        }
        switch exercise.muscleGroup {
        case "chest": return .red
        case "shoulders": return .orange
        case "arms": return .yellow
        case "back": return .green
        case "legs": return .teal
        case "abs": return .indigo
        default: return .gray
        }
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
                        HStack (spacing: 16){
                            if editMode.isEditing {
                                let isSelected = selectedEntriesForDeletion.contains(entry.id)
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                            } else {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(muscleColor(for: entry.exerciseName))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.exerciseName)
                                    .font(.headline)
                                let weight = totalWeight(for: entry)
                                Text("\(entry.completedSetCount)セット (\(weight)kg)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !editMode.isEditing {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if editMode.isEditing {
                                toggleSelection(for: entry.id)
                            } else {
                                selectedExerciseForEdit = entry
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
        entry.sets.compactMap { Int($0.weightText) }.reduce(0, +)
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
            muscleOrder.compactMap { key in
                groups.contains(key) ? groupColor[key] : nil
            }
            + groups
                .filter { !muscleOrder.contains($0) }
                .compactMap { groupColor[$0] ?? groupColor["other"] }
        }
    }

    private static var groupColor: [String: Color] {
        [
            "chest": .red,
            "shoulders": .orange,
            "arms": .yellow,
            "back": .green,
            "legs": .teal,
            "abs": .indigo,
            "other": .gray
        ]
    }

    private static var muscleOrder: [String] {
        ["chest", "shoulders", "arms", "back", "legs", "abs"]
    }
}
