import SwiftData
import SwiftUI

struct OverviewTabView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @State private var exercises: [ExerciseCatalog] = []
    @State private var loadFailed = false
    @State private var isLoadingExercises = true
    @State private var refreshID = UUID()
    @State private var showSettings = false
    @State private var navigationFeedbackTrigger = 0

    private let calendar = Calendar.appCurrent
    private let locale = Locale(identifier: "ja_JP")
    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }
    private var strings: OverviewStrings {
        OverviewStrings(isJapanese: isJapaneseLocale)
    }

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
                        isLoadingExercises: isLoadingExercises,
                        locale: locale,
                        calendar: calendar
                    )
                    .id(refreshID)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .navigationTitle(strings.navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(strings.settingsLabel)
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
            .alert(strings.loadFailedMessage, isPresented: $loadFailed) {
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
        guard exercises.isEmpty else {
            isLoadingExercises = false
            return
        }
        isLoadingExercises = true
        do {
            exercises = try ExerciseLoader.loadFromBundle()
        } catch {
            loadFailed = true
        }
        isLoadingExercises = false
    }

}

// MARK: - Top screen components

struct OverviewMuscleGrid: View {
    let volumes: [MuscleGroupVolume]
    let workouts: [Workout]
    let exercises: [ExerciseCatalog]
    let isLoadingExercises: Bool
    let locale: Locale
    let calendar: Calendar

    private let columns = [GridItem(.flexible(), spacing: 12)]
    @State private var navigationFeedbackTrigger = 0
    @State private var selectedMuscleGroup: MuscleGroupVolume?
    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }
    private var strings: OverviewStrings {
        OverviewStrings(isJapanese: isJapaneseLocale)
    }

    var body: some View {
        let visibleVolumes = volumes.filter { $0.muscleGroup != "other" }

        Group {
            if isLoadingExercises {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if visibleVolumes.isEmpty || exercises.isEmpty {
                Text(strings.noExerciseData)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(visibleVolumes) { item in
                        let trackingType = OverviewMetrics.trackingType(
                            for: item.muscleGroup,
                            segment: item.segment
                        )
                        let weeklyPoints = OverviewMetrics.weeklyMuscleGroupVolumesForSegment(
                            muscleGroup: item.muscleGroup,
                            segment: item.segment,
                            workouts: workouts,
                            exercises: exercises,
                            calendar: calendar,
                            weeks: 5,
                            trackingType: trackingType
                        )
                        Button {
                            selectedMuscleGroup = item
                        } label: {
                            OverviewMuscleCard(
                                title: item.displayName,
                                monthLabel: weekRangeLabel(for: Date()),
                                volume: item.volume,
                                trackingType: trackingType,
                                locale: locale,
                                titleColor: MuscleGroupColor.color(for: item.muscleGroup),
                                weeklyPoints: weeklyPoints
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
            let filteredExercises = filteredExercises(for: item)
            OverviewMuscleGroupSummaryView(
                muscleGroup: item.muscleGroup,
                segment: item.segment,
                displayName: item.displayName,
                exercises: filteredExercises,
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
        let start = calendar.startOfWeek(for: date) ?? date
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "M/d"
        return strings.weekRangeLabel(base: formatter.string(from: start))
    }

    private func filteredExercises(for item: MuscleGroupVolume) -> [ExerciseCatalog] {
        let base = exercises.filter { $0.muscleGroup == item.muscleGroup }
        switch item.segment {
        case .bodyweight:
            return base.filter { $0.equipment == "bodyweight" }
        case .standard:
            return base.filter { $0.equipment != "bodyweight" }
        case .all:
            return base
        }
    }
}

struct OverviewMuscleCard: View {
    let title: String
    let monthLabel: String
    let volume: Double
    let trackingType: ExerciseTrackingType
    let locale: Locale
    let titleColor: Color
    let weeklyPoints: [VolumePoint]
    var chevronColor: Color = .secondary
    @Environment(\.weightUnit) private var weightUnit

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(titleColor)
                Text(monthLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                let parts = VolumeFormatter.metricParts(
                    from: volume,
                    trackingType: trackingType,
                    locale: locale,
                    unit: weightUnit
                )
                if trackingType == .durationOnly {
                    durationValueText(seconds: volume)
                } else {
                    let unitText = parts.unit.isEmpty ? "" : " \(parts.unit)"
                    ValueWithUnitText(
                        value: parts.value,
                        unit: unitText,
                        valueFont: .system(.title, design: .rounded).weight(.bold),
                        unitFont: .system(.subheadline, design: .rounded).weight(.semibold),
                    )
                }
            }
            Spacer()
            WeeklyMiniChartView(
                points: weeklyPoints,
                barColor: titleColor
            )
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

    private func durationValueText(seconds: Double) -> some View {
        let totalMinutes = max(0, Int((seconds / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let isJapanese = locale.identifier.hasPrefix("ja")
        let valueFont = Font.system(.title, design: .rounded).weight(.bold)
        let unitFont = Font.system(.subheadline, design: .rounded).weight(.semibold)

        let hourUnit = isJapanese ? "時間" : "h "
        let minuteUnit = isJapanese ? "分" : "m"
        let valueText = "\(hours)\(hourUnit)\(minutes)\(minuteUnit)"
        var attributed = AttributedString(valueText)

        if let range = attributed.range(of: "\(hours)") {
            attributed[range].font = valueFont
            attributed[range].foregroundColor = .primary
        }
        if let range = attributed.range(of: hourUnit) {
            attributed[range].font = unitFont
            attributed[range].foregroundColor = .secondary
        }
        if let range = attributed.range(of: "\(minutes)") {
            attributed[range].font = valueFont
            attributed[range].foregroundColor = .primary
        }
        if let range = attributed.range(of: minuteUnit) {
            attributed[range].font = unitFont
            attributed[range].foregroundColor = .secondary
        }

        return Text(attributed)
    }
}

// MARK: - Metrics + helpers

struct VolumePoint: Identifiable {
    var id: Date { date }
    let date: Date
    let volume: Double
}

enum MuscleGroupSegment: String, Hashable {
    case all
    case standard
    case bodyweight
}

struct MuscleGroupVolume: Identifiable, Hashable {
    var id: String { "\(muscleGroup)-\(segment.rawValue)" }
    let muscleGroup: String
    let segment: MuscleGroupSegment
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

private struct MuscleGroupBucketKey: Hashable {
    let muscleGroup: String
    let segment: MuscleGroupSegment
}

private struct MuscleGroupCardDefinition: Hashable {
    let muscleGroup: String
    let segment: MuscleGroupSegment
}

enum OverviewPeriod: CaseIterable {
    case week
    case month
    case threeMonths
    case sixMonths

    var title: String {
        let isJapanese = Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
        switch self {
        case .week: return isJapanese ? "1週間" : "1 Week"
        case .month: return isJapanese ? "1ヶ月" : "1 Month"
        case .threeMonths: return isJapanese ? "3ヶ月" : "3 Months"
        case .sixMonths: return isJapanese ? "6ヶ月" : "6 Months"
        }
    }
}

enum OverviewMetrics {
    static let splitMuscleGroups: Set<String> = ["chest", "shoulders", "arms", "back", "legs"]

    static func resolveExercise(for set: ExerciseSet, exercises: [ExerciseCatalog]) -> ExerciseCatalog? {
        exercises.first { $0.id == set.exerciseId }
    }

    static func lookupMuscleGroup(for set: ExerciseSet, exercises: [ExerciseCatalog]) -> String {
        resolveExercise(for: set, exercises: exercises)?.muscleGroup ?? "other"
    }

    static func exerciseKey(for set: ExerciseSet) -> String {
        set.exerciseId
    }

    static func matches(set: ExerciseSet, exerciseId: String) -> Bool {
        set.exerciseId == exerciseId
    }

    static func trackingType(for muscleGroup: String) -> ExerciseTrackingType {
        switch muscleGroup {
        case "abs":
            return .repsOnly
        case "cardio":
            return .durationOnly
        default:
            return .weightReps
        }
    }

    static func trackingType(for muscleGroup: String, segment: MuscleGroupSegment) -> ExerciseTrackingType {
        if segment == .bodyweight {
            return .repsOnly
        }
        return trackingType(for: muscleGroup)
    }

    static func segment(for exercise: ExerciseCatalog) -> MuscleGroupSegment {
        guard splitMuscleGroups.contains(exercise.muscleGroup) else { return .all }
        return exercise.equipment == "bodyweight" ? .bodyweight : .standard
    }

    static func displayName(for muscleGroup: String, segment: MuscleGroupSegment) -> String {
        let base = MuscleGroupLabel.label(for: muscleGroup)
        guard segment != .all, splitMuscleGroups.contains(muscleGroup) else { return base }
        let isJapanese = Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
        let suffix: String
        switch segment {
        case .bodyweight:
            suffix = isJapanese ? "自重" : "Bodyweight"
        case .standard:
            suffix = isJapanese ? "ウエイト" : "Freeweight/Machine"
        case .all:
            return base
        }
        return "\(base): \(suffix)"
    }

    static func metricValue(for set: ExerciseSet, trackingType: ExerciseTrackingType) -> Double {
        switch trackingType {
        case .weightReps:
            return set.volume
        case .repsOnly:
            return Double(set.reps)
        case .durationOnly:
            return set.durationSeconds ?? 0
        }
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
        let splitGroups = ["chest", "shoulders", "arms", "back", "legs"]
        let baseGroups = ["abs", "cardio", "other"]
        let defaultDefinitions: [MuscleGroupCardDefinition] = splitGroups.flatMap { group in
            [
                MuscleGroupCardDefinition(muscleGroup: group, segment: .standard),
                MuscleGroupCardDefinition(muscleGroup: group, segment: .bodyweight)
            ]
        } + baseGroups.map { MuscleGroupCardDefinition(muscleGroup: $0, segment: .all) }

        var buckets: [MuscleGroupBucketKey: Double] = [:]

        for workout in workouts where workout.date >= range.start && workout.date < range.end {
            for set in workout.sets {
                if let exercise = resolveExercise(for: set, exercises: exercises) {
                    let muscleGroup = exercise.muscleGroup
                    let segment = segment(for: exercise)
                    let key = MuscleGroupBucketKey(muscleGroup: muscleGroup, segment: segment)
                    let metric = metricValue(
                        for: set,
                        trackingType: trackingType(for: muscleGroup, segment: segment)
                    )
                    buckets[key, default: 0] += metric
                } else {
                    let key = MuscleGroupBucketKey(muscleGroup: "other", segment: .all)
                    buckets[key, default: 0] += metricValue(for: set, trackingType: trackingType(for: "other"))
                }
            }
        }

        var definitions = defaultDefinitions
        let knownKeys = Set(definitions.map {
            MuscleGroupBucketKey(muscleGroup: $0.muscleGroup, segment: $0.segment)
        })
        for key in buckets.keys where !knownKeys.contains(key) {
            definitions.append(MuscleGroupCardDefinition(muscleGroup: key.muscleGroup, segment: key.segment))
        }

        return definitions.map { definition in
            let key = MuscleGroupBucketKey(muscleGroup: definition.muscleGroup, segment: definition.segment)
            return MuscleGroupVolume(
                muscleGroup: definition.muscleGroup,
                segment: definition.segment,
                displayName: displayName(for: definition.muscleGroup, segment: definition.segment),
                volume: buckets[key, default: 0]
            )
        }
    }

    static func exerciseVolumesForCurrentMonth(
        workouts: [Workout],
        exercises: [ExerciseCatalog],
        muscleGroup: String,
        calendar: Calendar
    ) -> [ExerciseVolume] {
        let exerciseList = exercises.filter { $0.muscleGroup == muscleGroup }
        let trackingLookup = Dictionary(uniqueKeysWithValues: exerciseList.map { ($0.id, $0.trackingType) })
        var buckets: [String: Double] = [:]

        for workout in workouts {
            let relevantSets: [ExerciseSet] = workout.sets.filter { set in
                let group = lookupMuscleGroup(for: set, exercises: exercises)
                return muscleGroup == "other" ? group == "other" : group == muscleGroup
            }
            for set in relevantSets {
                let key = exerciseKey(for: set)
                let trackingType = trackingLookup[key] ?? trackingType(for: muscleGroup)
                let metric = metricValue(for: set, trackingType: trackingType)
                buckets[key, default: 0] += metric
            }
        }

        let result: [ExerciseVolume] = exerciseList
            .map {
                let volume = buckets[$0.id] ?? 0
                return ExerciseVolume(exercise: $0, volume: volume)
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
        let trackingLookup = Dictionary(uniqueKeysWithValues: exerciseList.map { ($0.id, $0.trackingType) })
        var buckets: [String: Double] = [:]

        for workout in workouts where workout.date >= range.start && workout.date < range.end {
            let relevantSets: [ExerciseSet] = workout.sets.filter { set in
                let group = lookupMuscleGroup(for: set, exercises: exercises)
                return muscleGroup == "other" ? group == "other" : group == muscleGroup
            }
            for set in relevantSets {
                let key = exerciseKey(for: set)
                let trackingType = trackingLookup[key] ?? trackingType(for: muscleGroup)
                let metric = metricValue(for: set, trackingType: trackingType)
                buckets[key, default: 0] += metric
            }
        }

        let result: [ExerciseVolume] = exerciseList
            .map {
                let volume = buckets[$0.id] ?? 0
                return ExerciseVolume(exercise: $0, volume: volume)
            }

        return result
            .sorted { $0.volume > $1.volume }
    }
    
    static func dailyMuscleGroupVolumes(
        muscleGroup: String,
        workouts: [Workout],
        exercises: [ExerciseCatalog],
        calendar: Calendar,
        days: Int,
        trackingType: ExerciseTrackingType
    ) -> [VolumePoint] {
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        var buckets: [Date: Double] = [:]

        for workout in workouts where workout.date >= start {
            let day = calendar.startOfDay(for: workout.date)
            for set in workout.sets {
                let group = lookupMuscleGroup(for: set, exercises: exercises)
                if muscleGroup == "other" {
                    guard group == "other" else { continue }
                } else {
                    guard group == muscleGroup else { continue }
                }
                buckets[day, default: 0] += metricValue(for: set, trackingType: trackingType)
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
        weeks: Int,
        trackingType: ExerciseTrackingType
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
                let group = lookupMuscleGroup(for: set, exercises: exercises)
                if muscleGroup == "other" {
                    guard group == "other" else { continue }
                } else {
                    guard group == muscleGroup else { continue }
                }
                buckets[weekStart, default: 0] += metricValue(for: set, trackingType: trackingType)
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

    static func weeklyMuscleGroupVolumesForSegment(
        muscleGroup: String,
        segment: MuscleGroupSegment,
        workouts: [Workout],
        exercises: [ExerciseCatalog],
        calendar: Calendar,
        weeks: Int,
        trackingType: ExerciseTrackingType
    ) -> [VolumePoint] {
        guard weeks > 0 else { return [] }
        let today = calendar.startOfDay(for: Date())
        let currentWeekStart = calendar.startOfWeek(for: today) ?? today
        guard let start = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: currentWeekStart),
              let end = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) else { return [] }

        var buckets: [Date: Double] = [:]

        for workout in workouts where workout.date >= start && workout.date < end {
            guard let weekStart = calendar.startOfWeek(for: workout.date) else { continue }
            for set in workout.sets {
                guard let exercise = resolveExercise(for: set, exercises: exercises) else {
                    if muscleGroup == "other" && segment == .all {
                        buckets[weekStart, default: 0] += metricValue(for: set, trackingType: trackingType)
                    }
                    continue
                }
                let group = exercise.muscleGroup
                if muscleGroup == "other" {
                    guard group == "other" else { continue }
                } else {
                    guard group == muscleGroup else { continue }
                }
                if segment != .all {
                    guard OverviewMetrics.segment(for: exercise) == segment else { continue }
                }
                buckets[weekStart, default: 0] += metricValue(for: set, trackingType: trackingType)
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
        months: Int,
        trackingType: ExerciseTrackingType
    ) -> [VolumePoint] {
        let baseMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        guard let start = calendar.date(byAdding: .month, value: -(months - 1), to: baseMonth),
              let end = calendar.date(byAdding: .month, value: 1, to: baseMonth) else { return [] }

        var buckets: [Date: Double] = [:]

        for workout in workouts where workout.date >= start && workout.date < end {
            let comps = calendar.dateComponents([.year, .month], from: workout.date)
            guard let monthStart = calendar.date(from: comps) else { continue }
            for set in workout.sets {
                let group = lookupMuscleGroup(for: set, exercises: exercises)
                if muscleGroup == "other" {
                    guard group == "other" else { continue }
                } else {
                    guard group == muscleGroup else { continue }
                }
                buckets[monthStart, default: 0] += metricValue(for: set, trackingType: trackingType)
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
        calendar: Calendar,
        trackingType: ExerciseTrackingType
    ) -> [VolumePoint] {
        var buckets: [Date: Double] = [:]

        for workout in workouts {
            guard let weekStart = calendar.startOfWeek(for: workout.date) else { continue }
            for set in workout.sets {
                let group = lookupMuscleGroup(for: set, exercises: exercises)
                if muscleGroup == "other" {
                    guard group == "other" else { continue }
                } else {
                    guard group == muscleGroup else { continue }
                }
                buckets[weekStart, default: 0] += metricValue(for: set, trackingType: trackingType)
            }
        }

        return buckets
            .map { VolumePoint(date: $0.key, volume: $0.value) }
            .sorted { $0.date > $1.date }
    }

    static func weeklyExerciseVolumesAll(
        for exerciseId: String,
        workouts: [Workout],
        calendar: Calendar,
        trackingType: ExerciseTrackingType = .weightReps
    ) -> [VolumePoint] {
        var buckets: [Date: Double] = [:]

        for workout in workouts {
            guard let weekStart = calendar.startOfWeek(for: workout.date) else { continue }
            let total = workout.sets
                .filter { matches(set: $0, exerciseId: exerciseId) }
                .reduce(0.0) { $0 + metricValue(for: $1, trackingType: trackingType) }
            guard total > 0 else { continue }
            buckets[weekStart, default: 0] += total
        }

        return buckets
            .map { VolumePoint(date: $0.key, volume: $0.value) }
            .sorted { $0.date > $1.date }
    }

    static func exerciseChartSeries(
        for exerciseId: String,
        workouts: [Workout],
        period: ExerciseChartPeriod,
        calendar: Calendar,
        trackingType: ExerciseTrackingType = .weightReps
    ) -> [VolumePoint] {
        switch period {
        case .day:
            let today = calendar.startOfDay(for: Date())
            guard let start = calendar.date(byAdding: .day, value: -6, to: today),
                  let end = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
            var buckets: [Date: Double] = [:]

            for workout in workouts where workout.date >= start && workout.date < end {
                let day = calendar.startOfDay(for: workout.date)
                let total = workout.sets
                    .filter { matches(set: $0, exerciseId: exerciseId) }
                    .reduce(0.0) { $0 + metricValue(for: $1, trackingType: trackingType) }
                buckets[day, default: 0] += total
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
                let total = workout.sets
                    .filter { matches(set: $0, exerciseId: exerciseId) }
                    .reduce(0.0) { $0 + metricValue(for: $1, trackingType: trackingType) }
                buckets[weekStart, default: 0] += total
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
                let total = workout.sets
                    .filter { matches(set: $0, exerciseId: exerciseId) }
                    .reduce(0.0) { $0 + metricValue(for: $1, trackingType: trackingType) }
                buckets[monthStart, default: 0] += total
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
        for exerciseId: String,
        workouts: [Workout],
        period: OverviewPeriod,
        calendar: Calendar
    ) -> [VolumePoint] {
        let range = period.dateRange(calendar: calendar)
        var buckets: [Date: Double] = [:]

        for workout in workouts where workout.date >= range.start && workout.date < range.end {
            let date = workout.date
            let volume = workout.sets
                .filter { matches(set: $0, exerciseId: exerciseId) }
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
        for exerciseId: String,
        workouts: [Workout],
        period: OverviewPeriod,
        calendar: Calendar
    ) -> [DailyVolume] {
        let range = period.dateRange(calendar: calendar)
        var buckets: [Date: Double] = [:]

        for workout in workouts where workout.date >= range.start && workout.date < range.end {
            let day = calendar.startOfDay(for: workout.date)
            let volume = workout.sets
                .filter { matches(set: $0, exerciseId: exerciseId) }
                .reduce(0.0) { $0 + $1.volume }
            guard volume > 0 else { continue }
            buckets[day, default: 0] += volume
        }

        return buckets
            .map { DailyVolume(date: $0.key, volume: $0.value) }
            .sorted { $0.date > $1.date }
    }
    
    static func dailyVolumes(
        for exerciseId: String,
        workouts: [Workout],
        period: ExerciseChartPeriod,
        calendar: Calendar
    ) -> [DailyVolume] {
        let range = period.dateRange(calendar: calendar)
        var buckets: [Date: Double] = [:]

        for workout in workouts where workout.date >= range.start && workout.date < range.end {
            let day = calendar.startOfDay(for: workout.date)
            let volume = workout.sets
                .filter { matches(set: $0, exerciseId: exerciseId) }
                .reduce(0.0) { $0 + $1.volume }
            guard volume > 0 else { continue }
            buckets[day, default: 0] += volume
        }

        return buckets
            .map { DailyVolume(date: $0.key, volume: $0.value) }
            .sorted { $0.date > $1.date }
    }

    static func dailyVolumesAll(
        for exerciseId: String,
        workouts: [Workout],
        calendar: Calendar
    ) -> [DailyVolume] {
        var buckets: [Date: Double] = [:]

        for workout in workouts {
            let day = calendar.startOfDay(for: workout.date)
            let volume = workout.sets
                .filter { matches(set: $0, exerciseId: exerciseId) }
                .reduce(0.0) { $0 + $1.volume }
            guard volume > 0 else { continue }
            buckets[day, default: 0] += volume
        }

        return buckets
            .map { DailyVolume(date: $0.key, volume: $0.value) }
            .sorted { $0.date > $1.date }
    }

    static func sets(
        for exerciseId: String,
        on date: Date,
        workouts: [Workout],
        calendar: Calendar
    ) -> [ExerciseSet] {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let candidates = workouts.filter { $0.date >= start && $0.date < end }
        let allSets = candidates
            .flatMap { workout in
                workout.sets.filter { matches(set: $0, exerciseId: exerciseId) }
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

    static func repsParts(from reps: Double, locale: Locale) -> (value: String, unit: String) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.maximumFractionDigits = 0
        let text = formatter.string(from: NSNumber(value: reps)) ?? String(Int(reps))
        let unit = Locale.preferredLanguages.first?.hasPrefix("ja") ?? false ? "回" : "reps"
        return (text, unit)
    }

    static func durationString(from seconds: Double) -> String {
        let totalMinutes = max(0, Int((seconds / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let isJapanese = Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
        if isJapanese {
            return "\(hours)時間\(minutes)分"
        }
        return String(format: "%dh %dm", hours, minutes)
    }

    static func durationParts(from seconds: Double) -> (value: String, unit: String) {
        (durationString(from: seconds), "")
    }

    static func metricParts(
        from value: Double,
        trackingType: ExerciseTrackingType,
        locale: Locale,
        unit: WeightUnit = .kg
    ) -> (value: String, unit: String) {
        switch trackingType {
        case .weightReps:
            return volumePartsWithFraction(from: value, locale: locale, unit: unit)
        case .repsOnly:
            return repsParts(from: value, locale: locale)
        case .durationOnly:
            return durationParts(from: value)
        }
    }
}

private struct OverviewStrings {
    let isJapanese: Bool

    var navigationTitle: String { isJapanese ? "アクティビティ" : "Activity" }
    var settingsLabel: String { isJapanese ? "設定" : "Settings" }
    var loadFailedMessage: String {
        isJapanese ? "種目リストの読み込みに失敗しました" : "Failed to load exercise list."
    }
    var noExerciseData: String { isJapanese ? "種目データがありません" : "No exercise data available." }
    func weekRangeLabel(base: String) -> String {
        isJapanese ? "\(base)週" : "Week of \(base)"
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
