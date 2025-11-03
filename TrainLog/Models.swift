//
//  Models.swift
//  TrainLog
//
//  Created by Takanori Hirohashi on 2025/11/03.
//

// このファイルでは筋トレ記録アプリのデータモデルを定義しています。
// SwiftData (@Model) を使ってデータを永続化します。
// - Workout: 1回分のトレーニング全体
// - ExerciseSet: その中の各セット情報

import SwiftData
import Foundation

// MARK: - Workout モデル
// 1回のトレーニングを表すモデル。
// date: トレーニングを行った日付と時刻
// note: トレーニング全体に関するメモ
// sets: このトレーニングに含まれるセット（ExerciseSet）の配列
// deleteRule: .cascade にしているので、Workoutを削除すると関連するセットも同時に削除される
@Model
final class Workout {
    @Attribute(.unique) var id: UUID
    var date: Date
    var note: String
    @Relationship(deleteRule: .cascade) var sets: [ExerciseSet]

    // 新しいWorkoutインスタンスを作成する初期化メソッド
    // date と note、セットの配列を渡せます。引数を省略すると現在時刻の空Workoutになります。
    init(date: Date = .now, note: String = "", sets: [ExerciseSet] = []) {
        self.id = UUID()
        self.date = date
        self.note = note
        self.sets = sets
    }
}

// MARK: - ExerciseSet モデル
// 1つの種目における1セット分の記録を表すモデル。
// exerciseName: 種目名（例: ベンチプレス）
// weight: 使用した重量(kg)
// reps: 挙上回数
// rpe: 主観的なきつさ（RPEスケール、任意）
// createdAt: セットを記録した日時
@Model
final class ExerciseSet {
    @Attribute(.unique) var id: UUID
    var exerciseName: String
    var weight: Double
    var reps: Int
    var rpe: Double?
    var createdAt: Date

    // 新しいExerciseSetを作成する初期化メソッド
    // 種目名・重量・回数・RPEを指定できます。
    // createdAtはデフォルトで現在時刻が入ります。
    init(
        exerciseName: String,
        weight: Double,
        reps: Int,
        rpe: Double? = nil,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.createdAt = createdAt
    }

    // 1セットの総ボリューム(重量 × 回数)を計算して返す
    var volume: Double {
        weight * Double(reps)
    }
}
