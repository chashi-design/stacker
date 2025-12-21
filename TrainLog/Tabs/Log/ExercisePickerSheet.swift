import SwiftData
import SwiftUI
import UIKit

struct ExercisePickerSheet: View {
    let exercises: [ExerciseCatalog]
    @Binding var selections: Set<String>
    var onCancel: () -> Void
    var onComplete: () -> Void
    @EnvironmentObject private var favoritesStore: ExerciseFavoritesStore
    @State private var selectedGroup: String?
    @State private var searchText: String = ""

    private let muscleGroupOrder = ["chest", "shoulders", "arms", "back", "legs", "abs"]

    var body: some View {
        NavigationStack {
            listView
                .navigationTitle("種目を選択")
                .navigationBarTitleDisplayMode(.inline)
                .applyIfAvailableiOS26 { view in
                    view.scrollEdgeEffectStyle(.soft, for: .all)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { onCancel() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            onComplete()
                        } label: {
                            Label {
                                Text("完了")
                            } icon: {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selections.isEmpty)
                    }
                }
                .searchable(text: $searchText, prompt: "種目名で検索")
                .modifier(SearchToolbarVisibility())
                .safeAreaInset(edge: .top) {
                    if !muscleGroups.isEmpty {
                        VStack(spacing: 0) {
                            Picker("部位", selection: $selectedGroup) {
                                ForEach(muscleGroups, id: \.self) { group in
                                    Text(MuscleGroupLabel.label(for: group)).tag(String?.some(group))
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
            selectedGroup = muscleGroups.first
        }
    }

    @ViewBuilder
    private var listView: some View {
        List {
            if !filteredFavorites.isEmpty {
                let favoriteLabel = selectedGroup.map { "\(MuscleGroupLabel.label(for: $0))のお気に入り" } ?? "お気に入り"
                Section(favoriteLabel) {
                    ForEach(filteredFavorites, id: \.id) { item in
                        exerciseRow(for: item)
                    }
                }
            }

            if !filteredNonFavorites.isEmpty {
                let groupLabel = selectedGroup.map { "\(MuscleGroupLabel.label(for: $0))の種目" } ?? "種目"
                Section(groupLabel) {
                    ForEach(filteredNonFavorites, id: \.id) { item in
                        exerciseRow(for: item)
                    }
                }
            }
        }
        .listRowSeparator(.hidden)
        .scrollContentBackground(.visible)
        .applyIfAvailableiOS26 { view in
            view.scrollEdgeEffectStyle(.soft, for: .all)
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
        let byGroup = exercises(for: group)

        let searched: [ExerciseCatalog]
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            searched = byGroup
        } else {
            let keyword = normalizedForSearch(searchText)
            searched = byGroup.filter { item in
                let name = normalizedForSearch(item.name)
                let nameEn = normalizedForSearch(item.nameEn)
                return name.contains(keyword) || nameEn.contains(keyword)
            }
        }

        return searched.sorted { $0.name < $1.name }
    }

    private var filteredFavorites: [ExerciseCatalog] {
        filteredExercises.filter { favoritesStore.favoriteIDs.contains($0.id) }
    }

    private var filteredNonFavorites: [ExerciseCatalog] {
        filteredExercises.filter { !favoritesStore.favoriteIDs.contains($0.id) }
    }

    private var favoriteExercises: [ExerciseCatalog] {
        exercises.filter { favoritesStore.favoriteIDs.contains($0.id) }
    }

    private func exercises(for group: String) -> [ExerciseCatalog] {
        exercises.filter { $0.muscleGroup == group }
    }

    @ViewBuilder
    private func exerciseRow(for item: ExerciseCatalog) -> some View {
        let isSelected = selections.contains(item.id)
        Button {
            if isSelected {
                selections.remove(item.id)
            } else {
                selections.insert(item.id)
            }
        } label: {
            HStack {
                let color = muscleColor(for: item.muscleGroup)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? color : .secondary)
                    .frame(width: 20)
                VStack(alignment: .leading) {
                    Text(item.name)
                }
                .padding(.leading, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func muscleColor(for key: String) -> Color {
        MuscleGroupColor.color(for: key)
    }

    private func normalizedForSearch(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // カタカナ→ひらがな、全角→半角に正規化して検索精度を上げる
        let hiragana = trimmed.applyingTransform(.hiraganaToKatakana, reverse: true) ?? trimmed
        return hiragana.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? hiragana
    }

}
