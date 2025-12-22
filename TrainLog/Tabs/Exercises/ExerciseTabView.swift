import SwiftUI

struct ExerciseTabView: View {
    @StateObject private var favoritesStore = ExerciseFavoritesStore()
    @State private var exercises: [ExerciseCatalog] = []
    @State private var loadFailed = false
    @State private var navigationFeedbackTrigger = 0
    @State private var path: [ExerciseRoute] = []

    private let muscleGroupOrder = ["chest", "shoulders", "arms", "back", "legs", "abs", "other"]

    private var categories: [ExerciseCategory] {
        let grouped = Dictionary(grouping: exercises, by: { $0.muscleGroup })
        let raw = grouped.map { key, value in
            ExerciseCategory(
                id: key,
                title: MuscleGroupLabel.label(for: key),
                color: MuscleGroupColor.color(for: key),
                exercises: value.sorted { $0.name < $1.name }
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
        exercises.filter { favoritesStore.isFavorite($0.id) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: ExerciseRoute.favorites) {
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("お気に入り")
                                .foregroundStyle(favoriteExercises.isEmpty ? .secondary : .primary)
                            Spacer()
                            Text("\(favoriteExercises.count)種目")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                }

                Section("カテゴリ") {
                    ForEach(categories) { category in
                        NavigationLink(value: ExerciseRoute.category(category.id)) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 20, height: 20)
                                Text(category.title)
                                Spacer()
                                Text("\(category.exercises.count)種目")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                    }
                    if categories.isEmpty {
                        Text("種目データがありません")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("種目")
            .task { loadExercises() }
            .alert("種目リストの読み込みに失敗しました", isPresented: $loadFailed) {
                Button("OK", role: .cancel) {}
            }
            .animation(.default, value: favoriteExercises)
            .navigationDestination(for: ExerciseRoute.self) { route in
                switch route {
                case .favorites:
                    ExerciseListView(title: "お気に入り", exercises: favoriteExercises)
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
            .sensoryFeedback(.impact(weight: .light), trigger: navigationFeedbackTrigger)
        }
        .environmentObject(favoritesStore)
    }

    private func loadExercises() {
        guard exercises.isEmpty else { return }
        do {
            exercises = try ExerciseLoader.loadFromBundle()
        } catch {
            loadFailed = true
        }
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

struct ExerciseRow: View {
    let exercise: ExerciseCatalog
    let isFavorite: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.headline)
            }
            Spacer()
            if isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ExerciseTabView()
    }
}
