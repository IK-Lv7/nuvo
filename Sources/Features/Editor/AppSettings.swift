import Foundation
import NuvoCore

/// 端末に保存する設定。設定画面の `@AppStorage` と同じキー・同じ既定値を使う。
enum AppSettings {
    static let stripLocationKey = "stripLocation"
    static let exportFormatKey = "exportFormat"
    static let exportQualityKey = "exportQuality"

    /// 書き出す写真から位置情報を消すか。「データを渡さない」という方針に合わせ、既定は消す。
    static var stripLocation: Bool {
        UserDefaults.standard.object(forKey: stripLocationKey) as? Bool ?? true
    }

    static var exportFormat: ExportFormat {
        ExportFormat(rawValue: UserDefaults.standard.string(forKey: exportFormatKey) ?? "") ?? .jpeg
    }

    /// 画質(0.5...1)。既定は `ImageRenderer.defaultQuality`。
    static var exportQuality: Double {
        let stored = UserDefaults.standard.object(forKey: exportQualityKey) as? Double ?? ImageRenderer.defaultQuality
        return min(max(stored, 0.5), 1)
    }
}
