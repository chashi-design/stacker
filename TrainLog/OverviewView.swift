import Charts
import SwiftData
import SwiftUI

struct OverviewTabView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @State private var exercises: [ExerciseCatalog] = []
    @State private var loadFailed = false
    @State private var refreshID = UUID()

    private let calendar = Calendar.current
    private let locale = Locale(identifier: "ja_JP")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
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
                    .id(refreshID)
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
            .onChange(of: workouts) { oldValue, newValue in
                refreshID = UUID()
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
        .background(
            RoundedCorner(radius: 26, corners: [.bottomLeft, .bottomRight])
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// Custom shape for selective corner rounding
struct RoundedCorner: Shape {
    var radius: CGFloat = 0
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
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
                            monthLabel: "累計",
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
                .font(.system(size: 17, weight: .semibold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }
}

// MARK: - Parts screen
struct ExerciseVolumeChart: View {
    let data: [(label: String, value: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    BarMark(
                        x: .value("日付", item.label),
                        y: .value("ボリューム(kg)", item.value)
                    )
                }
            }
            .chartXAxis {
                AxisMarks(values: data.map { $0.label }) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYAxisLabel("kg")
            .frame(height: 220)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))

    }
}


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
    
    private var weeklySeries: [VolumePoint] {
        OverviewMetrics.weeklyMuscleGroupVolumes(
            muscleGroup: muscleGroup,
            workouts: workouts,
            exercises: exercises,
            calendar: calendar,
            weeks: 8
        )
    }

    private var chartData: [(label: String, value: Double)] {
        weeklySeries
            .sorted { $0.date < $1.date }
            .map { (axisLabel(for: $0.date), $0.volume) }
    }
    
    private var weeklyListData: [(label: String, value: Double)] {
        weeklySeries
            .sorted { $0.date > $1.date }
            .map { (weekRangeLabel(for: $0.date), $0.volume) }
    }

    var body: some View {
        List {
            Section("ボリューム") {
                ExerciseVolumeChart(data: chartData)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(weeklyListData.enumerated()), id: \.offset) { index, item in
                        HStack {
                            Text(item.label)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(VolumeFormatter.string(from: item.value, locale: locale))
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.vertical, 8)
                        if index < weeklyListData.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            Section("種別") {
                Picker("表示", selection: $filter) {
                    ForEach(PartsFilter.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
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
                                Text("累計")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(VolumeFormatter.string(from: item.volume, locale: locale))
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                if filteredExercises.isEmpty {
                    Text("対象の種目がありません")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.large)
        .listSectionSpacing(10)
    }

    private var filteredExercises: [ExerciseVolume] {
        switch filter {
        case .all:
            return exerciseVolumes
        case .completed:
            return exerciseVolumes.filter { $0.volume > 0 }
        }
    }

    private func axisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    private func weekRangeLabel(for date: Date) -> String {
        let start = calendar.startOfWeek(for: date) ?? date
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: start))週"
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

enum ExerciseChartPeriod: CaseIterable {
    case day
    case week
    case month

    var title: String {
        switch self {
        case .day: return "日"
        case .week: return "週"
        case .month: return "月"
        }
    }
}

// MARK: - Exercise detail (timeline)

struct OverviewExerciseDetailView: View {
    let exercise: ExerciseCatalog
    let workouts: [Workout]

    @State private var chartPeriod: ExerciseChartPeriod = .day
    private let calendar = Calendar.current
    private let locale = Locale(identifier: "ja_JP")

    private var chartData: [(label: String, value: Double)] {
        let series = OverviewMetrics.exerciseChartSeries(
            for: exercise.name,
            workouts: workouts,
            period: chartPeriod,
            calendar: calendar
        )
        return series.map { point in
            (axisLabel(for: point.date, period: chartPeriod), point.volume)
        }
    }

    private var hasAnyHistory: Bool {
        workouts.contains { workout in
            workout.sets.contains { $0.exerciseName == exercise.name }
        }
    }

    var body: some View {
        List {
            if hasAnyHistory {
                Section("ボリューム") {
                    Picker("期間", selection: $chartPeriod) {
                        ForEach(ExerciseChartPeriod.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)

                    ExerciseVolumeChart(data: chartData)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
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
        .navigationBarTitleDisplayMode(.large)
    }

    private var sectionedDailyVolumes: [DailyVolumeSection] {
        let days = OverviewMetrics.dailyVolumes(
            for: exercise.name,
            workouts: workouts,
            period: chartPeriod,
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

    private func axisLabel(for date: Date, period: ExerciseChartPeriod) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        switch period {
        case .day, .week:
            formatter.dateFormat = "M/d"
        case .month:
            formatter.dateFormat = "M月"
        }
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

    static func muscleGroupVolumesForCurrentMonth(
        workouts: [Workout],
        exercises: [ExerciseCatalog],
        calendar: Calendar
    ) -> [MuscleGroupVolume] {
        let lookup = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0) })
        var muscleGroups: [String] = ["chest", "shoulders", "arms", "back", "legs", "abs", "other"]
        var buckets: [String: Double] = [:]

        for workout in workouts {
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
                  let start = calendar.date(byAdding: .weekOfYear, value: -7, to: currentWeekStart),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) else { return [] }

            var buckets: [Date: Double] = [:]

            for workout in workouts where workout.date >= start && workout.date < end {
                guard let weekStart = calendar.startOfWeek(for: workout.date) else { continue }
                let volume = workout.sets
                    .filter { $0.exerciseName == exerciseName }
                    .reduce(0.0) { $0 + $1.volume }
                buckets[weekStart, default: 0] += volume
            }

            let weeks = (0..<8).compactMap { offset in
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
        "other": "その他"
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
        let base = calendar.startOfDay(for: Date())
        let end: Date
        let start: Date
        switch self {
        case .week:
            let weekday = calendar.component(.weekday, from: base)
            let offsetToSunday = (weekday + 7 - 1) % 7 // 1 = Sunday
            start = calendar.date(byAdding: .day, value: -offsetToSunday, to: base) ?? base
            end = calendar.date(byAdding: .day, value: 7, to: start) ?? base
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
            start = calendar.date(byAdding: .weekOfYear, value: -7, to: currentWeekStart) ?? currentWeekStart
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
