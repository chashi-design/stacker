import SwiftData
import SwiftUI

// 種目・重量・レップなどを入力し、一時的にドラフトへ保持する画面
struct LogView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel = LogViewModel()
    @State private var isShowingExercisePicker = false
    @State private var selectedExerciseForEdit: DraftExerciseEntry?
    @State private var pickerSelection: String?

    var body: some View {
        NavigationStack {
            Form {
                LogCalendarSection(selectedDate: $viewModel.selectedDate)

                Section("今回の種目") {
                    HStack {
                        Text("種目を追加")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                    }
                    .foregroundStyle(.tint)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        preparePickerSelection()
                        isShowingExercisePicker = true
                    }
                    .padding(.vertical, 8)

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
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    hideKeyboard()
                }
            )
            .navigationTitle("トレーニングログ")
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
        if pickerSelection == nil, let first = viewModel.exercisesCatalog.first {
            pickerSelection = first.id
        }
    }
}

#Preview {
    LogView()
}
