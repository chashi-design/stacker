import SwiftUI

// 数値と単位の見た目を分けて表示する共通View
struct ValueWithUnitText: View {
    let value: String
    let unit: String
    let valueFont: Font
    let unitFont: Font
    var valueColor: Color = .primary
    var unitColor: Color = .secondary

    var body: some View {
        Text(styledText)
    }

    private var styledText: AttributedString {
        var attributed = AttributedString("\(value)\(unit)")
        if let valueRange = attributed.range(of: value) {
            attributed[valueRange].font = valueFont
            attributed[valueRange].foregroundColor = valueColor
        }
        if let unitRange = attributed.range(of: unit) {
            attributed[unitRange].font = unitFont
            attributed[unitRange].foregroundColor = unitColor
        }
        return attributed
    }
}
