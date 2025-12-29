import SwiftData
import SwiftUI
import UIKit

// セット編集画面
struct SetEditorView: View {
    @ObservedObject var viewModel: LogViewModel
    let exerciseID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.weightUnit) private var weightUnit
    @Environment(\.openURL) private var openURL
    @State private var fieldHapticTrigger = 0
    @State private var addSetHapticTrigger = 0
    @State private var deleteSetHapticTrigger = 0
    @FocusState private var focusedField: Field?
    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }
    private var strings: SetEditorStrings {
        SetEditorStrings(isJapanese: isJapaneseLocale)
    }
 
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
                            strings.weightPlaceholder(unit: weightUnit.unitLabel),
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
                            strings.repsPlaceholder,
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
                    Label(strings.addSetTitle, systemImage: "plus.circle.fill")
                }
                .sensoryFeedback(.impact(weight: .light), trigger: addSetHapticTrigger)

                if let metrics = metrics(for: entry, context: context, selectedDate: viewModel.selectedDate, unit: weightUnit) {
                    Section(strings.volumeTrendSectionTitle) {
                        ExerciseVolumeChart(
                            data: metrics.volumeChartData,
                            barColor: muscleGroupColor(for: entry),
                            animateOnAppear: false,
                            animateOnTrigger: false,
                            animationTrigger: viewModel.draftRevision,
                            yValueLabel: strings.volumeLabel(unit: weightUnit.unitLabel),
                            yAxisLabel: weightUnit.unitLabel
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section(strings.volumeTrendSectionTitle) {
                        Text(strings.volumeTrendEmptyMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentMargins(.top, 4, for: .scrollContent)
            .onChange(of: viewModel.draftRevision) { _, _ in
                if !viewModel.isSyncingDrafts {
                    viewModel.saveWorkout(context: context, unit: weightUnit)
                }
            }
            .onChange(of: focusedField) { _, newValue in
                if newValue != nil {
                    fieldHapticTrigger += 1
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: fieldHapticTrigger)
            .navigationTitle(displayName(for: entry.exerciseId))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HapticButton {
                        openYouTubeSearch(exerciseId: entry.exerciseId)
                    } label: {
                        Label(strings.youtubeSearchTitle, systemImage: "play.rectangle")
                    }
                }
            }
        } else {
            VStack(spacing: 12) {
                Text(strings.missingEntryMessage)
                    .foregroundStyle(.secondary)
                Button(strings.closeTitle) { dismiss() }
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
            exerciseId: entry.exerciseId,
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
        exerciseId: String,
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
                .filter { $0.exerciseId == exerciseId }
                .reduce(0.0) { $0 + $1.volume }
            guard volume > 0 else { continue }
            volumes.append((date: workout.date, volume: unit.displayValue(fromKg: volume)))
        }

        return Array(volumes.prefix(4)).reversed()
    }

    func axisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = strings.locale
        formatter.dateFormat = strings.axisDateFormat
        return formatter.string(from: date)
    }

    func muscleGroupColor(for entry: DraftExerciseEntry) -> Color {
        let key = viewModel.exercisesCatalog.first(where: { $0.id == entry.exerciseId })?.muscleGroup ?? "other"
        return MuscleGroupColor.color(for: key)
    }

    func displayName(for exerciseId: String) -> String {
        viewModel.displayName(for: exerciseId, isJapanese: isJapaneseLocale)
    }

    func openYouTubeSearch(exerciseId: String) {
        guard let vndURL = youtubeVndSearchURL(exerciseId: exerciseId),
              let appURL = youtubeAppSearchURL(exerciseId: exerciseId),
              let webURL = youtubeWebSearchURL(exerciseId: exerciseId) else { return }

        if UIApplication.shared.canOpenURL(appURL) {
            openURL(appURL)
        } else if UIApplication.shared.canOpenURL(vndURL) {
            openURL(vndURL)
        } else {
            openURL(webURL)
        }
    }

    func youtubeAppSearchURL(exerciseId: String) -> URL? {
        var components = URLComponents()
        components.scheme = "youtube"
        components.host = "search"
        components.queryItems = [
            URLQueryItem(name: "query", value: displayName(for: exerciseId))
        ]
        return components.url
    }

    func youtubeVndSearchURL(exerciseId: String) -> URL? {
        var components = URLComponents()
        components.scheme = "vnd.youtube"
        components.host = "search"
        components.queryItems = [
            URLQueryItem(name: "query", value: displayName(for: exerciseId))
        ]
        return components.url
    }

    func youtubeWebSearchURL(exerciseId: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.youtube.com"
        components.path = "/results"
        components.queryItems = [
            URLQueryItem(name: "search_query", value: displayName(for: exerciseId))
        ]
        return components.url
    }
}

private struct SetEditorStrings {
    let isJapanese: Bool

    var locale: Locale { isJapanese ? Locale(identifier: "ja_JP") : Locale(identifier: "en_US") }
    var repsPlaceholder: String { isJapanese ? "レップ数" : "Reps" }
    var addSetTitle: String { isJapanese ? "セットを追加" : "Add Set" }
    var volumeTrendSectionTitle: String { isJapanese ? "筋ボリューム推移" : "Volume Trend" }
    var volumeTrendEmptyMessage: String {
        isJapanese ? "有効なセットを入力すると指標を表示します" : "Enter valid sets to show metrics."
    }
    var missingEntryMessage: String {
        isJapanese ? "編集対象が見つかりませんでした" : "Entry not found."
    }
    var closeTitle: String { isJapanese ? "閉じる" : "Close" }
    var youtubeSearchTitle: String { isJapanese ? "YouTubeで検索" : "Search YouTube" }
    var axisDateFormat: String { "M/d" }
    func weightPlaceholder(unit: String) -> String {
        isJapanese ? "重量(\(unit))" : "Weight (\(unit))"
    }
    func volumeLabel(unit: String) -> String {
        isJapanese ? "ボリューム(\(unit))" : "Volume (\(unit))"
    }
}
