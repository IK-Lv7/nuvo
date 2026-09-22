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
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let decoded = try? JSONDecoder().decode([Look].self, from: data) {
            looks = decoded
            return
        }
        // 調整項目が増えると、以前のバージョンで保存したルックはそのままでは読めない。
        // 既定値で埋めて読み直し、黙って全部消えないようにする。
        looks = Self.looksFillingMissingValues(from: data)
    }

    /// 項目が足りない JSON を、既定値で埋めながら読む。読めないルックだけを捨てる。
    private static func looksFillingMissingValues(from data: Data) -> [Look] {
        guard let array = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return [] }
        return array.compactMap { entry in
            guard let name = entry["name"] as? String,
                  let saved = entry["parameters"] as? [String: Any],
                  let parameters = AdjustmentParameters.lenientlyDecoded(from: saved) else { return nil }
            let id = (entry["id"] as? String).flatMap { UUID(uuidString: $0) } ?? UUID()
            return Look(id: id, name: name, parameters: parameters)
        }
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
