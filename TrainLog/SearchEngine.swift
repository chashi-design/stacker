import Foundation

// MARK: - Model (JSONと対応)
public struct ExerciseCatalog: Codable, Hashable, Identifiable {
    public let id: String
    public let name: String        // 日本語表記
    public let nameEn: String      // 英語表記
    public let muscleGroup: String // "chest" など
    public let aliases: [String]
    public let equipment: String   // "barbell" 等
    public let pattern: String     // 動作パターン
}

public struct SearchFilters: Sendable {
    public var muscleGroup: Set<String> = []
    public var equipment: Set<String> = []
    public var pattern: Set<String> = []
    
    public init(
        muscleGroup: Set<String> = [],
        equipment: Set<String> = [],
        pattern: Set<String> = []
    ) {
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.pattern = pattern
    }
}

public struct SearchResult: Sendable {
    public let item: ExerciseCatalog
    public let score: Int // 大きいほど関連度が高い
}

// MARK: - 正規化ユーティリティ
public enum TextNorm {
    public static func normalize(_ s: String) -> String {
        var str = s.precomposedStringWithCompatibilityMapping
        str = str.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ja_JP"))
        let transform = StringTransform("Katakana-Hiragana")
        str = str.applyingTransform(transform, reverse: false) ?? str

        let allowed = CharacterSet(charactersIn: "ぁあ-んa-z0-9")
        var buf = ""
        for ch in str {
            if ch == "ー" { continue }
            if ch == " " || ch == "\t" || ch == "_" || ch == "-" { continue }
            if String(ch).rangeOfCharacter(from: allowed) != nil {
                buf.append(ch)
            }
        }
        return buf
    }

    public static func tokens(from s: String) -> [String] {
        let norm = normalize(s)
        if s.contains(" ") {
            return s.lowercased()
                .split(separator: " ")
                .map { normalize(String($0)) }
                .filter { !$0.isEmpty }
        } else {
            return [norm]
        }
    }
}

// MARK: - 索引
public final class ExerciseIndex: @unchecked Sendable {
    private let items: [ExerciseCatalog]
    private var index: [(key: String, id: String, weight: Int)] = []
    private var dict: [String: ExerciseCatalog] = [:]

    public init(items: [ExerciseCatalog]) {
        self.items = items
        for it in items {
            dict[it.id] = it
            let k1 = TextNorm.normalize(it.name)
            index.append((k1, it.id, 8))

            let k2 = TextNorm.normalize(it.nameEn)
            if !k2.isEmpty { index.append((k2, it.id, 6)) }

            for al in it.aliases {
                let k = TextNorm.normalize(al)
                if !k.isEmpty { index.append((k, it.id, 5)) }
            }
        }
    }

    public func all() -> [ExerciseCatalog] { items }

    public func search(_ query: String, filters: SearchFilters = .init(), limit: Int = 20) -> [SearchResult] {
        let qn = TextNorm.normalize(query)
        if qn.isEmpty {
            return items
                .filter { self.filterMatch($0, filters: filters) }
                .prefix(limit)
                .map { SearchResult(item: $0, score: 0) }
        }

        var scores: [String: Int] = [:]
        for (key, id, weight) in index {
            if key == qn {
                scores[id, default: 0] += 100 * weight
                continue
            }
            if key.hasPrefix(qn) {
                scores[id, default: 0] += 60 * weight
                continue
            }
            if key.contains(qn) {
                scores[id, default: 0] += 30 * weight
            } else {
                if qn.count <= 6 {
                    let d = ExerciseIndex.levenshtein(key, qn)
                    if d <= 1 { scores[id, default: 0] += 20 * weight }
                    else if d == 2 { scores[id, default: 0] += 10 * weight }
                }
            }
        }

        let results: [SearchResult] = scores.compactMap { (id, sc) in
            guard let item = dict[id], filterMatch(item, filters: filters) else { return nil }
            return SearchResult(item: item, score: sc)
        }
        .sorted { $0.score > $1.score }
        .prefix(limit)
        .map { $0 }

        return results
    }

    private func filterMatch(_ item: ExerciseCatalog, filters: SearchFilters) -> Bool {
        if !filters.muscleGroup.isEmpty && !filters.muscleGroup.contains(item.muscleGroup) { return false }
        if !filters.equipment.isEmpty && !filters.equipment.contains(item.equipment) { return false }
        if !filters.pattern.isEmpty && !filters.pattern.contains(item.pattern) { return false }
        return true
    }

    // Levenshtein
    static func levenshtein(_ s: String, _ t: String) -> Int {
        let a = Array(s), b = Array(t)
        let n = a.count, m = b.count
        if n == 0 { return m }
        if m == 0 { return n }
        var dp = Array(0...m)
        for i in 1...n {
            var prev = dp[0]
            dp[0] = i
            for j in 1...m {
                let temp = dp[j]
                dp[j] = min(
                    dp[j] + 1,
                    dp[j-1] + 1,
                    prev + (a[i-1] == b[j-1] ? 0 : 1)
                )
                prev = temp
            }
        }
        return dp[m]
    }
}

// MARK: - JSONローダ
public enum ExerciseLoader {
    public static func loadFromBundle() throws -> [ExerciseCatalog] {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            throw NSError(
                domain: "SearchEngine",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "exercises.json が見つかりません。プロジェクトに追加してください。"]
            )
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([ExerciseCatalog].self, from: data)
    }
}//
//  SearchEngine.swift
//  TrainLog
//
//  Created by Takanori Hirohashi on 2025/11/03.
//




