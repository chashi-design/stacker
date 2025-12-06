import Charts
import SwiftData
import SwiftUI

struct OverviewTabView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @State private var exercises: [ExerciseCatalog] = []
    @State private var loadFailed = false

    private let calendar = Calendar.current
    private let locale = Locale(identifier: "ja_JP")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    OverviewVolumeCard(
                        title: "ボリューム",
                        series: OverviewMetrics.volumeByDayForCurrentMonth(workouts: workouts, calendar: calendar)
                    )

                    OverviewMuscleGrid(
                        volumes: OverviewMetrics.muscleGroupVolumesForCurrentMonth(
                            workouts: workouts,
                            exercises: exercises,
                            calendar: calendar
                        ),
                        workouts: workouts,
                        exercises: exercises,
                        locale: locale
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .navigationTitle("概要")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
            .task {
                loadExercises()
            }
            .alert("種目リストの読み込みに失敗しました", isPresented: $loadFailed) {
                Button("OK", role: .cancel) {}
            }
        }
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

// MARK: - Top screen components

struct OverviewVolumeCard: View {
    let title: String
    let series: [VolumePoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            if series.isEmpty {
                Text("今月の記録がありません")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            } else {
                Chart(series) { item in
                    BarMark(
                        x: .value("日付", item.date),
                        y: .value("ボリューム(kg)", item.volume)
                    )
                }
                .chartXAxis {
                    AxisMarks()
                }
                .chartYAxisLabel("kg")
                .frame(height: 220)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }
}

struct OverviewMuscleGrid: View {
    let volumes: [MuscleGroupVolume]
    let workouts: [Workout]
    let exercises: [ExerciseCatalog]
    let locale: Locale

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        if volumes.isEmpty || exercises.isEmpty {
            Text("種目データがありません")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(volumes) { item in
                    NavigationLink {
                        OverviewPartsView(
                            muscleGroup: item.muscleGroup,
                            displayName: item.displayName,
                            exercises: exercises.filter { $0.muscleGroup == item.muscleGroup },
                            workouts: workouts
                        )
                    } label: {
                        OverviewMuscleCard(
                            title: item.displayName,
                            monthLabel: "今月",
                            volume: item.volume,
                            locale: locale
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct OverviewMuscleCard: View {
    let title: String
    let monthLabel: String
    let volume: Double
    let locale: Locale
    var chevronColor: Color = .secondary

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(monthLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(VolumeFormatter.string(from: volume, locale: locale))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .imageScale(.small)
                .font(.system(size: 14, weight: .bold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }
}

// MARK: - Parts screen

struct OverviewPartsView: View {
    let muscleGroup: String
    let displayName: String
    let exercises: [ExerciseCatalog]
    let workouts: [Workout]

    @State private var filter: PartsFilter = .all
    private let calendar = Calendar.current
    private let locale = Locale(identifier: "ja_JP")

    private var exerciseVolumes: [ExerciseVolume] {
        OverviewMetrics.exerciseVolumesForCurrentMonth(
            workouts: workouts,
            exercises: exercises,
            muscleGroup: muscleGroup,
            calendar: calendar
        )
    }

    var body: some View {
        List {
            Section {
                Picker("表示", selection: $filter) {
                    ForEach(PartsFilter.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                ForEach(filteredExercises, id: \.exercise.id) { item in
                    NavigationLink {
                        OverviewExerciseDetailView(
                            exercise: item.exercise,
                            workouts: workouts
                        )
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.exercise.name)
                                    .font(.headline)
                                Text("今月")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(VolumeFormatter.string(from: item.volume, locale: locale))
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                            .padding(.vertical, 6)
                        }
                    }
                if filteredExercises.isEmpty {
                    Text("対象の種目がありません")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filteredExercises: [ExerciseVolume] {
        switch filter {
        case .all:
            return exerciseVolumes
        case .completed:
            return exerciseVolumes.filter { $0.volume > 0 }
        }
    }
}

enum PartsFilter: CaseIterable {
    case all
    case completed

    var title: String {
        switch self {
        case .all: return "すべて"
        case .completed: return "実施済み"
        }
    }
}

// MARK: - Exercise detail (timeline)

struct OverviewExerciseDetailView: View {
    let exercise: ExerciseCatalog
    let workouts: [Workout]

    @State private var period: OverviewPeriod = .week
    private let calendar = Calendar.current
    private let locale = Locale(identifier: "ja_JP")

    var body: some View {
        List {
            Section {
                Picker("期間", selection: $period) {
                    ForEach(OverviewPeriod.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                OverviewVolumeCard(
                    title: "ボリューム",
                    series: OverviewMetrics.timeline(
                        for: exercise.name,
                        workouts: workouts,
                        period: period,
                        calendar: calendar
                    )
                )
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            ForEach(sectionedDailyVolumes) { section in
                Section(section.monthLabel) {
                    ForEach(section.items) { item in
                        NavigationLink {
                            OverviewExerciseDayDetailView(
                                exerciseName: exercise.name,
                                date: item.date,
                                workouts: workouts
                            )
                        } label: {
                            HStack {
                                Text(dayLabel(for: item.date))
                                Spacer()
                                Text(VolumeFormatter.string(from: item.volume, locale: locale))
                                    .font(.headline)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            if sectionedDailyVolumes.isEmpty {
                Text("期間内の記録がありません")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sectionedDailyVolumes: [DailyVolumeSection] {
        let days = OverviewMetrics.dailyVolumes(
            for: exercise.name,
            workouts: workouts,
            period: period,
            calendar: calendar
        )
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "yyyy年M月"

        let grouped = Dictionary(grouping: days) { day in
            formatter.string(from: day.date)
        }

        return grouped
            .map { key, values in
                DailyVolumeSection(
                    id: key,
                    monthLabel: key,
                    items: values.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.items.first?.date ?? Date.distantFuture > $1.items.first?.date ?? Date.distantFuture }
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

// MARK: - Day detail

struct OverviewExerciseDayDetailView: View {
    let exerciseName: String
    let date: Date
    let workouts: [Workout]

    private let calendar = Calendar.current
    private let locale = Locale(identifier: "ja_JP")

    private var sets: [ExerciseSet] {
        OverviewMetrics.sets(
            for: exerciseName,
            on: date,
            workouts: workouts,
            calendar: calendar
        )
    }

    var body: some View {
        List {
            if sets.isEmpty {
                Text("この日の記録はありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    HStack {
                        Text("\(index + 1)セット")
                        Spacer()
                        Text("\(Int(set.weight))kg")
                        Spacer()
                        Text("\(set.reps)回")
                    }
                }
            }
        }
        .navigationTitle(dayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

// MARK: - Metrics + helpers

struct VolumePoint: Identifiable {
    var id: Date { date }
    let date: Date
    let volume: Double
}

struct MuscleGroupVolume: Identifiable {
    var id: String { muscleGroup }
    let muscleGroup: String
    let displayName: String
    let volume: Double
}

struct ExerciseVolume {
    let exercise: ExerciseCatalog
    let volume: Double
}

struct DailyVolume: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Double
}

struct DailyVolumeSection: Identifiable {
    let id: String
    let monthLabel: String
    let items: [DailyVolume]
}

enum OverviewPeriod: CaseIterable {
    case week
    case month
    case threeMonths
    case sixMonths
    case year

    var title: String {
        switch self {
        case .week: return "1週間"
        case .month: return "1ヶ月"
        case .threeMonths: return "3ヶ月"
        case .sixMonths: return "6ヶ月"
        case .year: return "1年"
        }
    }
}

enum OverviewMetrics {
    static func volumeByDayForCurrentMonth(workouts: [Workout], calendar: Calendar) -> [VolumePoint] {
        guard let range = calendar.dateInterval(of: .month, for: Date()) else { return [] }
        var buckets: [Date: Double] = [:]

        for workout in workouts where workout.date >= range.start && workout.date < range.end {
            let day = calendar.startOfDay(for: workout.date)
            let volume = workout.sets.reduce(0.0) { $0 + $1.volume }
            buckets[day, default: 0] += volume
        }

        return buckets
            .map { VolumePoint(date: $0.key, volume: $0.value) }
            .sorted { $0.date < $1.date }
    }

    static func muscleGroupVolumesForCurrentMonth(
        workouts: [Workout],
        exercises: [ExerciseCatalog],
        calendar: Calendar
    ) -> [MuscleGroupVolume] {
        guard let range = calendar.dateInterval(of: .month, for: Date()) else { return [] }
        let lookup = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0) })
        let muscleGroups: [String] = ["chest", "shoulders", "arms", "back", "legs", "abs"]
        var buckets: [String: Double] = [:]

        for workout in workouts where workout.date >= range.start && workout.date < range.end {
            for set in workout.sets {
                guard let catalog = lookup[set.exerciseName] else { continue }
                buckets[catalog.muscleGroup, default: 0] += set.volume
            }
        }

        return muscleGroups
            .map { key in
                MuscleGroupVolume(
                    muscleGroup: key,
                    displayName: MuscleGroupLabel.label(for: key),
                    volume: buckets[key, default: 0]
                )
            }
            .filter { _ in true }
    }

    static func exerciseVolumesForCurrentMonth(
        workouts: [Workout],
        exercises: [ExerciseCatalog],
        muscleGroup: String,
        calendar: Calendar
    ) -> [ExerciseVolume] {
        guard let range = calendar.dateInterval(of: .month, for: Date()) else { return [] }
        let exerciseList = exercises.filter { $0.muscleGroup == muscleGroup }
        let names = Set(exerciseList.map { $0.name })
        var buckets: [String: Double] = [:]

        for workout in workouts where workout.date >= range.start && workout.date < range.end {
            let relevantSets = workout.sets.filter { names.contains($0.exerciseName) }
            for set in relevantSets {
                buckets[set.exerciseName, default: 0] += set.volume
            }
        }

        return exerciseList
            .map { ExerciseVolume(exercise: $0, volume: buckets[$0.name, default: 0]) }
            .sorted { $0.volume > $1.volume }
    }

    static func timeline(
        for exerciseName: String,
        workouts: [Workout],
        period: OverviewPeriod,
        calendar: Calendar
    ) -> [VolumePoint] {
        let range = period.dateRange(calendar: calendar)
        var buckets: [Date: Double] = [:]

        for workout in workouts where workout.date >= range.start && workout.date < range.end {
            let date = workout.date
            let volume = workout.sets
                .filter { $0.exerciseName == exerciseName }
                .reduce(0.0) { $0 + $1.volume }
            guard volume > 0 else { continue }

            let bucketDate: Date
            switch period {
            case .week, .month:
                bucketDate = calendar.startOfDay(for: date)
            case .threeMonths:
                bucketDate = calendar.startOfWeek(for: date) ?? calendar.startOfDay(for: date)
            case .sixMonths, .year:
                let comps = calendar.dateComponents([.year, .month], from: date)
                bucketDate = calendar.date(from: comps) ?? calendar.startOfDay(for: date)
            }

            buckets[bucketDate, default: 0] += volume
        }

        return buckets
            .map { VolumePoint(date: $0.key, volume: $0.value) }
            .sorted { $0.date < $1.date }
    }

    static func dailyVolumes(
        for exerciseName: String,
        workouts: [Workout],
        period: OverviewPeriod,
        calendar: Calendar
    ) -> [DailyVolume] {
        let range = period.dateRange(calendar: calendar)
        var buckets: [Date: Double] = [:]

        for workout in workouts where workout.date >= range.start && workout.date < range.end {
            let day = calendar.startOfDay(for: workout.date)
            let volume = workout.sets
                .filter { $0.exerciseName == exerciseName }
                .reduce(0.0) { $0 + $1.volume }
            guard volume > 0 else { continue }
            buckets[day, default: 0] += volume
        }

        return buckets
            .map { DailyVolume(date: $0.key, volume: $0.value) }
            .sorted { $0.date > $1.date }
    }

    static func sets(
        for exerciseName: String,
        on date: Date,
        workouts: [Workout],
        calendar: Calendar
    ) -> [ExerciseSet] {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let candidates = workouts.filter { $0.date >= start && $0.date < end }
        let allSets = candidates
            .flatMap { workout in
                workout.sets.filter { $0.exerciseName == exerciseName }
            }

        return allSets.sorted { $0.createdAt < $1.createdAt }
    }
}

// MARK: - Utilities

enum MuscleGroupLabel {
    static func label(for key: String) -> String {
        labels[key, default: key]
    }

    private static let labels: [String: String] = [
        "chest": "胸",
        "back": "背中",
        "shoulders": "肩",
        "arms": "腕",
        "legs": "脚",
        "abs": "腹筋",
    ]
}

enum VolumeFormatter {
    static func string(from volume: Double, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.maximumFractionDigits = 0
        let number = NSNumber(value: volume)
        let text = formatter.string(from: number) ?? "0"
        return "\(text) kg"
    }
}

extension OverviewPeriod {
    func dateRange(calendar: Calendar) -> DateInterval {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        let start: Date
        switch self {
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
        case .month:
            start = calendar.date(byAdding: .month, value: -1, to: end) ?? end
        case .threeMonths:
            start = calendar.date(byAdding: .month, value: -3, to: end) ?? end
        case .sixMonths:
            start = calendar.date(byAdding: .month, value: -6, to: end) ?? end
        case .year:
            start = calendar.date(byAdding: .year, value: -1, to: end) ?? end
        }
        return DateInterval(start: start, end: end)
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date? {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Workout.self,
        ExerciseSet.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return NavigationStack {
        OverviewTabView()
    }
    .modelContainer(container)
}
