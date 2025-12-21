import SwiftUI

struct ExerciseTabView: View {
    @StateObject private var favoritesStore = ExerciseFavoritesStore()
    @State private var exercises: [ExerciseCatalog] = []
    @State private var loadFailed = false

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
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ExerciseListView(
                            title: "登録済み",
                            exercises: favoriteExercises
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("登録済み")
                                .foregroundStyle(favoriteExercises.isEmpty ? .secondary : .primary)
                            Spacer()
                            Text("\(favoriteExercises.count)種目")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("カテゴリ") {
                    ForEach(categories) { category in
                        NavigationLink {
                            ExerciseListView(
                                title: category.title,
                                exercises: category.exercises
                            )
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 20, height: 20)
                                Text(category.title)
                                Spacer()
                                Text("\(category.exercises.count)種目")
                                    .foregroundStyle(.secondary)
                                    .font(.footnote)
                            }
                            .padding(.vertical, 4)
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

struct ExerciseRow: View {
    let exercise: ExerciseCatalog
    let isFavorite: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.headline)
                Text(exercise.nameEn)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
