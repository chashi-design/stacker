//
// このファイルでは「筋トレ記録アプリ」の主要画面をすべて定義しています。
// - 履歴画面(HistoryView)
// - 入力画面(LogView)
// - 統計画面(StatsView)
// - タブをまとめるContentView
// SwiftDataで保存されたWorkout/ExerciseSetのデータを読み書きします。
//
import SwiftData
import SwiftUI
import Charts

// MARK: - 履歴画面
// 保存されたトレーニング(Workout)を日付の新しい順にリスト表示する画面です。
// 各行をタップすると詳細(WorkoutDetailView)に遷移します。
struct HistoryView: View {
    // SwiftDataに保存されているWorkoutを自動的に取得する
    // \Workout.date を基準に降順(.reverse)で並べています
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

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
                    }
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
}

// MARK: - アプリ全体のタブをまとめるビュー
// ログ・履歴・統計の3画面をタブで切り替えます。
struct ContentView: View {
    var body: some View {
        TabView {
            // 保存されたデータを元にボリュームを集計・グラフ表示する画面
            StatsView()
                .tabItem {
                    Label("統計", systemImage: "chart.line.uptrend.xyaxis")
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
    // 画面上の入力値を保持しておくState
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var exercise = ""
    @State private var weight = ""
    @State private var reps = ""
    @State private var rpe = ""
    @State private var note = ""
    // フォームで追加した「今回のセット」を一時的に保持するための配列
    @State private var draftSets: [DraftSet] = []
    // 種目カタログ(exercises.json)の一覧
    @State private var exercisesCatalog: [ExerciseCatalog] = []
    @State private var isLoadingExercises = true
    @State private var exerciseLoadFailed = false

    var body: some View {
        NavigationStack {
            Form {
                Section("日付") {
                    DatePicker("日付", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .onChange(of: selectedDate) { newValue in
                            selectedDate = normalizedDate(newValue)
                        }

                    HStack {
                        Label(selectedDateLabel, systemImage: "calendar")
                            .font(.headline)
                        Spacer()
                        Button("今日に戻す") {
                            selectedDate = normalizedDate(Date())
                        }
                        .font(.caption)
                    }
                    .padding(.top, 4)
                }

                Section("種目") {
                    if isLoadingExercises {
                        ProgressView("読み込み中…")
                    } else if exerciseLoadFailed {
                        Text("種目リストを読み込めませんでした")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("種目を選択", selection: $exercise) {
                            Text("選択してください").tag("")
                            ForEach(exercisesCatalog, id: \.id) { item in
                                if item.nameEn.isEmpty {
                                    Text(item.name).tag(item.name)
                                } else {
                                    Text("\(item.name) (\(item.nameEn))").tag(item.name)
                                }
                            }
                        }
                    }
                }

                Section("負荷") {
                    // 重量・レップ・RPEなど1セットに必要な情報を入力
                    TextField("重量(kg)", text: $weight)
                        .keyboardType(.decimalPad)
                    TextField("レップ数", text: $reps)
                        .keyboardType(.numberPad)
                    TextField("RPE (任意)", text: $rpe)
                        .keyboardType(.decimalPad)
                }

                Section("メモ") {
                    TextField("メモ (任意)", text: $note)
                }

                // 入力した内容を一時的なセットとして下のリストに追加
                Section {
                    Button("このセットを追加") {
                        addSet()
                    }
                    .disabled(exercise.isEmpty || weight.isEmpty || reps.isEmpty)
                }
                
                // 一時的にためたセット(draftSets)を1つのWorkoutとしてDBに保存
                Section {
                    Button("このトレーニングを保存") {
                        saveWorkout()
                    }
                    .disabled(draftSets.isEmpty)
                }

                // いま入力中のセットを表示（保存前の確認用）
                if !draftSets.isEmpty {
                    Section("今回のセット") {
                        ForEach(draftSets) { set in
                            HStack {
                                Text(set.exerciseName)
                                Spacer()
                                Text("\(set.weight, format: .number.precision(.fractionLength(0...2))) kg × \(set.reps)")
                            }
                        }
                        .onDelete { indexSet in
                            draftSets.remove(atOffsets: indexSet)
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
                isLoadingExercises = true
                exerciseLoadFailed = false
                do {
                    let items = try ExerciseLoader.loadFromBundle()
                    exercisesCatalog = items.sorted { $0.name < $1.name }
                    if !exercisesCatalog.contains(where: { $0.name == exercise }) {
                        exercise = ""
                    }
                    isLoadingExercises = false
                } catch {
                    print("exercises.json load error:", error)
                    exerciseLoadFailed = true
                    isLoadingExercises = false
                }
            }
        }
    }

    // フォームの入力値から一時的なセット(DraftSet)を1件作って配列に追加する
    private func addSet() {
        let set = DraftSet(
            exerciseName: exercise,
            weight: Double(weight) ?? 0,
            reps: Int(reps) ?? 0,
            rpe: Double(rpe)
        )
        draftSets.append(set)
        // 続けて同じ種目・重量を使う想定なのでそこは残す
        reps = ""
        rpe = ""
    }

    // draftSetsをSwiftData用のExerciseSetに変換し、1日のWorkoutとして保存する
    private func saveWorkout() {
        // ドラフトのセットをSwiftData用のセットに変換
        let savedSets = draftSets.map { draft in
            ExerciseSet(
                exerciseName: draft.exerciseName,
                weight: draft.weight,
                reps: draft.reps,
                rpe: draft.rpe
            )
        }

        // Workoutにまとめる
        let workout = Workout(
            date: normalizedDate(selectedDate),
            note: note,
            sets: savedSets
        )

        // 保存
        context.insert(workout)

        // フォームをリセット
        draftSets.removeAll()
        note = ""
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

extension LogView {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(E)"
        return formatter
    }()

    private var selectedDateLabel: String {
        Self.dateFormatter.string(from: selectedDate)
    }

    private func normalizedDate(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
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
