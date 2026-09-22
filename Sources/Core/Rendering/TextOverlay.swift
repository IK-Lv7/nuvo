import CoreGraphics
import Foundation

/// 文字の書体。すべて端末に入っているフォントで、フォントファイルは同梱しない
/// (実行時に名前で呼ぶだけなので、ライセンスの整理も要らない)。
public enum TextStyle: String, CaseIterable, Sendable, Codable {
    case standard, serif, rounded, mono
    case gothic, mincho, maru
    case script, handwriting, marker, condensed, didot, typewriter

    /// PostScript 名(通常・太字)。nil はシステムフォント。太字の専用フォントが無いものは bold が nil で、
    /// 描画時に太字のトレイトを付ける。
    var fontNames: (regular: String, bold: String?)? {
        switch self {
        case .standard: nil
        case .serif: ("Georgia", "Georgia-Bold")
        case .rounded: ("ArialRoundedMTBold", nil)
        case .mono: ("Menlo-Regular", "Menlo-Bold")
        case .gothic: ("HiraginoSans-W3", "HiraginoSans-W6")
        case .mincho: ("HiraMinProN-W3", "HiraMinProN-W6")
        case .maru: ("HiraMaruProN-W4", nil)
        case .script: ("SnellRoundhand", "SnellRoundhand-Bold")
        case .handwriting: ("Noteworthy-Light", "Noteworthy-Bold")
        case .marker: ("MarkerFelt-Thin", "MarkerFelt-Wide")
        case .condensed: ("Futura-CondensedMedium", "Futura-CondensedExtraBold")
        case .didot: ("Didot", "Didot-Bold")
        case .typewriter: ("AmericanTypewriter", "AmericanTypewriter-Bold")
        }
    }

    /// 選択肢の見本表示に使う名前。システムフォントは nil。
    public var previewFontName: String? { fontNames?.regular }
}

public enum TextColor: String, CaseIterable, Sendable, Codable {
    case white, black, pink, yellow

    /// 文字入れ・スタンプで共通に使う色の値。
    public var cgColor: CGColor {
        switch self {
        case .white: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        case .black: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        case .pink: CGColor(red: 1, green: 0.54, blue: 0.62, alpha: 1)
        case .yellow: CGColor(red: 1, green: 0.86, blue: 0.3, alpha: 1)
        }
    }
}

/// 写真に重ねる文字。位置・大きさは画像サイズに依存しない値で持つので、プレビューでも書き出しでも同じ見た目になる。
public struct TextOverlay: Equatable, Sendable, Codable, Identifiable {
    public var id: UUID
    public var text: String
    /// 文字の中心(0...1、左上原点)。
    public var center: CGPoint
    /// 文字の高さ(画像の短辺に対する比)。
    public var size: Double
    public var color: TextColor
    public var style: TextStyle
    public var isBold: Bool
    public var hasShadow: Bool

    public static let sizeRange: ClosedRange<Double> = 0.03...0.3

    public init(id: UUID = UUID(), text: String = "Nuvo", center: CGPoint = CGPoint(x: 0.5, y: 0.5),
                size: Double = 0.08, color: TextColor = .white, style: TextStyle = .standard,
                isBold: Bool = true, hasShadow: Bool = true) {
        self.id = id
        self.text = text
        self.center = center
        self.size = size
        self.color = color
        self.style = style
        self.isBold = isBold
        self.hasShadow = hasShadow
    }
}
