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
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.tertiary)
                        .imageScale(.large)
                        .font(.system(size: 32, weight: .semibold))
                    Text("登録されている種目がありません。\nカテゴリから選んで\nお気に入りに追加しましょう。")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .contentMargins(.top, 4, for: .scrollContent)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}


#Preview {
    NavigationStack {
        ExerciseTabView()
            .environmentObject(ExerciseFavoritesStore())
    }
}
