import SwiftUI

struct ExerciseListView: View {
    let title: String
    let exercises: [ExerciseCatalog]

    @EnvironmentObject private var favoritesStore: ExerciseFavoritesStore

    var body: some View {
        List {
            ForEach(exercises, id: \.id) { exercise in
                NavigationLink(value: ExerciseRoute.detail(exercise)) {
                    ExerciseRow(
                        exercise: exercise,
                        isFavorite: favoritesStore.isFavorite(exercise.id)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        favoritesStore.toggle(id: exercise.id)
                    } label: {
                        Label(
                            favoritesStore.isFavorite(exercise.id) ? "お気に入り解除" : "お気に入り",
                            systemImage: favoritesStore.isFavorite(exercise.id) ? "star.slash" : "star"
                        )
                    }
                    .tint(favoritesStore.isFavorite(exercise.id) ? .gray : .yellow)
                }
            }
            if exercises.isEmpty {
                Text("登録されている種目がありません")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ExerciseListView(
            title: "胸",
            exercises: [
                ExerciseCatalog(id: "ex001", name: "ベンチプレス", nameEn: "Barbell Bench Press", muscleGroup: "chest", aliases: [], equipment: "barbell", pattern: "horizontal_push")
            ]
        )
        .environmentObject(ExerciseFavoritesStore())
    }
}
