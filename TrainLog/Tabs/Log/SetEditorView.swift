import SwiftData
import SwiftUI

struct SetEditorView: View {
    @ObservedObject var viewModel: LogViewModel
    let exerciseID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

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
