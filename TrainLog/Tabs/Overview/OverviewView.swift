import SwiftData
import SwiftUI

struct OverviewTabView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @State private var exercises: [ExerciseCatalog] = []
    @State private var loadFailed = false
    @State private var refreshID = UUID()
    @State private var showSettings = false
    @State private var navigationFeedbackTrigger = 0

    private let calendar = Calendar.appCurrent
    private let locale = Locale(identifier: "ja_JP")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    OverviewMuscleGrid(
                        volumes: OverviewMetrics.muscleGroupVolumesForCurrentWeek(
                            workouts: workouts,
                            exercises: exercises,
                            calendar: calendar
                        ),
                        workouts: workouts,
                        exercises: exercises,
                        locale: locale
                    )
                    .id(refreshID)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .navigationTitle("アクティビティ")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("設定")
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .background(Color(.systemGroupedBackground))
            .task {
                loadExercises()
            }
            .alert("種目リストの読み込みに失敗しました", isPresented: $loadFailed) {
                Button("OK", role: .cancel) {}
            }
            .onChange(of: workouts) { oldValue, newValue in
                refreshID = UUID()
            }
            .onChange(of: showSettings) { _, newValue in
                if newValue {
                    navigationFeedbackTrigger += 1
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: navigationFeedbackTrigger)
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

struct OverviewMuscleGrid: View {
    let volumes: [MuscleGroupVolume]
    let workouts: [Workout]
    let exercises: [ExerciseCatalog]
    let locale: Locale

    private let columns = [GridItem(.flexible(), spacing: 12)]
    @State private var navigationFeedbackTrigger = 0
    @State private var selectedMuscleGroup: MuscleGroupVolume?

    var body: some View {
        let visibleVolumes = volumes.filter { $0.muscleGroup != "other" }

        Group {
            if visibleVolumes.isEmpty || exercises.isEmpty {
                Text("種目データがありません")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(visibleVolumes) { item in
                        Button {
                            selectedMuscleGroup = item
                        } label: {
                            OverviewMuscleCard(
                                title: item.displayName,
                                monthLabel: weekRangeLabel(for: Date()),
                                volume: item.volume,
                                locale: locale,
                                titleColor: MuscleGroupColor.color(for: item.muscleGroup)
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationDestination(item: $selectedMuscleGroup) { item in
            OverviewMuscleGroupSummaryView(
                muscleGroup: item.muscleGroup,
                displayName: item.displayName,
                exercises: exercises.filter { $0.muscleGroup == item.muscleGroup },
                workouts: workouts
            )
        }
        .onChange(of: selectedMuscleGroup) { _, newValue in
            if newValue != nil {
                navigationFeedbackTrigger += 1
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: navigationFeedbackTrigger)
    }

    private func weekRangeLabel(for date: Date) -> String {
        let start = Calendar.appCurrent.startOfWeek(for: date) ?? date
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: start))週"
    }
}

struct OverviewMuscleCard: View {
    let title: String
    let monthLabel: String
    let volume: Double
    let locale: Locale
    let titleColor: Color
    var chevronColor: Color = .secondary
    @Environment(\.weightUnit) private var weightUnit

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(titleColor)
                Text(monthLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                let parts = VolumeFormatter.volumePartsWithFraction(from: volume, locale: locale, unit: weightUnit)
                ValueWithUnitText(
                    value: parts.value,
                    unit: " \(parts.unit)",
                    valueFont: .system(.title, design: .rounded).weight(.bold),
                    unitFont: .system(.subheadline, design: .rounded).weight(.semibold),
                )
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .imageScale(.small)
                .font(.system(size: 17, weight: .semibold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }
}

// MARK: - Metrics + helpers

struct VolumePoint: Identifiable {
    var id: Date { date }
    let date: Date
    let volume: Double
}

struct MuscleGroupVolume: Identifiable, Hashable {
    var id: String { muscleGroup }
    let muscleGroup: String
    let displayName: String
    let volume: Double
}

struct ExerciseVolume: Hashable {
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

    var title: String {
        switch self {
        case .week: return "1週間"
        case .month: return "1ヶ月"
        case .threeMonths: return "3ヶ月"
        case .sixMonths: return "6ヶ月"
        }
    }
}

enum OverviewMetrics {
    static func lookupMuscleGroup(for name: String, exercises: [ExerciseCatalog]) -> String {
        exercises.first(where: { $0.name == name })?.muscleGroup ?? "other"
    }

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

    static func muscleGroupVolumesForCurrentWeek(
        workouts: [Workout],
        exercises: [ExerciseCatalog],
        calendar: Calendar
    ) -> [MuscleGroupVolume] {
        guard let range = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        let lookup = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0) })
        var muscleGroups: [String] = ["chest", "shoulders", "arms", "back", "legs", "abs", "other"]
        var buckets: [String: Double] = [:]

        for workout in workouts where workout.date >= range.start && workout.date < range.end {
            for set in workout.sets {
                let muscleGroup = lookup[set.exerciseName]?.muscleGroup ?? "other"
                buckets[muscleGroup, default: 0] += set.volume
            }
        }

        // Append any additional groups discovered from data (e.g., legacy exercises)
        for key in buckets.keys where !muscleGroups.contains(key) {
            muscleGroups.append(key)
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
        let exerciseList = exercises.filter { $0.muscleGroup == muscleGroup }
        let names = Set(exerciseList.map { $0.name })
        var buckets: [String: Double] = [:]
        var legacyNames: Set<String> = []

        for workout in workouts {
            let relevantSets: [ExerciseSet] = workout.sets.filter { set in
                if muscleGroup == "other" {
                    return lookupMuscleGroup(for: set.exerciseName, exercises: exercises) == "other"
                } else {
                    return names.contains(set.exerciseName)
                }
            }
            for set in relevantSets {
                buckets[set.exerciseName, default: 0] += set.volume
                if !names.contains(set.exerciseName) {
                    legacyNames.insert(set.exerciseName)
                }
            }
        }

        var result: [ExerciseVolume] = exerciseList
            .map { ExerciseVolume(exercise: $0, volume: buckets[$0.name, default: 0]) }

        if muscleGroup == "other" {
            let legacyExercises = legacyNames.map { name in
                ExerciseCatalog(id: name, name: name, nameEn: "", muscleGroup: "other", aliases: [], equipment: "", pattern: "")
            }
            result += legacyExercises.map { ExerciseVolume(exercise: $0, volume: buckets[$0.name, default: 0]) }
        }

        return result
            .sorted { $0.volume > $1.volume }
    }

    static func exerciseVolumesForCurrentWeek(
        workouts: [Workout],
        exercises: [ExerciseCatalog],
        muscleGroup: String,
        calendar: Calendar
    ) -> [ExerciseVolume] {
        guard let range = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        let exerciseList = exercises.filter { $0.muscleGroup == muscleGroup }
        let names = Set(exerciseList.map { $0.name })
        var buckets: [String: Double] = [:]
        var legacyNames: Set<String> = []

        for workout in workouts where workout.date >= range.start && workout.date < range.end {
            let relevantSets: [ExerciseSet] = workout.sets.filter { set in
                if muscleGroup == "other" {
                    return lookupMuscleGroup(for: set.exerciseName, exercises: exercises) == "other"
                } else {
                    return names.contains(set.exerciseName)
                }
            }
            for set in relevantSets {
                buckets[set.exerciseName, default: 0] += set.volume
                if !names.contains(set.exerciseName) {
                    legacyNames.insert(set.exerciseName)
                }
            }
        }

        var result: [ExerciseVolume] = exerciseList
            .map { ExerciseVolume(exercise: $0, volume: buckets[$0.name, default: 0]) }

        if muscleGroup == "other" {
            let legacyExercises = legacyNames.map { name in
                ExerciseCatalog(id: name, name: name, nameEn: "", muscleGroup: "other", aliases: [], equipment: "", pattern: "")
            }
            result += legacyExercises.map { ExerciseVolume(exercise: $0, volume: buckets[$0.name, default: 0]) }
        }

        return result
            .sorted { $0.volume > $1.volume }
    }
    
    static func dailyMuscleGroupVolumes(
        muscleGroup: String,
        workouts: [Workout],
        exercises: [ExerciseCatalog],
        calendar: Calendar,
        days: Int
    ) -> [VolumePoint] {
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        var buckets: [Date: Double] = [:]

        for workout in workouts where workout.date >= start {
            let day = calendar.startOfDay(for: workout.date)
            for set in workout.sets {
                let group = lookupMuscleGroup(for: set.exerciseName, exercises: exercises)
                if muscleGroup == "other" {
                    guard group == "other" else { continue }
                } else {
                    guard group == muscleGroup else { continue }
                }
                buckets[day, default: 0] += set.volume
            }
        }

        let daysRange = (0..<days).compactMap { offset in
            calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today)
        }

        return daysRange.map { day in
            let normalized = calendar.startOfDay(for: day)
            return VolumePoint(date: normalized, volume: buckets[normalized, default: 0])
        }
    }

    static func weeklyMuscleGroupVolumes(
        muscleGroup: String,
        workouts: [Workout],
        exercises: [ExerciseCatalog],
        calendar: Calendar,
        weeks: Int
    ) -> [VolumePoint] {
        let today = calendar.startOfDay(for: Date())
        let currentWeekStart = calendar.startOfWeek(for: today) ?? today
        guard let start = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: currentWeekStart),
              let end = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) else { return [] }

        var buckets: [Date: Double] = [:]

        for workout in workouts where workout.date >= start && workout.date < end {
            let day = calendar.startOfDay(for: workout.date)
            guard let weekStart = calendar.startOfWeek(for: day) else { continue }
            for set in workout.sets {
                let group = lookupMuscleGroup(for: set.exerciseName, exercises: exercises)
                if muscleGroup == "other" {
                    guard group == "other" else { continue }
                } else {
                    guard group == muscleGroup else { continue }
                }
                buckets[weekStart, default: 0] += set.volume
            }
        }

        let weeksRange = (0..<weeks).compactMap { offset in
            calendar.date(byAdding: .weekOfYear, value: offset, to: start)
        }

        return weeksRange.map { weekStart in
            let normalized = calendar.startOfWeek(for: weekStart) ?? weekStart
            return VolumePoint(date: normalized, volume: buckets[normalized, default: 0])
        }
    }

    static func monthlyMuscleGroupVolumes(
        muscleGroup: String,
        workouts: [Workout],
        exercises: [ExerciseCatalog],
        calendar: Calendar,
        months: Int
    ) -> [VolumePoint] {
        let baseMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        guard let start = calendar.date(byAdding: .month, value: -(months - 1), to: baseMonth),
              let end = calendar.date(byAdding: .month, value: 1, to: baseMonth) else { return [] }

        var buckets: [Date: Double] = [:]

        for workout in workouts where workout.date >= start && workout.date < end {
            let comps = calendar.dateComponents([.year, .month], from: workout.date)
            guard let monthStart = calendar.date(from: comps) else { continue }
            for set in workout.sets {
                let group = lookupMuscleGroup(for: set.exerciseName, exercises: exercises)
                if muscleGroup == "other" {
                    guard group == "other" else { continue }
                } else {
                    guard group == muscleGroup else { continue }
                }
                buckets[monthStart, default: 0] += set.volume
            }
        }

        let monthsRange = (0..<months).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: start)
        }

        return monthsRange.map { monthStart in
            let normalized = calendar.date(from: calendar.dateComponents([.year, .month], from: monthStart)) ?? monthStart
            return VolumePoint(date: normalized, volume: buckets[normalized, default: 0])
        }
    }

    static func weeklyMuscleGroupVolumesAll(
        muscleGroup: String,
        workouts: [Workout],
        exercises: [ExerciseCatalog],
        calendar: Calendar
    ) -> [VolumePoint] {
        var buckets: [Date: Double] = [:]

        for workout in workouts {
            guard let weekStart = calendar.startOfWeek(for: workout.date) else { continue }
            for set in workout.sets {
                let group = lookupMuscleGroup(for: set.exerciseName, exercises: exercises)
                if muscleGroup == "other" {
                    guard group == "other" else { continue }
                } else {
                    guard group == muscleGroup else { continue }
                }
                buckets[weekStart, default: 0] += set.volume
            }
        }

        return buckets
            .map { VolumePoint(date: $0.key, volume: $0.value) }
            .sorted { $0.date > $1.date }
    }

    static func weeklyExerciseVolumesAll(
        for exerciseName: String,
        workouts: [Workout],
        calendar: Calendar
    ) -> [VolumePoint] {
        var buckets: [Date: Double] = [:]

        for workout in workouts {
            guard let weekStart = calendar.startOfWeek(for: workout.date) else { continue }
            let volume = workout.sets
                .filter { $0.exerciseName == exerciseName }
                .reduce(0.0) { $0 + $1.volume }
            guard volume > 0 else { continue }
            buckets[weekStart, default: 0] += volume
        }

        return buckets
            .map { VolumePoint(date: $0.key, volume: $0.value) }
            .sorted { $0.date > $1.date }
    }

    static func exerciseChartSeries(
        for exerciseName: String,
        workouts: [Workout],
        period: ExerciseChartPeriod,
        calendar: Calendar
    ) -> [VolumePoint] {
        switch period {
        case .day:
            let today = calendar.startOfDay(for: Date())
            guard let start = calendar.date(byAdding: .day, value: -6, to: today),
                  let end = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
            var buckets: [Date: Double] = [:]

            for workout in workouts where workout.date >= start && workout.date < end {
                let day = calendar.startOfDay(for: workout.date)
                let volume = workout.sets
                    .filter { $0.exerciseName == exerciseName }
                    .reduce(0.0) { $0 + $1.volume }
                buckets[day, default: 0] += volume
            }

            let days = (0..<7).compactMap { offset in
                calendar.date(byAdding: .day, value: -(6 - offset), to: today)
            }

            return days.map { day in
                let normalized = calendar.startOfDay(for: day)
                return VolumePoint(date: normalized, volume: buckets[normalized, default: 0])
            }
        case .week:
            let today = calendar.startOfDay(for: Date())
            guard let currentWeekStart = calendar.startOfWeek(for: today),
                  let start = calendar.date(byAdding: .weekOfYear, value: -4, to: currentWeekStart),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) else { return [] }

            var buckets: [Date: Double] = [:]

            for workout in workouts where workout.date >= start && workout.date < end {
                guard let weekStart = calendar.startOfWeek(for: workout.date) else { continue }
                let volume = workout.sets
                    .filter { $0.exerciseName == exerciseName }
                    .reduce(0.0) { $0 + $1.volume }
                buckets[weekStart, default: 0] += volume
            }

            let weeks = (0..<5).compactMap { offset in
                calendar.date(byAdding: .weekOfYear, value: offset, to: start)
            }

            return weeks.map { weekStart in
                let normalized = calendar.startOfWeek(for: weekStart) ?? weekStart
                return VolumePoint(date: normalized, volume: buckets[normalized, default: 0])
            }
        case .month:
            let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
            guard let start = calendar.date(byAdding: .month, value: -5, to: currentMonthStart),
                  let end = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) else { return [] }

            var buckets: [Date: Double] = [:]

            for workout in workouts where workout.date >= start && workout.date < end {
                let comps = calendar.dateComponents([.year, .month], from: workout.date)
                guard let monthStart = calendar.date(from: comps) else { continue }
                let volume = workout.sets
                    .filter { $0.exerciseName == exerciseName }
                    .reduce(0.0) { $0 + $1.volume }
                buckets[monthStart, default: 0] += volume
            }

            let months = (0..<6).compactMap { offset in
                calendar.date(byAdding: .month, value: offset, to: start)
            }

            return months.map { monthStart in
                let normalized = calendar.date(from: calendar.dateComponents([.year, .month], from: monthStart)) ?? monthStart
                return VolumePoint(date: normalized, volume: buckets[normalized, default: 0])
            }
        }
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
            case .threeMonths, .sixMonths:
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
    
    static func dailyVolumes(
        for exerciseName: String,
        workouts: [Workout],
        period: ExerciseChartPeriod,
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

    static func dailyVolumesAll(
        for exerciseName: String,
        workouts: [Workout],
        calendar: Calendar
    ) -> [DailyVolume] {
        var buckets: [Date: Double] = [:]

        for workout in workouts {
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

enum VolumeFormatter {
    static func string(from volume: Double, locale: Locale, unit: WeightUnit = .kg) -> String {
        let text = unit.formattedValue(fromKg: volume, locale: locale, maximumFractionDigits: 0)
        return "\(text) \(unit.unitLabel)"
    }

    static func volumeParts(from volume: Double, locale: Locale, unit: WeightUnit = .kg) -> (value: String, unit: String) {
        let text = unit.formattedValue(fromKg: volume, locale: locale, maximumFractionDigits: 0)
        return (text, unit.unitLabel)
    }

    static func stringWithFraction(from volume: Double, locale: Locale, unit: WeightUnit = .kg) -> String {
        let text = unit.formattedValue(fromKg: volume, locale: locale, maximumFractionDigits: 3)
        return "\(text) \(unit.unitLabel)"
    }

    static func volumePartsWithFraction(from volume: Double, locale: Locale, unit: WeightUnit = .kg) -> (value: String, unit: String) {
        let text = unit.formattedValue(fromKg: volume, locale: locale, maximumFractionDigits: 3)
        return (text, unit.unitLabel)
    }

    static func weightString(from weight: Double, locale: Locale, unit: WeightUnit = .kg) -> String {
        let text = unit.formattedValue(fromKg: weight, locale: locale, maximumFractionDigits: 3)
        return "\(text)\(unit.unitLabel)"
    }

    static func weightParts(from weight: Double, locale: Locale, unit: WeightUnit = .kg) -> (value: String, unit: String) {
        let text = unit.formattedValue(fromKg: weight, locale: locale, maximumFractionDigits: 3)
        return (text, unit.unitLabel)
    }
}

extension OverviewPeriod {
    func dateRange(calendar: Calendar) -> DateInterval {
        let base = calendar.startOfDay(for: Date())
        let end: Date
        let start: Date
        switch self {
        case .week:
            let weekStart = calendar.startOfWeek(for: base) ?? base
            start = weekStart
            end = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? base
        case .month:
            let currentWeekStart = calendar.startOfWeek(for: base) ?? base
            start = calendar.date(byAdding: .weekOfYear, value: -7, to: currentWeekStart) ?? currentWeekStart
            end = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? currentWeekStart
        case .threeMonths:
            let currentStart = calendar.date(from: calendar.dateComponents([.year, .month], from: base)) ?? base
            start = calendar.date(byAdding: .month, value: -2, to: currentStart) ?? currentStart
            end = calendar.date(byAdding: .month, value: 1, to: currentStart) ?? currentStart
        case .sixMonths:
            let currentStart = calendar.date(from: calendar.dateComponents([.year, .month], from: base)) ?? base
            start = calendar.date(byAdding: .month, value: -5, to: currentStart) ?? currentStart
            end = calendar.date(byAdding: .month, value: 1, to: currentStart) ?? currentStart
        }
        return DateInterval(start: start, end: end)
    }
}

extension ExerciseChartPeriod {
    func dateRange(calendar: Calendar) -> DateInterval {
        let base = calendar.startOfDay(for: Date())
        let start: Date
        let end: Date
        switch self {
        case .day:
            start = calendar.date(byAdding: .day, value: -6, to: base) ?? base
            end = calendar.date(byAdding: .day, value: 1, to: base) ?? base
        case .week:
            let currentWeekStart = calendar.startOfWeek(for: base) ?? base
            start = calendar.date(byAdding: .weekOfYear, value: -4, to: currentWeekStart) ?? currentWeekStart
            end = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? currentWeekStart
        case .month:
            let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: base)) ?? base
            start = calendar.date(byAdding: .month, value: -5, to: currentMonthStart) ?? currentMonthStart
            end = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) ?? currentMonthStart
        }
        return DateInterval(start: start, end: end)
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date? {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps)
    }

    static var appCurrent: Calendar {
        // OS設定（地域・暦法・週開始曜日・タイムゾーン）に追従
        Calendar.autoupdatingCurrent
    }

    static var mondayStart: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        calendar.timeZone = Calendar.current.timeZone
        return calendar
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
