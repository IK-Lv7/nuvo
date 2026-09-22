import SwiftUI
import UIKit

extension Color {
    /// 0...1 の sRGB 成分。`ColorPicker` などから受け取った色を、加工用の値(MakeupTint)に変換するために使う。
    /// システムの色選択画面は「スライダ」タブでグレースケール・CMYK など RGB 以外の色空間でも選べるが、
    /// `UIColor.getRed(green:blue:alpha:)` はそれらの色空間では失敗する(戻り値 false)。
    /// 呼び出し側はその失敗時に何もせず抜けるため、テンプレ以外の色を選んだときに無反応に見える不具合があった。
    /// `CGColor.converted` で色空間によらず明示的に sRGB へ変換してから成分を取り出す。
    func srgbComponents() -> (red: Double, green: Double, blue: Double)? {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = UIColor(self).cgColor.converted(to: srgb, intent: .defaultIntent, options: nil),
              let components = converted.components, components.count >= 3 else {
            return nil
        }
        return (Double(components[0]), Double(components[1]), Double(components[2]))
    }
}
