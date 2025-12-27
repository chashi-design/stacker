import Charts
import SwiftUI

// 部位/種目のボリュームチャートを表示する共通コンポーネント
struct ExerciseVolumeChart: View {
    let data: [(label: String, value: Double)]
    var barColor: Color = .blue
    var animateOnAppear: Bool = false
    var animateOnTrigger: Bool = false
    var animationTrigger: Int = 0
    var yValueLabel: String = "ボリューム(kg)"
    var yAxisLabel: String = "kg"
    @State private var animateBars = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    BarMark(
                        x: .value("日付", item.label),
                        y: .value(yValueLabel, animatedValue(for: item.value))
                    )
                    .foregroundStyle(barColor)
                    .cornerRadius(8)
                }
            }
            .chartYScale(domain: 0...yScaleUpperBound)
            .chartXAxis {
                AxisMarks(values: data.map { $0.label }) { value in
                    AxisValueLabel()
                }
            }
            .chartYAxisLabel(yAxisLabel)
            .frame(height: 200)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .onAppear {
            guard animateOnAppear else { return }
            restartAnimation()
        }
        .onChange(of: animationTrigger) { _, _ in
            guard animateOnTrigger else { return }
            restartAnimation()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))

    }

    private func restartAnimation() {
        animateBars = false
        withAnimation(.smooth(duration: 0.6)) {
            animateBars = true
        }
    }

    private func animatedValue(for value: Double) -> Double {
        (animateOnAppear ? animateBars : true) ? value : 0
    }

    private var yScaleUpperBound: Double {
        let maxValue = data.map { $0.value }.max() ?? 0
        return max(maxValue, 1)
    }
}
