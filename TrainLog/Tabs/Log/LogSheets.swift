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
            selectedGroup = "favorites"
            if selections.isEmpty, let first = firstExerciseID(for: "favorites") ?? firstExerciseID(for: defaultGroup) {
                selections.insert(first)
            }
        }
        .onChange(of: selectedGroup) { _, newValue in
            guard let group = newValue else { return }
            if selections.isEmpty, let first = firstExerciseID(for: group) {
                selections.insert(first)
            }
        }
    }

    @ViewBuilder
    private var listView: some View {
        List {
            ForEach(filteredExercises, id: \.id) { (item: ExerciseCatalog) in
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
        }
        .listStyle(.plain)
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
        return ["favorites"] + ordered + remaining
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

    private var favoriteExercises: [ExerciseCatalog] {
        exercises.filter { favoritesStore.favoriteIDs.contains($0.id) }
    }

    private var defaultGroup: String {
        if !favoriteExercises.isEmpty {
            return "favorites"
        }
        return muscleGroups.first(where: { !exercises(for: $0).isEmpty }) ?? muscleGroups.first ?? "favorites"
    }

    private func exercises(for group: String) -> [ExerciseCatalog] {
        switch group {
        case "favorites":
            return favoriteExercises
        default:
            return exercises.filter { $0.muscleGroup == group }
        }
    }

    private func muscleColor(for key: String) -> Color {
        switch key {
        case "chest": return .red
        case "shoulders": return .orange
        case "arms": return .yellow
        case "back": return .green
        case "legs": return .teal
        case "abs": return .indigo
        default: return .gray
        }
    }

    private func normalizedForSearch(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // カタカナ→ひらがな、全角→半角に正規化して検索精度を上げる
        let hiragana = trimmed.applyingTransform(.hiraganaToKatakana, reverse: true) ?? trimmed
        return hiragana.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? hiragana
    }

    private func muscleGroupLabel(_ key: String) -> String {
        switch key {
        case "favorites": return "登録"
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
        exercises(for: group).first?.id
    }
}

private struct SearchToolbarVisibility: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            content
        }
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
                    ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 19, alignment: .trailing)
                                .foregroundStyle(.secondary)

                            TextField(
                                "重量(kg)",
                                text: Binding(
                                    get: { viewModel.weightText(exerciseID: exerciseID, setID: set.id) },
                                    set: { viewModel.updateSetRow(exerciseID: exerciseID, setID: set.id, weightText: $0, repsText: viewModel.repsText(exerciseID: exerciseID, setID: set.id)) }
                                )
                            )
                            .keyboardType(.numberPad)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(width: 110)

                            TextField(
                                "レップ数",
                                text: Binding(
                                    get: { viewModel.repsText(exerciseID: exerciseID, setID: set.id) },
                                    set: { viewModel.updateSetRow(exerciseID: exerciseID, setID: set.id, weightText: viewModel.weightText(exerciseID: exerciseID, setID: set.id), repsText: $0) }
                                )
                            )
                            .keyboardType(.numberPad)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(width: 100)

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
                .navigationTitle(entry.exerciseName)
                .navigationBarTitleDisplayMode(.inline)
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

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private struct ScrollEdgeEffectIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            content
        }
    }
}

private extension View {
    @ViewBuilder
    func applyIfAvailableiOS26<Content: View>(_ transform: (Self) -> Content) -> some View {
        if #available(iOS 26.0, *) {
            transform(self)
        } else {
            self
        }
    }
}
