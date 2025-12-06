//
// このファイルでは「筋トレ記録アプリ」の主要画面をすべて定義しています。
// - 履歴画面(HistoryView)
// - 入力画面(LogView)
// - 統計画面(StatsView)
// - タブをまとめるContentView
// SwiftDataで保存されたWorkout/ExerciseSetのデータを読み書きします。
//
import UIKit
import SwiftData
import SwiftUI
import Charts
import Combine

// MARK: - 履歴画面
// 保存されたトレーニング(Workout)を日付の新しい順にリスト表示する画面です。
// 各行をタップすると詳細(WorkoutDetailView)に遷移します。
struct HistoryView: View {
    // SwiftDataに保存されているWorkoutを自動的に取得する
    // \Workout.date を基準に降順(.reverse)で並べています
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            List {
                // まだ1件もトレーニングが保存されていないときの表示
                if workouts.isEmpty {
                    ContentUnavailableView("まだ記録がありません", systemImage: "tray", description: Text("ログでトレーニングを保存するとここに表示されます"))
                } else {
                    // 保存済みのWorkoutを1件ずつ表示
                    ForEach(workouts) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            HStack {
                                // 左側に日時とメモ、右側にセット数を表示
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dateTimeString(for: workout.date))
                                        .font(.headline)
                                    if !workout.note.isEmpty {
                                        Text(workout.note)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(workout.sets.count)セット")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(workout: workout)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteWorkouts)
                }
            }
            .navigationTitle("履歴")
        }
    }
    
    // Dateを「yyyy/MM/dd HH:mm」形式の日本語表記に変換するヘルパー
    private func dateTimeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func delete(workout: Workout) {
        context.delete(workout)
        try? context.save()
    }

    private func deleteWorkouts(atOffsets offsets: IndexSet) {
        for index in offsets {
            guard workouts.indices.contains(index) else { continue }
            delete(workout: workouts[index])
        }
    }
}

// MARK: - アプリ全体のタブをまとめるビュー
// ログ・履歴・統計の3画面をタブで切り替えます。
struct ContentView: View {
    var body: some View {
        TabView {
            OverviewTabView()
                .tabItem {
                    Label("概要", systemImage: "square.grid.2x2")
                }

            // 新しいトレーニングを入力する画面
            LogView()
                .tabItem {
                    Label("ログ", systemImage: "square.and.pencil")
                }

            // 保存したトレーニングを一覧で見る画面
            HistoryView()
                .tabItem {
                    Label("履歴", systemImage: "clock.arrow.circlepath")
                }
        }
    }
}

// MARK: - 履歴詳細画面
// 1回分のトレーニング内容(セットの一覧)を表示します。
struct WorkoutDetailView: View {
    let workout: Workout

    var body: some View {
        List {
            // トレーニングした日時やメモを表示するセクション
            Section("概要") {
                Text(dateTimeString(for: workout.date))
                if !workout.note.isEmpty {
                    Text(workout.note)
                }
            }

            // その日に実施したセットを1行ずつ表示するセクション
            Section("セット") {
                if workout.sets.isEmpty {
                    Text("セットがありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workout.sets) { set in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(set.exerciseName)
                                if let rpe = set.rpe {
                                    Text("RPE \(rpe, specifier: "%.1f")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(set.weight, format: .number.precision(.fractionLength(0...2))) kg × \(set.reps)")
                        }
                    }
                }
            }
        }
        .navigationTitle("詳細")
    }
    
    // 日付を「yyyy/MM/dd HH:mm」形式で表示するためのヘルパー
    private func dateTimeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 統計画面
// 保存されたトレーニングデータから日別・月別のボリュームを集計し、Swift Chartsで表示します。
struct StatsView: View {
    // すべてのWorkoutを新しい順で取得
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    // 日別表示か月別表示かを保持する状態
    @State private var selectedRange: StatsRange = .week

    var body: some View {
        NavigationStack {
            List {
                // 日別/月別を切り替えるピッカー（スクロールに乗る）
                Section {
                    Picker("期間", selection: $selectedRange) {
                        ForEach(StatsRange.allCases, id: \.self) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 棒グラフでボリュームを可視化するエリア
                Section(header: Text("ボリューム")) {
                    let totals = aggregateVolume(range: selectedRange)
                    if totals.isEmpty {
                        Text("まだ記録がありません")
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(totals, id: \.date) { item in
                            BarMark(
                                x: .value("日付", item.date, unit: selectedRange == .week ? .day : .month),
                                y: .value("ボリューム(kg)", item.volume)
                            )
                        }
                        .frame(height: 220)
                    }
                }

                // 下に数値でも同じ内容を一覧表示（デバッグ・確認しやすくする）
                Section(header: Text(selectedRange.title)) {
                    let totals = aggregateVolume(range: selectedRange)
                    ForEach(totals, id: \.date) { item in
                        HStack {
                            Text(dateString(item.date, range: selectedRange))
                            Spacer()
                            Text("\(Int(item.volume)) kg")
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationTitle("統計")
        }
    }

    // Workoutのセットから「その日(または月)の合計ボリューム」を出す関数
    private func aggregateVolume(range: StatsRange) -> [StatsItem] {
        let calendar = Calendar.current
        var buckets: [Date: Double] = [:]

        for workout in workouts {
            // 1日の合計ボリュームを出す
            let dayVolume = workout.sets.reduce(0.0) { $0 + $1.volume }
            // バケットキーを期間に応じて丸める
            let key: Date
            switch range {
            case .week:
                key = calendar.startOfDay(for: workout.date)
            case .month:
                let comps = calendar.dateComponents([.year, .month], from: workout.date)
                key = calendar.date(from: comps) ?? calendar.startOfDay(for: workout.date)
            }
            buckets[key, default: 0] += dayVolume
        }

        // 日付の降順で並べて返す
        return buckets
            .map { StatsItem(date: $0.key, volume: $0.value) }
            .sorted { $0.date > $1.date }
    }

    // グラフ下のリストで表示するための日付文字列を生成
    private func dateString(_ date: Date, range: StatsRange) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        switch range {
        case .week:
            formatter.dateFormat = "yyyy/MM/dd"
        case .month:
            formatter.dateFormat = "yyyy/MM"
        }
        return formatter.string(from: date)
    }
}

// 日別で見るか月別で見るかを表す列挙型
enum StatsRange: CaseIterable {
    case week
    case month

    var title: String {
        switch self {
        case .week: return "日別"
        case .month: return "月別"
        }
    }
}

// グラフやリストで使う「1行分の集計結果」を表す簡単な構造体
struct StatsItem {
    let date: Date
    let volume: Double
}

// MARK: - ログ入力画面
// 種目・重量・レップなどを入力し、一時的にdraftSetsにためておき、
// 「このトレーニングを保存」でSwiftDataに書き込む画面です。
struct LogView: View {
    // SwiftDataにアクセスするためのコンテキスト
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel = LogViewModel()
    @State private var isShowingExercisePicker = false
    @State private var selectedExerciseForEdit: DraftExerciseEntry?
    @State private var pickerSelection: String?

    var body: some View {
        NavigationStack {
            Form {
                LogCalendarSection(selectedDate: $viewModel.selectedDate)
       

                Button {
                    preparePickerSelection()
                    isShowingExercisePicker = true
                } label: {
                    Text("種目を追加")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.primary)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoadingExercises || viewModel.exerciseLoadFailed)
                .listRowInsets(EdgeInsets())
                .padding(.horizontal, 10)

                Section("今回の種目") {
                    if viewModel.draftExercises.isEmpty {
                        Text("追加された種目はありません。＋から追加してください。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.draftExercises) { entry in
                            Button {
                                selectedExerciseForEdit = entry
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.exerciseName)
                                            .font(.headline)
                                        Text("\(entry.completedSetCount)セット")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            viewModel.removeDraftExercise(atOffsets: offsets)
                        }
                    }
                }
            }
            // スクロールやドラッグでキーボードを閉じやすくする
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    hideKeyboard()
                }
            )
            .navigationTitle("トレーニングログ")
            // 画面表示時に種目カタログ(exercises.json)を読み込んでリストから選択できるようにする
            .task {
                await viewModel.loadExercises()
                viewModel.syncDraftsForSelectedDate(context: context)
            }
            .sheet(isPresented: $isShowingExercisePicker) {
                ExercisePickerSheet(
                    exercises: viewModel.exercisesCatalog,
                    selection: $pickerSelection,
                    onCancel: {
                        pickerSelection = nil
                        isShowingExercisePicker = false
                    },
                    onComplete: {
                        if let selection = pickerSelection,
                           let name = viewModel.exerciseName(forID: selection) {
                            viewModel.appendExercise(name)
                        }
                        pickerSelection = nil
                        isShowingExercisePicker = false
                    }
                )
            }
            .sheet(item: $selectedExerciseForEdit) { entry in
                SetEditorSheet(viewModel: viewModel, exerciseID: entry.id)
            }
            .onChange(of: viewModel.selectedDate) {
                viewModel.syncDraftsForSelectedDate(context: context)
            }
        }
    }
    
    private func preparePickerSelection() {
        // デフォルト選択を先頭に置く（未選択の場合）
        if pickerSelection == nil, let first = viewModel.exercisesCatalog.first {
            pickerSelection = first.id
        }
    }
}

@MainActor
final class LogViewModel: ObservableObject {
    @Published var selectedDate = LogDateHelper.normalized(Date())
    @Published var exercisesCatalog: [ExerciseCatalog] = []
    @Published var isLoadingExercises = true
    @Published var exerciseLoadFailed = false
    // 新UI用: 種目ごとにセットを管理するドラフト
    @Published var draftExercises: [DraftExerciseEntry] = []

    // 選択日ごとのドラフトを保持するキャッシュ
    private var draftsCache: [Date: [DraftExerciseEntry]] = [:]
    // 直近で同期した日付を記録
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
    }

    func removeDraftExercise(atOffsets indexSet: IndexSet) {
        draftExercises.remove(atOffsets: indexSet)
    }

    func exerciseName(forID id: String) -> String? {
        exercisesCatalog.first(where: { $0.id == id })?.name
    }

    func draftEntry(with id: UUID) -> DraftExerciseEntry? {
        draftExercises.first(where: { $0.id == id })
    }

    func saveWorkout(context: ModelContext) {
        let savedSets = buildExerciseSets()
        guard !savedSets.isEmpty else { return }

        let normalizedDate = LogDateHelper.normalized(selectedDate)

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
        // Normalize the new selected date
        let normalizedNewDate = LogDateHelper.normalized(selectedDate)

        // Save current drafts for the previous date into the cache
        if let lastDate = lastSyncedDate {
            let normalizedLast = LogDateHelper.normalized(lastDate)
            draftsCache[normalizedLast] = draftExercises
        }

        // Try to restore drafts for the newly selected date from the in-memory cache first
        if let cachedDrafts = draftsCache[normalizedNewDate] {
            draftExercises = cachedDrafts
            lastSyncedDate = normalizedNewDate
            return
        }

        // If there is no cached draft, fall back to loading from persisted Workout
        if let workout = findWorkout(on: normalizedNewDate, context: context) {
            let grouped = Dictionary(grouping: workout.sets, by: { $0.exerciseName })
            let mapped = grouped.map { exerciseName, sets -> DraftExerciseEntry in
                let rows: [DraftSetRow] = sets.map { set in
                    DraftSetRow(weightText: String(set.weight), repsText: String(set.reps))
                }
                var entry = DraftExerciseEntry(exerciseName: exerciseName, defaultSetCount: 0)
                entry.sets = rows
                return entry
            }

            draftExercises = mapped.sorted { $0.exerciseName < $1.exerciseName }
        } else {
            // No workout and no cached drafts → start with empty list
            draftExercises = []
        }

        // Remember the date we just synced
        lastSyncedDate = normalizedNewDate
    }

    func appendExercise(_ name: String, initialSetCount: Int = 5) {
        let entry = DraftExerciseEntry(exerciseName: name, defaultSetCount: initialSetCount)
        draftExercises.append(entry)
    }

    func addSetRow(to exerciseID: UUID) {
        guard let index = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        draftExercises[index].sets.append(DraftSetRow())
    }

    func removeSetRow(exerciseID: UUID, setID: UUID) {
        guard let index = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        draftExercises[index].sets.removeAll { $0.id == setID }
    }

    func updateSetRow(exerciseID: UUID, setID: UUID, weightText: String, repsText: String) {
        guard let exerciseIndex = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        guard let setIndex = draftExercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        draftExercises[exerciseIndex].sets[setIndex].weightText = weightText
        draftExercises[exerciseIndex].sets[setIndex].repsText = repsText
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
        guard let weight = Double(weightText), let reps = Int(repsText) else { return nil }
        return ExerciseSet(exerciseName: exerciseName, weight: weight, reps: reps)
    }

    var isValid: Bool {
        Double(weightText) != nil && Int(repsText) != nil
    }
}

struct ExercisePickerSheet: View {
    let exercises: [ExerciseCatalog]
    @Binding var selection: String?
    var onCancel: () -> Void
    var onComplete: () -> Void
    @State private var selectedGroup: String?

    private let muscleGroupOrder = ["chest", "shoulders", "arms", "back", "legs", "abs"]

    var body: some View {
        NavigationStack {
            listView
            .navigationTitle("種目を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { onComplete() }
                        .disabled(selection == nil)
                }
            }
            .safeAreaInset(edge: .top) {
                if !muscleGroups.isEmpty {
                    VStack(spacing: 0) {
                        Picker("部位", selection: $selectedGroup) {
                            ForEach(muscleGroups, id: \.self) { group in
                                Text(muscleGroupLabel(group)).tag(String?.some(group))
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .background(.ultraThinMaterial)
                }
            }
        }
        .onAppear {
            if selectedGroup == nil {
                let initialGroup = muscleGroups.first
                selectedGroup = initialGroup
                if let group = initialGroup {
                    selection = firstExerciseID(for: group)
                }
            } else if selection == nil, let group = selectedGroup {
                selection = firstExerciseID(for: group)
            }
        }
        .onChange(of: selectedGroup) { oldValue, newValue in
            if let group = newValue {
                selection = firstExerciseID(for: group)
            } else {
                selection = nil
            }
        }
    }

    @ViewBuilder
    private var listView: some View {
        List {
            ForEach(filteredExercises, id: \.id) { (item: ExerciseCatalog) in
                Button {
                    selection = item.id
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                            if !item.nameEn.isEmpty {
                                Text(item.nameEn)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if selection == item.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var muscleGroups: [String] {
        let groups = Set(exercises.map { $0.muscleGroup })
        let ordered = muscleGroupOrder.filter { groups.contains($0) }
        let remaining = groups.subtracting(muscleGroupOrder).sorted()
        return ordered + remaining
    }

    private var filteredExercises: [ExerciseCatalog] {
        guard let group = selectedGroup else { return [] }
        return exercises
            .filter { $0.muscleGroup == group }
            .sorted { $0.name < $1.name }
    }

    private func muscleGroupLabel(_ key: String) -> String {
        switch key {
        case "chest": return "胸"
        case "shoulders": return "肩"
        case "arms": return "腕"
        case "back": return "背中"
        case "legs": return "脚"
        case "abs": return "腹"
        default: return key
        }
    }

    private func firstExerciseID(for group: String) -> String? {
        filteredExercises.first(where: { $0.muscleGroup == group })?.id
    }
}

struct SetEditorSheet: View {
    @ObservedObject var viewModel: LogViewModel
    let exerciseID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            if let entry = viewModel.draftEntry(with: exerciseID) {
                List {
                    Section(header: Text(entry.exerciseName)) {
                        ForEach(entry.sets) { set in
                            HStack {
                                TextField(
                                    "重量(kg)",
                                    text: Binding(
                                        get: { viewModel.weightText(exerciseID: exerciseID, setID: set.id) },
                                        set: { viewModel.updateSetRow(exerciseID: exerciseID, setID: set.id, weightText: $0, repsText: viewModel.repsText(exerciseID: exerciseID, setID: set.id)) }
                                    )
                                )
                                .keyboardType(.decimalPad)
                                .frame(width: 90)

                                TextField(
                                    "レップ数",
                                    text: Binding(
                                        get: { viewModel.repsText(exerciseID: exerciseID, setID: set.id) },
                                        set: { viewModel.updateSetRow(exerciseID: exerciseID, setID: set.id, weightText: viewModel.weightText(exerciseID: exerciseID, setID: set.id), repsText: $0) }
                                    )
                                )
                                .keyboardType(.numberPad)
                                .frame(width: 80)

                                Spacer()

                                Button(role: .destructive) {
                                    viewModel.removeSetRow(exerciseID: exerciseID, setID: set.id)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .disabled(entry.sets.count <= 1)
                            }
                        }

                        Button {
                            viewModel.addSetRow(to: exerciseID)
                        } label: {
                            Label("セットを追加", systemImage: "plus.circle.fill")
                        }
                    }
                }
                .navigationTitle("セット編集")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            viewModel.saveWorkout(context: context)
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text("編集対象が見つかりませんでした")
                        .foregroundStyle(.secondary)
                    Button("閉じる") { dismiss() }
                }
                .padding()
            }
        }
    }
}

// MARK: - カレンダー表示
struct LogCalendarSection: View {
    @Binding var selectedDate: Date
    @State private var datePickerID = UUID()
    private let calendar = Calendar.current
    private let locale = Locale(identifier: "ja_JP")

    init(selectedDate: Binding<Date>) {
        _selectedDate = selectedDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Current selected date label + "today" button
            HStack(alignment: .firstTextBaseline) {
                Label(LogDateHelper.label(for: selectedDate), systemImage: "calendar")
                    .font(.subheadline)

                Spacer()

                Button {
                    selectToday()
                } label: {
                    Text("今日に戻す")
                        .font(.caption)
                }
            }

            // Graphical calendar DatePicker
            DatePicker(
                "",
                selection: Binding(
                    get: { selectedDate },
                    set: { newValue in
                        selectedDate = LogDateHelper.normalized(newValue)
                    }
                ),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .environment(\.locale, locale)
            .id(datePickerID)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func selectToday() {
        let today = LogDateHelper.normalized(Date())
        let alreadyToday = calendar.isDate(selectedDate, inSameDayAs: today)
        selectedDate = today
        if alreadyToday {
            datePickerID = UUID()
        }
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

// キーボードを閉じるための共通ヘルパー（どのViewからでも呼べるようにextensionにしている）
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}



#Preview {
    ContentView()
}
