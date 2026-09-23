import CoreGraphics

/// メイクの色。0...1 の RGB で持つ。SwiftUI の `Color` にも、加工計算の 0...255 の値にも変換できる。
public struct MakeupTint: Codable, Equatable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    /// 0...255 の RGB から作る(色の資料はこの単位で書かれていることが多いため)。
    public init(r: Double, g: Double, b: Double) {
        self.init(red: r / 255, green: g / 255, blue: b / 255)
    }

    var rgb255: (Float, Float, Float) { (Float(red) * 255, Float(green) * 255, Float(blue) * 255) }

    /// 文字入れ・スタンプの塗りに使う(不透明)。
    public var cgColor: CGColor {
        CGColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
    }
}

/// リップに使う色見本。名前は色の系統を表す一般的な言葉で、既存アプリの商品名は使わない。
/// RGB は自作の初期値で、実機で見て調整する前提。
public enum LipstickPreset: String, CaseIterable, Sendable {
    case nude, coral, rose, berry, brick, plum

    public var tint: MakeupTint {
        switch self {
        case .nude: MakeupTint(r: 200, g: 140, b: 125)
        case .coral: MakeupTint(r: 222, g: 104, b: 92)
        // 血色調整と同じ色(以前からの固定値)。見本の並びでは基準として中央に置く。
        case .rose: MakeupTint(r: 190, g: 60, b: 75)
        case .berry: MakeupTint(r: 150, g: 45, b: 80)
        case .brick: MakeupTint(r: 170, g: 70, b: 55)
        case .plum: MakeupTint(r: 120, g: 55, b: 90)
        }
    }
}

/// アイシャドウに使う色見本。リップと同じ方針(一般的な言葉の名前、自作の初期値)。
public enum EyeshadowPreset: String, CaseIterable, Sendable {
    case brown, pink, coral, gold, khaki, lavender

    public var tint: MakeupTint {
        switch self {
        // 既定色。いちばん使いやすい、肌になじむ茶。
        case .brown: MakeupTint(r: 150, g: 105, b: 85)
        case .pink: MakeupTint(r: 215, g: 140, b: 150)
        case .coral: MakeupTint(r: 220, g: 135, b: 110)
        case .gold: MakeupTint(r: 205, g: 165, b: 100)
        case .khaki: MakeupTint(r: 140, g: 135, b: 95)
        case .lavender: MakeupTint(r: 160, g: 140, b: 190)
        }
    }
}

/// カラコン(カラーコンタクト)に使う色見本。虹彩の模様は輝度として残すので、色味だけを決める。
public enum LensPreset: String, CaseIterable, Sendable {
    case brown, hazel, gray, blue, green, olive

    public var tint: MakeupTint {
        switch self {
        // 既定色。日本人の瞳になじむ明るい茶。
        case .brown: MakeupTint(r: 110, g: 75, b: 50)
        case .hazel: MakeupTint(r: 145, g: 110, b: 60)
        case .gray: MakeupTint(r: 110, g: 110, b: 115)
        case .blue: MakeupTint(r: 80, g: 120, b: 165)
        case .green: MakeupTint(r: 85, g: 130, b: 100)
        case .olive: MakeupTint(r: 120, g: 120, b: 80)
        }
    }
}

/// チークに使う色見本。リップと同じ方針(一般的な言葉の名前、自作の初期値)。
public enum BlushPreset: String, CaseIterable, Sendable {
    case pink, coral, peach, rose, apricot, mauve

    public var tint: MakeupTint {
        switch self {
        // 以前からの固定値。見本の並びでは基準として中央に置く。
        case .pink: MakeupTint(r: 235, g: 110, b: 120)
        case .coral: MakeupTint(r: 240, g: 130, b: 100)
        case .peach: MakeupTint(r: 245, g: 170, b: 140)
        case .rose: MakeupTint(r: 220, g: 100, b: 130)
        case .apricot: MakeupTint(r: 235, g: 150, b: 110)
        case .mauve: MakeupTint(r: 200, g: 120, b: 140)
        }
    }
}
