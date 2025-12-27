import SwiftData
import SwiftUI

struct SetEditorView: View {
    @ObservedObject var viewModel: LogViewModel
    let exerciseID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var fieldHapticTrigger = 0
    @State private var addSetHapticTrigger = 0
    @State private var deleteSetHapticTrigger = 0
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case weight(UUID)
        case reps(UUID)
    }

    var body: some View {
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
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .weight(set.id))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(width: 110)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = .weight(set.id)
                        }

                        TextField(
                            "レップ数",
                            text: Binding(
                                get: { viewModel.repsText(exerciseID: exerciseID, setID: set.id) },
                                set: { viewModel.updateSetRow(exerciseID: exerciseID, setID: set.id, weightText: viewModel.weightText(exerciseID: exerciseID, setID: set.id), repsText: $0) }
                            )
                        )
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .reps(set.id))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(width: 110)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = .reps(set.id)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            viewModel.removeSetRow(exerciseID: exerciseID, setID: set.id)
                            deleteSetHapticTrigger += 1
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(entry.sets.count <= 1)
                        .sensoryFeedback(.impact(weight: .light), trigger: deleteSetHapticTrigger)
                    }
                }

                Button {
                    viewModel.addSetRow(to: exerciseID)
                    addSetHapticTrigger += 1
                } label: {
                    Label("セットを追加", systemImage: "plus.circle.fill")
                }
                .sensoryFeedback(.impact(weight: .light), trigger: addSetHapticTrigger)
            }
            .contentMargins(.top, 4, for: .scrollContent)
            .onChange(of: focusedField) { _, newValue in
                if newValue != nil {
                    fieldHapticTrigger += 1
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: fieldHapticTrigger)
            .navigationTitle(entry.exerciseName)
            .navigationBarTitleDisplayMode(.inline)
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
