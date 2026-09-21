import SwiftUI

extension LocalizedStringKey {
    /// 実行時に組み立てたキー("tool." + id など)で文字列を引く。
    /// `LocalizedStringKey("tool.\(id)")` と書くと、補間が書式指定子("tool.%@")に変わり、
    /// 文字列カタログに無いキーを探して、キー名がそのまま画面に出てしまう。
    static func dynamic(_ key: String) -> LocalizedStringKey {
        LocalizedStringKey(key)
    }
}
