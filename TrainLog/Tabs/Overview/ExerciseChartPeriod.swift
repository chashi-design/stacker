import SwiftUI

// 種目別チャートの期間種別を定義するenum
// enumは「決められた選択肢の集合」を型として表すため、想定外の値を防げる
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
