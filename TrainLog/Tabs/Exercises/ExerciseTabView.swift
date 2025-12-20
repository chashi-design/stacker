import SwiftUI

struct ExerciseTabView: View {
    @StateObject private var favoritesStore = ExerciseFavoritesStore()
    @State private var exercises: [ExerciseCatalog] = []
    @State private var loadFailed = false

    private var categories: [ExerciseCategory] {
        let grouped = Dictionary(grouping: exercises, by: { $0.muscleGroup })
        return grouped.map { key, value in
            ExerciseCategory(
                id: key,
                title: MuscleGroupLabel.label(for: key),
                color: MuscleGroupColor.color(for: key),
                exercises: value.sorted { $0.name < $1.name }
            )
        }
        .sorted { $0.title < $1.title }
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
                            title: "お気に入り",
                            exercises: favoriteExercises
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("お気に入りリスト")
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

enum MuscleGroupColor {
    static func color(for key: String) -> Color {
        palette[key, default: .secondary]
    }

    private static let palette: [String: Color] = [
        "chest": Color.red,
        "shoulders": Color.orange,
        "arms": Color.pink,
        "back": Color.blue,
        "legs": Color.green,
        "abs": Color.yellow,
        "other": Color.gray
    ]
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
