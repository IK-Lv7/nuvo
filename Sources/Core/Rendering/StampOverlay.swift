import CoreGraphics
import Foundation

/// スタンプに使える SF Symbols(Apple 標準のアイコン)の一覧。
/// 独自の画像素材は同梱しない(文字入れがシステムフォントのみなのと同じ方針)。
/// 数が多いと選びにくいため、よく使われそうな種類だけを選んでいる。
/// SF Symbols の名前は Xcode がないと最終確認できないため、実機・Xcode での見た目確認を推奨する。
public enum StampSymbol: String, CaseIterable, Sendable {
    case heart = "heart.fill"
    case heartCircle = "heart.circle.fill"
    case star = "star.fill"
    case starCircle = "star.circle.fill"
    case sparkles
    case sun = "sun.max.fill"
    case moon = "moon.fill"
    case moonStars = "moon.stars.fill"
    case cloud = "cloud.fill"
    case bolt = "bolt.fill"
    case flame = "flame.fill"
    case drop = "drop.fill"
    case leaf = "leaf.fill"
    case paw = "pawprint.fill"
    case crown = "crown.fill"
    case gift = "gift.fill"
    case smile = "face.smiling.fill"
    case thumbsUp = "hand.thumbsup.fill"
    case music = "music.note"
    case camera = "camera.fill"
    case airplane
    case umbrella = "umbrella.fill"
    case snowflake
    case trophy = "trophy.fill"

    /// SF Symbols の名前(rawValue そのもの)。`StampOverlay.symbolName` に渡す。
    public var symbolName: String { rawValue }
}

/// 写真に重ねるスタンプ。位置・大きさは画像サイズに依存しない値で持つので、プレビューでも書き出しでも同じ見た目になる。
/// 文字入れ(TextOverlay)と同じ考え方で、色は共通の `TextColor` を使う。
public struct StampOverlay: Equatable, Sendable, Codable, Identifiable {
    public var id: UUID
    /// SF Symbols の名前("heart.fill" など)。
    public var symbolName: String
    /// 中心(0...1、左上原点)。
    public var center: CGPoint
    /// 大きさ(画像の短辺に対する比)。
    public var size: Double
    public var color: TextColor

    public static let sizeRange: ClosedRange<Double> = 0.05...0.4

    public init(id: UUID = UUID(), symbolName: String, center: CGPoint = CGPoint(x: 0.5, y: 0.5),
                size: Double = 0.15, color: TextColor = .white) {
        self.id = id
        self.symbolName = symbolName
        self.center = center
        self.size = size
        self.color = color
    }
}
