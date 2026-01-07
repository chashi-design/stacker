import SwiftUI

// 種目タブ画面
struct ExerciseTabView: View {
    @EnvironmentObject private var favoritesStore: ExerciseFavoritesStore
    @State private var exercises: [ExerciseCatalog] = []
    @State private var loadFailed = false
    @State private var isLoadingExercises = true
    @State private var navigationFeedbackTrigger = 0
    @State private var path: [ExerciseRoute] = []
    @State private var showSettings = false
    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }
    private var strings: ExerciseTabStrings {
        ExerciseTabStrings(isJapanese: isJapaneseLocale)
    }

    private let muscleGroupOrder = ["chest", "shoulders", "arms", "back", "legs", "abs", "cardio", "other"]

    private var categories: [ExerciseCategory] {
        let isJapanese = isJapaneseLocale
        let grouped = Dictionary(grouping: exercises, by: { $0.muscleGroup })
        let raw = grouped.map { key, value in
            ExerciseCategory(
                id: key,
                title: MuscleGroupLabel.label(for: key),
                color: MuscleGroupColor.color(for: key),
                exercises: value.sorted {
                    displayName($0, isJapanese: isJapanese) < displayName($1, isJapanese: isJapanese)
                }
            )
        }
        return raw.sorted { lhs, rhs in
            let leftIndex = muscleGroupOrder.firstIndex(of: lhs.id) ?? muscleGroupOrder.count
            let rightIndex = muscleGroupOrder.firstIndex(of: rhs.id) ?? muscleGroupOrder.count
            if leftIndex == rightIndex {
                return lhs.title < rhs.title
            }
            return leftIndex < rightIndex
        }
    }

    private var favoriteExercises: [ExerciseCatalog] {
        let isJapanese = isJapaneseLocale
        return exercises.filter { favoritesStore.isFavorite($0.id) }
            .sorted { displayName($0, isJapanese: isJapanese) < displayName($1, isJapanese: isJapanese) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: ExerciseRoute.favorites) {
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(strings.favoritesTitle)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(strings.exerciseCountText(favoriteExercises.count))
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                }

                Section(strings.categorySectionTitle) {
                    ForEach(categories) { category in
                        NavigationLink(value: ExerciseRoute.category(category.id)) {
                            HStack(spacing: 12) {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(category.color)
                                Text(category.title)
                                    .font(.body)
                                Spacer()
                                Text(strings.exerciseCountText(category.exercises.count))
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                    }
                    if isLoadingExercises {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if categories.isEmpty {
                        Text(strings.noExerciseData)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(strings.navigationTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel(strings.settingsLabel)
                    .tint(.primary)
                }
            }
            .task { loadExercises() }
            .alert(strings.loadFailedMessage, isPresented: $loadFailed) {
                Button("OK", role: .cancel) {}
            }
            .animation(.default, value: favoriteExercises)
            .navigationDestination(for: ExerciseRoute.self) { route in
                switch route {
                case .favorites:
                    ExerciseListView(title: strings.favoritesTitle, exercises: favoriteExercises)
                case .category(let id):
                    if let category = categories.first(where: { $0.id == id }) {
                        ExerciseListView(title: category.title, exercises: category.exercises)
                    } else {
                        ExerciseListView(title: MuscleGroupLabel.label(for: id), exercises: [])
                    }
                case .detail(let exercise):
                    ExerciseDetailView(exercise: exercise)
                }
            }
            .onChange(of: path) { oldValue, newValue in
                if newValue.count > oldValue.count {
                    navigationFeedbackTrigger += 1
                }
            }
            .onChange(of: showSettings) { _, newValue in
                if newValue {
                    navigationFeedbackTrigger += 1
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: navigationFeedbackTrigger)
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }

    private func loadExercises() {
        guard exercises.isEmpty else {
            isLoadingExercises = false
            return
        }
        isLoadingExercises = true
        do {
            exercises = try ExerciseLoader.loadFromBundle()
        } catch {
            loadFailed = true
        }
        isLoadingExercises = false
    }

    private func displayName(_ exercise: ExerciseCatalog, isJapanese: Bool) -> String {
        exercise.displayName(isJapanese: isJapanese)
    }
}

struct ExerciseCategory: Identifiable {
    let id: String
    let title: String
    let color: Color
    let exercises: [ExerciseCatalog]
}

enum ExerciseRoute: Hashable {
    case favorites
    case category(String)
    case detail(ExerciseCatalog)
}

private struct ExerciseTabStrings {
    let isJapanese: Bool

    var favoritesTitle: String { isJapanese ? "お気に入り" : "Favorites" }
    var categorySectionTitle: String { isJapanese ? "カテゴリ" : "Categories" }
    var noExerciseData: String { isJapanese ? "種目データがありません" : "No exercise data available." }
    var navigationTitle: String { isJapanese ? "種目" : "Exercises" }
    var settingsLabel: String { isJapanese ? "設定" : "Settings" }
    var loadFailedMessage: String {
        isJapanese ? "種目リストの読み込みに失敗しました" : "Failed to load exercise list."
    }
    func exerciseCountText(_ count: Int) -> String {
        isJapanese ? "\(count)種目" : "\(count) exercises"
    }
}

#Preview {
    NavigationStack {
        ExerciseTabView()
            .environmentObject(ExerciseFavoritesStore())
    }
}
