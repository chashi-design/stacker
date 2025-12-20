import Combine
import Foundation

/// お気に入り種目IDをUserDefaultsに保存・読み書きするシンプルなストア
final class ExerciseFavoritesStore: ObservableObject {
    private let storageKey = "favoriteExerciseIDs"

    @Published private(set) var favoriteIDs: Set<String> = []

    init() {
        favoriteIDs = Self.decode(data: storedData())
    }

    func isFavorite(_ id: String) -> Bool {
        favoriteIDs.contains(id)
    }

    func toggle(id: String) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else {
            favoriteIDs.insert(id)
        }
        persist()
    }

    func update(_ ids: Set<String>) {
        favoriteIDs = ids
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Self.encode(favoriteIDs), forKey: storageKey)
    }

    private func storedData() -> Data {
        UserDefaults.standard.data(forKey: storageKey) ?? Data()
    }

    private static func decode(data: Data) -> Set<String> {
        guard !data.isEmpty else { return [] }
        do {
            let decoded = try JSONDecoder().decode([String].self, from: data)
            return Set(decoded)
        } catch {
            return []
        }
    }

    private static func encode(_ set: Set<String>) -> Data {
        (try? JSONEncoder().encode(Array(set))) ?? Data()
    }
}
