import SwiftUI

/// 色・余白・角丸の定義。画面側は数値を直接書かず、ここを参照する。
enum Theme {
    /// アイコンと同じローズ → ピーチ。
    static let accent = Color(red: 1.0, green: 0.54, blue: 0.62)
    static let accentSoft = Color(red: 1.0, green: 0.77, blue: 0.58)

    /// 写真の色を正しく判断できるよう、編集画面は中間色の暗い背景にする。
    static let canvas = Color(red: 0.07, green: 0.07, blue: 0.08)

    static let brandGradient = LinearGradient(
        colors: [accent, accentSoft], startPoint: .topLeading, endPoint: .bottomTrailing)

    enum Spacing {
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
    }
}
