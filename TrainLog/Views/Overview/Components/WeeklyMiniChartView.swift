import SwiftUI

// Overview card weekly mini chart
struct WeeklyMiniChartView: View {
    let points: [VolumePoint]
    var barColor: Color = .secondary
    var inactiveBarColor: Color = .gray
    var barCornerRadius: CGFloat = 3
    var barSpacing: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let safePoints = points.isEmpty
                ? [VolumePoint(date: Date(timeIntervalSince1970: 0), volume: 0)]
                : points
            let values = safePoints.map(\.volume)
            let maxValue = values.max() ?? 0
            let hasValue = points.contains { $0.volume > 0 }
            let calendar = Calendar.appCurrent
            let currentWeekStart = calendar.startOfWeek(for: Date()) ?? Date()
            let count = max(safePoints.count, 1)
            let totalSpacing = barSpacing * CGFloat(max(count - 1, 0))
            let availableWidth = max(size.width - totalSpacing, 0)
            let barWidth = max(availableWidth / CGFloat(count), 2)
            let maxScale = max(maxValue, 1)

            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(Array(safePoints.enumerated()), id: \.offset) { _, point in
                    let weekStart = calendar.startOfWeek(for: point.date) ?? point.date
                    let isCurrentWeek = calendar.isDate(weekStart, inSameDayAs: currentWeekStart)
                    let inactiveColor = inactiveBarColor.opacity(0.3)
                    let baseColor = isCurrentWeek ? barColor : inactiveColor
                    let fillColor = hasValue ? baseColor : baseColor.opacity(0.3)
                    let ratio = maxScale > 0 ? point.volume / maxScale : 0
                    let rawHeight = CGFloat(ratio) * size.height
                    let height = point.volume > 0 ? max(rawHeight, 2) : 0
                    RoundedRectangle(cornerRadius: barCornerRadius)
                        .fill(fillColor)
                        .frame(width: barWidth, height: height)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .bottom)
        }
        .frame(width: 80, height: 80)
        .accessibilityHidden(true)
    }
}

#Preview {
    WeeklyMiniChartView(
        points: [
            VolumePoint(date: Date().addingTimeInterval(-60 * 60 * 24 * 28), volume: 12),
            VolumePoint(date: Date().addingTimeInterval(-60 * 60 * 24 * 21), volume: 9),
            VolumePoint(date: Date().addingTimeInterval(-60 * 60 * 24 * 14), volume: 15),
            VolumePoint(date: Date().addingTimeInterval(-60 * 60 * 24 * 7), volume: 18),
            VolumePoint(date: Date(), volume: 16)
        ],
        barColor: Color.accentColor
    )
}
