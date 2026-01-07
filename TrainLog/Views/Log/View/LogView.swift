import Combine
import SwiftData
import SwiftUI

// 種目・重量・レップなどを入力し、一時的にドラフトへ保持する画面
struct LogView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel = LogViewModel()
    @EnvironmentObject private var favoritesStore: ExerciseFavoritesStore
    @Environment(\.weightUnit) private var weightUnit
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Workout.date, order: .reverse) private var workoutsQuery: [Workout]
    private var workouts: [Workout] { workoutsQuery }
    @State private var isShowingExercisePicker = false
    @State private var pickerSelections: Set<String> = []
    @State private var editMode: EditMode = .inactive
    @State private var selectedEntriesForDeletion: Set<UUID> = []
    @State private var isShowingDeleteAlert = false
    @State private var navigationFeedbackTrigger = 0
    @State private var path: [LogRoute] = []

    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }
    private var strings: LogStrings {
        LogStrings(isJapanese: isJapaneseLocale)
    }

    private enum LogRoute: Hashable {
        case edit(UUID)
    }

    private var selectedDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = strings.locale
        formatter.dateFormat = strings.selectedDateFormat
        return strings.selectedDateTitle(dateText: formatter.string(from: viewModel.selectedDate))
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
            .navigationTitle(strings.navigationTitle)
                .task {
                    await viewModel.loadExercises()
                    viewModel.syncDraftsForSelectedDate(context: context, unit: weightUnit)
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
                            viewModel.appendExercise(id)
                        }
                        pickerSelections.removeAll()
                        isShowingExercisePicker = false
                    }
                )
                .environmentObject(favoritesStore)
            }
            .onChange(of: viewModel.selectedDate) { _, _ in
                viewModel.syncDraftsForSelectedDate(context: context, unit: weightUnit)
            }
            .onChange(of: weightUnit) { _, _ in
                viewModel.syncDraftsForSelectedDate(context: context, unit: weightUnit)
            }
            .onReceive(viewModel.$draftRevision.dropFirst()) { _ in
                if !viewModel.isSyncingDrafts {
                    viewModel.saveWorkout(context: context, unit: weightUnit)
                }
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .background && !viewModel.isSyncingDrafts {
                    viewModel.saveWorkout(context: context, unit: weightUnit)
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
                                .foregroundStyle(.primary)
                        }
                        .disabled(selectedEntriesForDeletion.isEmpty)
                        .tint(.primary)
                    } else {
                        HapticButton {
                            viewModel.selectedDate = LogDateHelper.normalized(Date())
                        } label: {
                            Text(strings.todayLabel)
                                .foregroundStyle(.primary)
                        }
                        .tint(.primary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !editMode.isEditing {
                        HapticButton {
                            preparePickerSelection()
                            isShowingExercisePicker = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.primary)
                        }
                        .tint(.primary)
                    }
                }
            }
            .alert(strings.deleteAlertTitle, isPresented: $isShowingDeleteAlert) {
                Button(strings.deleteActionTitle, role: .destructive) {
                    selectedEntriesForDeletion.forEach { id in
                        viewModel.removeDraftExercise(id: id)
                    }
                    selectedEntriesForDeletion.removeAll()
                    editMode = .inactive
                }
                Button(strings.cancelActionTitle, role: .cancel) {
                    isShowingDeleteAlert = false
                }
            } message: {
                Text(strings.deleteAlertMessage(count: selectedEntriesForDeletion.count))
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
            exercisesSnapshot.first(where: { $0.id == entry.exerciseId })?.muscleGroup ?? "other"
        })

        if draftGroups.isEmpty {
            dots[selectedDay] = nil
        } else {
            dots[selectedDay] = WorkoutDotsBuilder.colors(for: Array(draftGroups))
        }

        return dots
    }
    
    private func muscleColor(for id: String) -> Color {
        guard let exercise = viewModel.exercisesCatalog.first(where: { $0.id == id }) else {
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
        Section(selectedDateTitle) {
            if viewModel.draftExercises.isEmpty {
                Text(strings.emptyStateMessage)
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
                                    Text(displayName(for: entry.exerciseId))
                                        .font(.headline)
                                    Text(summaryText(for: entry))
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
                                        .foregroundStyle(muscleColor(for: entry.exerciseId))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(displayName(for: entry.exerciseId))
                                            .font(.headline)
                                        Text(summaryText(for: entry))
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

    private func totalWeight(for entry: DraftExerciseEntry, unit: WeightUnit) -> Double {
        entry.sets.compactMap { set in
            guard let weight = Double(set.weightText), let reps = Int(set.repsText) else { return nil }
            let weightKg = unit.kgValue(fromDisplay: weight)
            return weightKg * Double(reps)
        }
        .reduce(0, +)
    }

    private func formattedWeight(_ weight: Double) -> String {
        weightUnit.formattedValue(
            fromKg: weight,
            locale: Locale.current,
            maximumFractionDigits: 3
        )
    }

    private func formattedDuration(_ seconds: Double) -> String {
        VolumeFormatter.durationString(from: seconds)
    }

    private func totalReps(for entry: DraftExerciseEntry) -> Int {
        entry.sets.compactMap { Int($0.repsText) }.reduce(0, +)
    }

    private func totalDurationSeconds(for entry: DraftExerciseEntry) -> Double {
        entry.sets.compactMap { DraftSetRow.durationSeconds(from: $0.durationText) }.reduce(0, +)
    }

    private func summaryText(for entry: DraftExerciseEntry) -> String {
        let trackingType = viewModel.trackingType(for: entry.exerciseId)
        let completed = entry.completedSetCount(trackingType: trackingType)
        guard completed > 0 else { return strings.setCountText(completed) }
        switch trackingType {
        case .weightReps:
            let weight = formattedWeight(totalWeight(for: entry, unit: weightUnit))
            return strings.setCountWithWeightText(completed, weight: weight, unit: weightUnit.unitLabel)
        case .repsOnly:
            let reps = totalReps(for: entry)
            return strings.setCountWithRepsText(completed, reps: reps)
        case .durationOnly:
            let duration = formattedDuration(totalDurationSeconds(for: entry))
            return strings.setCountWithDurationText(completed, duration: duration)
        }
    }

    private func displayName(for exerciseId: String) -> String {
        viewModel.displayName(for: exerciseId, isJapanese: isJapaneseLocale)
    }
}

private struct LogStrings {
    let isJapanese: Bool

    var navigationTitle: String { isJapanese ? "記録" : "Records" }
    var todayLabel: String { isJapanese ? "今日" : "Today" }
    var deleteAlertTitle: String { isJapanese ? "選択した種目を削除しますか？" : "Delete selected exercises?" }
    var deleteActionTitle: String { isJapanese ? "削除" : "Delete" }
    var cancelActionTitle: String { isJapanese ? "キャンセル" : "Cancel" }
    var emptyStateMessage: String {
        isJapanese
            ? "まだ種目が追加されていません。\n右上の \"＋\" から追加してください。"
            : "No exercises yet.\nTap the + in the top right to add."
    }
    var locale: Locale { isJapanese ? Locale(identifier: "ja_JP") : Locale(identifier: "en_US") }
    var selectedDateFormat: String { isJapanese ? "MM月dd日" : "MMM d" }
    func selectedDateTitle(dateText: String) -> String {
        isJapanese ? "\(dateText)のトレーニング種目" : "Exercises on \(dateText)"
    }
    func deleteAlertMessage(count: Int) -> String {
        isJapanese ? "\(count)件の種目を削除します。" : "Delete \(count) exercises."
    }
    func setCountText(_ count: Int) -> String {
        isJapanese ? "\(count)セット" : "\(count) sets"
    }
    func setCountWithWeightText(_ count: Int, weight: String, unit: String) -> String {
        isJapanese ? "\(count)セット (\(weight)\(unit))" : "\(count) sets (\(weight)\(unit))"
    }
    func setCountWithRepsText(_ count: Int, reps: Int) -> String {
        isJapanese ? "\(count)セット (\(reps)回)" : "\(count) sets (\(reps) reps)"
    }
    func setCountWithDurationText(_ count: Int, duration: String) -> String {
        isJapanese ? "\(count)セット (\(duration))" : "\(count) sets (\(duration))"
    }
}

#Preview {
    LogView()
        .environmentObject(ExerciseFavoritesStore())
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
        let exerciseLookup = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.muscleGroup) })

        var buckets: [Date: Set<String>] = [:]

        for workout in workouts {
            let day = calendar.startOfDay(for: workout.date)
            var groups: [String] = workout.sets.compactMap { exerciseLookup[$0.exerciseId] }
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
        ["chest", "shoulders", "arms", "back", "legs", "abs", "cardio"]
    }
}
