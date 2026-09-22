import CoreGraphics
import Foundation

/// スタンプに使える SF Symbols(Apple 標準のアイコン)の一覧。独自に描き起こした画像素材は同梱しない方針
/// (文字入れがシステムフォントのみなのと同じ考え方)。色つきの絵がほしい場合は `EmojiStamp` を使う。
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

/// スタンプに使える、同梱の絵文字画像(OpenMoji。ライセンスは THIRD_PARTY_NOTICES.md 参照)。
/// SF Symbols には無い「色つきの可愛い」見た目がほしいという要望から追加した
/// (ハート・キラキラ系だけを選んでいる。全絵文字は同梱しない)。
/// `EmojiStampRenderer` がファイル名(rawValue)で `Sources/Core/Resources/Stamps/` から読み込む。
public enum EmojiStamp: String, CaseIterable, Sendable {
    case heart, twoHearts, sparklingHeart, growingHeart, beatingHeart, heartArrow, revolvingHearts
    case sparkles, glowingStar, star, dizzy, ribbon, cherryBlossom

    /// `Sources/Core/Resources/Stamps/` 内の画像ファイル名(拡張子抜き)。`StampOverlay.imageAssetName` に渡す。
    public var assetName: String { rawValue }

    /// 絵文字画像が(万一)読み込めなかったときの、見た目が近い SF Symbols での代わり。
    var fallbackSymbolName: String {
        switch self {
        case .heart, .twoHearts, .sparklingHeart, .growingHeart, .beatingHeart, .heartArrow, .revolvingHearts:
            "heart.fill"
        case .sparkles, .glowingStar, .dizzy:
            "sparkles"
        case .star:
            "star.fill"
        case .ribbon, .cherryBlossom:
            "gift.fill"
        }
    }
}

/// 写真に重ねるスタンプ。位置・大きさは画像サイズに依存しない値で持つので、プレビューでも書き出しでも同じ見た目になる。
/// 文字入れ(TextOverlay)と同じ考え方で、色は共通の `TextColor` を使う(絵文字画像には効かない。下記参照)。
public struct StampOverlay: Equatable, Sendable, Codable, Identifiable {
    public var id: UUID
    /// SF Symbols の名前("heart.fill" など)。`imageAssetName` がある場合は使わない
    /// (どちらの場合も入れておくと、絵文字画像が将来読み込めなくなったときの見た目の手がかりになる)。
    public var symbolName: String
    /// 同梱の絵文字画像(`EmojiStamp.assetName`)を使う場合はこちら。nil なら `symbolName`(SF Symbols)を使う。
    /// すでに色がついた画像のため、`color` は効かない。
    /// 既存の保存済みルック(この項目がない)を読めるよう、nil をデコード時の既定値にする。
    public var imageAssetName: String?
    /// 中心(0...1、左上原点)。
    public var center: CGPoint
    /// 大きさ(画像の短辺に対する比)。
    public var size: Double
    public var color: TextColor

    public static let sizeRange: ClosedRange<Double> = 0.05...0.4

    public init(id: UUID = UUID(), symbolName: String, imageAssetName: String? = nil,
                center: CGPoint = CGPoint(x: 0.5, y: 0.5), size: Double = 0.15, color: TextColor = .white) {
        self.id = id
        self.symbolName = symbolName
        self.imageAssetName = imageAssetName
        self.center = center
        self.size = size
        self.color = color
    }

    /// 絵文字画像のスタンプを作る(SF Symbols のフォールバック名も持たせる)。
    public init(id: UUID = UUID(), emoji: EmojiStamp, center: CGPoint = CGPoint(x: 0.5, y: 0.5), size: Double = 0.15) {
        self.init(id: id, symbolName: emoji.fallbackSymbolName, imageAssetName: emoji.assetName,
                  center: center, size: size)
    }
}
