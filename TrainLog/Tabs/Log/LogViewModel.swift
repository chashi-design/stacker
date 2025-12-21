import Combine
import SwiftData
import SwiftUI

@MainActor
final class LogViewModel: ObservableObject {
    @Published var selectedDate = LogDateHelper.normalized(Date())
    @Published var exercisesCatalog: [ExerciseCatalog] = []
    @Published var isLoadingExercises = true
    @Published var exerciseLoadFailed = false
    @Published var draftExercises: [DraftExerciseEntry] = []
    @Published private(set) var draftRevision: Int = 0
    private(set) var isSyncingDrafts = false

    private var draftsCache: [Date: [DraftExerciseEntry]] = [:]
    private var lastSyncedDate: Date?

    func loadExercises() async {
        isLoadingExercises = true
        exerciseLoadFailed = false
        do {
            let items = try ExerciseLoader.loadFromBundle()
            exercisesCatalog = items.sorted { $0.name < $1.name }
            isLoadingExercises = false
        } catch {
            print("exercises.json load error:", error)
            exerciseLoadFailed = true
            isLoadingExercises = false
        }
    }

    func startNewWorkout() {
        selectedDate = LogDateHelper.normalized(selectedDate)
        draftExercises.removeAll()
        draftRevision += 1
    }

    func removeDraftExercise(atOffsets indexSet: IndexSet) {
        draftExercises.remove(atOffsets: indexSet)
        draftRevision += 1
    }

    func removeDraftExercise(id: UUID) {
        draftExercises.removeAll { $0.id == id }
        draftRevision += 1
    }

    func exerciseName(forID id: String) -> String? {
        exercisesCatalog.first(where: { $0.id == id })?.name
    }

    func draftEntry(with id: UUID) -> DraftExerciseEntry? {
        draftExercises.first(where: { $0.id == id })
    }

    func saveWorkout(context: ModelContext) {
        let savedSets = buildExerciseSets()
        let normalizedDate = LogDateHelper.normalized(selectedDate)

        if savedSets.isEmpty {
            if let existing = findWorkout(on: normalizedDate, context: context) {
                context.delete(existing)
                do {
                    try context.save()
                    draftsCache[normalizedDate] = draftExercises
                } catch {
                    print("Workout delete error:", error)
                }
            }
            return
        }

        if let existing = findWorkout(on: normalizedDate, context: context) {
            existing.sets = savedSets
        } else {
            let workout = Workout(
                date: normalizedDate,
                note: "",
                sets: savedSets
            )
            context.insert(workout)
        }

        do {
            try context.save()
            draftsCache[normalizedDate] = draftExercises
        } catch {
            print("Workout save error:", error)
        }
    }

    private func findWorkout(on date: Date, context: ModelContext) -> Workout? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { workout in
                workout.date >= startOfDay && workout.date < endOfDay
            }
        )

        return try? context.fetch(descriptor).first
    }

    func syncDraftsForSelectedDate(context: ModelContext) {
        isSyncingDrafts = true
        defer { isSyncingDrafts = false }
        let normalizedNewDate = LogDateHelper.normalized(selectedDate)

        if let lastDate = lastSyncedDate {
            let normalizedLast = LogDateHelper.normalized(lastDate)
            draftsCache[normalizedLast] = draftExercises
        }

        if let cachedDrafts = draftsCache[normalizedNewDate] {
            draftExercises = cachedDrafts
            lastSyncedDate = normalizedNewDate
            return
        }

        if let workout = findWorkout(on: normalizedNewDate, context: context) {
            let grouped = Dictionary(grouping: workout.sets, by: { $0.exerciseName })
            let mapped = grouped.map { exerciseName, sets -> DraftExerciseEntry in
                let rows: [DraftSetRow] = sets.map { set -> DraftSetRow in
                    let intWeight = Int(set.weight.rounded(.toNearestOrAwayFromZero))
                    return DraftSetRow(weightText: String(intWeight), repsText: String(set.reps))
                }
                var entry = DraftExerciseEntry(exerciseName: exerciseName, defaultSetCount: 0)
                entry.sets = rows
                return entry
            }

            draftExercises = mapped.sorted { $0.exerciseName < $1.exerciseName }
        } else {
            draftExercises = []
        }

        lastSyncedDate = normalizedNewDate
    }

    func appendExercise(_ name: String, initialSetCount: Int = 5) {
        let entry = DraftExerciseEntry(exerciseName: name, defaultSetCount: initialSetCount)
        draftExercises.append(entry)
        draftRevision += 1
    }

    func addSetRow(to exerciseID: UUID) {
        guard let index = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        draftExercises[index].sets.append(DraftSetRow())
        draftRevision += 1
    }

    func removeSetRow(exerciseID: UUID, setID: UUID) {
        guard let index = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        draftExercises[index].sets.removeAll { $0.id == setID }
        draftRevision += 1
    }

    func moveDraftExercises(from source: IndexSet, to destination: Int) {
        draftExercises.move(fromOffsets: source, toOffset: destination)
        draftRevision += 1
    }

    func updateSetRow(exerciseID: UUID, setID: UUID, weightText: String, repsText: String) {
        guard let exerciseIndex = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        guard let setIndex = draftExercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        draftExercises[exerciseIndex].sets[setIndex].weightText = weightText
        draftExercises[exerciseIndex].sets[setIndex].repsText = repsText
        draftRevision += 1
    }

    func weightText(exerciseID: UUID, setID: UUID) -> String {
        guard let exerciseIndex = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return "" }
        guard let setIndex = draftExercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return "" }
        return draftExercises[exerciseIndex].sets[setIndex].weightText
    }

    func repsText(exerciseID: UUID, setID: UUID) -> String {
        guard let exerciseIndex = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return "" }
        guard let setIndex = draftExercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return "" }
        return draftExercises[exerciseIndex].sets[setIndex].repsText
    }

    var hasValidSets: Bool {
        draftExercises.contains { entry in
            entry.sets.contains { $0.isValid }
        }
    }

    private func buildExerciseSets() -> [ExerciseSet] {
        let structured = draftExercises.flatMap { entry in
            entry.exerciseSets()
        }

        return structured
    }
}

struct DraftExerciseEntry: Identifiable {
    let id = UUID()
    var exerciseName: String
    var sets: [DraftSetRow]

    init(exerciseName: String, defaultSetCount: Int = 5) {
        self.exerciseName = exerciseName
        self.sets = (0..<defaultSetCount).map { _ in DraftSetRow() }
    }

    func exerciseSets() -> [ExerciseSet] {
        sets.compactMap { $0.toExerciseSet(exerciseName: exerciseName) }
    }

    var completedSetCount: Int {
        sets.filter { $0.isValid }.count
    }
}

struct DraftSetRow: Identifiable {
    let id = UUID()
    var weightText: String = ""
    var repsText: String = ""

    func toExerciseSet(exerciseName: String) -> ExerciseSet? {
        guard let weightInt = Int(weightText), let reps = Int(repsText) else { return nil }
        return ExerciseSet(exerciseName: exerciseName, weight: Double(weightInt), reps: reps)
    }

    var isValid: Bool {
        Int(weightText) != nil && Int(repsText) != nil
    }
}

// まだDBに保存していない「入力中のセット」を表すための一時的な型
struct DraftSet: Identifiable {
    let id = UUID()
    var exerciseName: String
    var weight: Double
    var reps: Int
    var rpe: Double?
}
