import Foundation

enum MuscleGroupLabel {
    static func label(for key: String) -> String {
        labels[key, default: key]
    }

    private static let labels: [String: String] = [
        "favorites": "登録",
        "chest": "胸",
        "back": "背中",
        "shoulders": "肩",
        "arms": "腕",
        "legs": "脚",
        "abs": "体幹",
        "other": "その他"
    ]
}
