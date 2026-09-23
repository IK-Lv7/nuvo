import CoreGraphics
import Foundation

/// 文字の書体。すべて端末に入っているフォントで、フォントファイルは同梱しない
/// (実行時に名前で呼ぶだけなので、ライセンスの整理も要らない)。
public enum TextStyle: String, CaseIterable, Sendable, Codable {
    case standard, serif, rounded, mono
    case gothic, mincho, maru
    case script, handwriting, marker, condensed, didot, typewriter
    case avenir, baskerville, copperplate, chalkboard, papyrus, zapfino, optima, bradleyHand

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
        // Avenir に "Bold" という名前の書体は無く、"Heavy" が太字に相当する。
        case .avenir: ("Avenir-Book", "Avenir-Heavy")
        case .baskerville: ("Baskerville", "Baskerville-Bold")
        case .copperplate: ("Copperplate", "Copperplate-Bold")
        case .chalkboard: ("ChalkboardSE-Regular", "ChalkboardSE-Bold")
        // Papyrus・Zapfino は太字の書体が存在しない(太字トグルは通常のトレイト付けにフォールバックする)。
        case .papyrus: ("Papyrus", nil)
        case .zapfino: ("Zapfino", nil)
        case .optima: ("Optima-Regular", "Optima-Bold")
        // Bradley Hand は端末に1書体しか無く、その唯一の書体の名前に "Bold" が含まれている
        // (太字にしても見た目は変わらない)。
        case .bradleyHand: ("BradleyHandITCTT-Bold", nil)
        }
    }

    /// 選択肢の見本表示に使う名前。システムフォントは nil。
    public var previewFontName: String? { fontNames?.regular }
}

/// 文字入れ・スタンプ(SF Symbols)の色見本。メイクの色見本(LipstickPreset など)と同じ方針で、
/// 一般的な言葉の名前・自作の値にする。値は iOS 標準の色(UIColor の systemXxx 系)に合わせてあり、
/// 見た目の相性を個別に調整する必要がない。
public enum TextColorPreset: String, CaseIterable, Sendable {
    case white, black, gray, red, orange, yellow, green, mint, blue, purple, pink, brown

    public var tint: MakeupTint {
        switch self {
        case .white: MakeupTint(red: 1, green: 1, blue: 1)
        case .black: MakeupTint(red: 0, green: 0, blue: 0)
        case .gray: MakeupTint(r: 142, g: 142, b: 147)
        case .red: MakeupTint(r: 255, g: 59, b: 48)
        case .orange: MakeupTint(r: 255, g: 149, b: 0)
        // 以前からの固定値(TextColor.yellow)。既存の保存済みルックとの見た目の連続性のため変えない。
        case .yellow: MakeupTint(red: 1, green: 0.86, blue: 0.3)
        case .green: MakeupTint(r: 52, g: 199, b: 89)
        case .mint: MakeupTint(r: 0, g: 199, b: 190)
        case .blue: MakeupTint(r: 10, g: 132, b: 255)
        case .purple: MakeupTint(r: 175, g: 82, b: 222)
        // 以前からの固定値(TextColor.pink)。既存の保存済みルックとの見た目の連続性のため変えない。
        case .pink: MakeupTint(red: 1, green: 0.54, blue: 0.62)
        case .brown: MakeupTint(r: 162, g: 132, b: 94)
        }
    }
}

/// `imageAssetName` を追加したときと同じ理由(後方互換)で残す、以前の文字色(固定4色)の名前。
/// 新しい保存形式は `color` を `MakeupTint`(RGB。カラーピックで選んだ任意の色も表せる)で持つが、
/// それ以前に保存されたルックはこの名前の文字列で入っているため、読み込み時にだけ経由する。
private enum LegacyTextColor: String, Codable {
    case white, black, pink, yellow

    var preset: TextColorPreset {
        switch self {
        case .white: .white
        case .black: .black
        case .pink: .pink
        case .yellow: .yellow
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
    /// カラーコードで選んだ任意の色も含む(`TextColorPreset` の見本はここへの近道)。
    public var color: MakeupTint
    public var style: TextStyle
    public var isBold: Bool
    public var hasShadow: Bool

    public static let sizeRange: ClosedRange<Double> = 0.03...0.3

    public init(id: UUID = UUID(), text: String = "Nuvo", center: CGPoint = CGPoint(x: 0.5, y: 0.5),
                size: Double = 0.08, color: MakeupTint = TextColorPreset.white.tint, style: TextStyle = .standard,
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

    private enum CodingKeys: String, CodingKey {
        case id, text, center, size, color, style, isBold, hasShadow
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        center = try container.decode(CGPoint.self, forKey: .center)
        size = try container.decode(Double.self, forKey: .size)
        style = try container.decode(TextStyle.self, forKey: .style)
        isBold = try container.decode(Bool.self, forKey: .isBold)
        hasShadow = try container.decode(Bool.self, forKey: .hasShadow)
        // 新形式(MakeupTint)を先に試し、ダメなら旧形式(色の名前の文字列)として読む。
        if let tint = try? container.decode(MakeupTint.self, forKey: .color) {
            color = tint
        } else if let legacy = try? container.decode(LegacyTextColor.self, forKey: .color) {
            color = legacy.preset.tint
        } else {
            color = TextColorPreset.white.tint
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(center, forKey: .center)
        try container.encode(size, forKey: .size)
        try container.encode(color, forKey: .color)
        try container.encode(style, forKey: .style)
        try container.encode(isBold, forKey: .isBold)
        try container.encode(hasShadow, forKey: .hasShadow)
    }
}
