import SwiftUI
import UIKit

extension Color {
    /// 0...1 の sRGB 成分。`ColorPicker` などから受け取った色を、加工用の値(MakeupTint)に変換するために使う。
    /// 変換できない色空間の場合は nil。
    func srgbComponents() -> (red: Double, green: Double, blue: Double)? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (Double(r), Double(g), Double(b))
    }
}
