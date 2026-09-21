import Foundation
import NuvoCore
import Observation

/// 保存したルック(調整値のまとまり)。端末の中だけに保存し、外には出さない。
@MainActor
@Observable
final class LookStore {
    struct Look: Identifiable, Codable, Equatable {
        var id = UUID()
        var name: String
        var parameters: AdjustmentParameters
    }

    private(set) var looks: [Look] = []
    private let key = "looks.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Look].self, from: data) else { return }
        looks = decoded
    }

    /// 写真ごとの内容(修復位置・構図・文字・証明写真)を除いて保存する。
    func save(name: String, parameters: AdjustmentParameters) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        looks.append(Look(name: trimmed, parameters: parameters.lookOnly()))
        persist()
    }

    func delete(_ look: Look) {
        looks.removeAll { $0.id == look.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(looks) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
