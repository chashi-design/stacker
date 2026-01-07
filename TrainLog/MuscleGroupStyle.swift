import SwiftUI

enum MuscleGroupColor {
    static func color(for key: String) -> Color {
        palette[key, default: .gray]
    }

    private static let palette: [String: Color] = [
        "chest": .red,
        "shoulders": .orange,
        "arms": .green,
        "back": .mint,
        "legs": .cyan,
        "abs": .purple,
        "cardio": .pink,
        "other": .gray
    ]
}
