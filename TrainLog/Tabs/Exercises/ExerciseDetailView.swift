import SwiftUI

struct ExerciseDetailView: View {
    let exercise: ExerciseCatalog

    @EnvironmentObject private var favoritesStore: ExerciseFavoritesStore

    private var isFavorite: Bool {
        favoritesStore.isFavorite(exercise.id)
    }

    var body: some View {
        List {

            Section("説明") {
                Text(descriptionText)
                    .font(.body)
                    .padding(.vertical, 4)
            }

            Section("部位") {
                WrapTagView(tags: [muscleTag])
            }

            Section("器具") {
                if let equipmentTag {
                    WrapTagView(tags: [equipmentTag])
                } else {
                    Text("情報なし")
                        .foregroundStyle(.secondary)
                }
            }

            Section("動作") {
                if let patternTag {
                    WrapTagView(tags: [patternTag])
                } else {
                    Text("情報なし")
                        .foregroundStyle(.secondary)
                }
            }

            if !exercise.aliases.isEmpty {
                Section("別名") {
                    WrapTagView(tags: exercise.aliases)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            HapticButton {
                favoritesStore.toggle(id: exercise.id)
            } label: {
                Label(isFavorite ? "お気に入り解除" : "お気に入り", systemImage: isFavorite ? "star.fill" : "star")
                    .labelStyle(.iconOnly)
            }
            .tint(isFavorite ? .yellow : .primary)
        }
    }

    private var descriptionText: String {
        var parts: [String] = []
        let muscle = MuscleGroupLabel.label(for: exercise.muscleGroup)
        parts.append("\(exercise.name)は\(muscle)を主に鍛える種目です。")
        if let pattern = MovementPatternLabel.detail(for: exercise.pattern) {
            parts.append(pattern)
        } else {
            parts.append("フォームや安全に注意して実施しましょう。")
        }
        return parts.joined(separator: "\n")
    }

    private var muscleTag: String {
        "\(MuscleGroupLabel.label(for: exercise.muscleGroup))"
    }

    private var equipmentTag: String? {
        EquipmentLabel.label(for: exercise.equipment).map { "\($0)" }
    }

    private var patternTag: String? {
        MovementPatternLabel.label(for: exercise.pattern).map { "\($0)" }
    }
}

struct WrapTagView: View {
    let tags: [String]

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.body)
            }
        }
    }
}

enum EquipmentLabel {
    static func label(for key: String) -> String? {
        equipment[key]
    }

    private static let equipment: [String: String] = [
        "barbell": "バーベル",
        "dumbbell": "ダンベル",
        "machine": "マシン",
        "cable": "ケーブル",
        "bodyweight": "自重",
        "band": "チューブ/バンド"
    ]
}

enum MovementPatternLabel {
    static func label(for key: String) -> String? {
        patterns[key]?.title
    }

    static func detail(for key: String) -> String? {
        patterns[key]?.description
    }

    private struct PatternInfo {
        let title: String
        let description: String
    }

    private static let patterns: [String: PatternInfo] = [
        "horizontal_push": PatternInfo(
            title: "水平プッシュ",
            description: "肩甲骨を安定させ、バー/ダンベルを胸の上でコントロールしながら押し出します。"
        ),
        "vertical_push": PatternInfo(
            title: "垂直プッシュ",
            description: "体幹を締めてバランスを保ち、耳の近くを通すように真上へ押し上げます。"
        ),
        "horizontal_pull": PatternInfo(
            title: "水平プル",
            description: "肩甲骨を寄せる意識で引き、胸を張ったまま動作を行います。"
        ),
        "vertical_pull": PatternInfo(
            title: "垂直プル",
            description: "肘で引くイメージでバー/グリップを引き下げ、反動を抑えてコントロールします。"
        ),
        "hip_hinge": PatternInfo(
            title: "ヒンジ",
            description: "股関節を起点に上体をたたみ、背中を丸めずにお尻を引いて動作します。"
        ),
        "squat": PatternInfo(
            title: "スクワット",
            description: "足裏全体で床を踏みしめ、膝と股関節を連動させて上下動します。"
        ),
        "lunge": PatternInfo(
            title: "ランジ",
            description: "前後の足でバランスをとりながら上下動し、膝が内側に入らないよう意識します。"
        ),
        "carry": PatternInfo(
            title: "キャリー",
            description: "体幹を固定し、荷重を安定させたまま歩行/移動を行います。"
        ),
        "rotation": PatternInfo(
            title: "ローテーション",
            description: "体幹を主導にツイストを行い、腰を反らせすぎないように注意します。"
        )
    ]
}

#Preview {
    NavigationStack {
        ExerciseDetailView(
            exercise: ExerciseCatalog(
                id: "ex001",
                name: "ベンチプレス",
                nameEn: "Barbell Bench Press",
                muscleGroup: "chest",
                aliases: ["ベンチ", "BBベンチ"],
                equipment: "barbell",
                pattern: "horizontal_push"
            )
        )
        .environmentObject(ExerciseFavoritesStore())
    }
}
