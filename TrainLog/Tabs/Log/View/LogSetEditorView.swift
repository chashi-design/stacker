import SwiftData
import SwiftUI

// セット編集画面
struct SetEditorView: View {
    @ObservedObject var viewModel: LogViewModel
    let exerciseID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.weightUnit) private var weightUnit
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
                            "重量(\(weightUnit.unitLabel))",
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

                if let metrics = metrics(for: entry, context: context, selectedDate: viewModel.selectedDate, unit: weightUnit) {
                    Section("筋ボリューム推移") {
                        ExerciseVolumeChart(
                            data: metrics.volumeChartData,
                            barColor: muscleGroupColor(for: entry),
                            animateOnAppear: false,
                            animateOnTrigger: false,
                            animationTrigger: viewModel.draftRevision,
                            yValueLabel: "ボリューム(\(weightUnit.unitLabel))",
                            yAxisLabel: weightUnit.unitLabel
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section("筋ボリュームの推移") {
                        Text("有効なセットを入力すると指標を表示します")
                            .foregroundStyle(.secondary)
                    }
                }
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

private struct SetMetrics {
    let volumeChartData: [(label: String, value: Double)]
}

private extension SetEditorView {
    func metrics(
        for entry: DraftExerciseEntry,
        context: ModelContext,
        selectedDate: Date,
        unit: WeightUnit
    ) -> SetMetrics? {
        let currentVolume = entry.sets.compactMap { set in
            guard let weight = Double(set.weightText), let reps = Int(set.repsText) else { return nil }
            return weight * Double(reps)
        }
        .reduce(0.0, +)
        guard currentVolume > 0 else { return nil }

        let calendar = Calendar.appCurrent
        let normalizedDate = calendar.startOfDay(for: selectedDate)
        let history = previousVolumes(
            exerciseName: entry.exerciseName,
            before: normalizedDate,
            context: context,
            unit: unit
        )

        var data = history.map { item in
            (label: axisLabel(for: item.date), value: item.volume)
        }
        data.append((label: axisLabel(for: normalizedDate), value: currentVolume))

        return SetMetrics(volumeChartData: data)
    }

    func previousVolumes(
        exerciseName: String,
        before date: Date,
        context: ModelContext,
        unit: WeightUnit
    ) -> [(date: Date, volume: Double)] {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { workout in
                workout.date < date
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let workouts = (try? context.fetch(descriptor)) ?? []
        var volumes: [(date: Date, volume: Double)] = []

        for workout in workouts {
            let volume = workout.sets
                .filter { $0.exerciseName == exerciseName }
                .reduce(0.0) { $0 + $1.volume }
            guard volume > 0 else { continue }
            volumes.append((date: workout.date, volume: unit.displayValue(fromKg: volume)))
        }

        return Array(volumes.prefix(4)).reversed()
    }

    func axisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    func muscleGroupColor(for entry: DraftExerciseEntry) -> Color {
        let key = viewModel.exercisesCatalog.first(where: { $0.name == entry.exerciseName })?.muscleGroup ?? "other"
        return MuscleGroupColor.color(for: key)
    }
}
