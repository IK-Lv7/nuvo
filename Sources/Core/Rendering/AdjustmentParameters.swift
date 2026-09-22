import CoreGraphics
import Foundation

/// スポット修復の1箇所。座標・半径は画像サイズに依存しない値で持つ。
public struct HealSpot: Equatable, Sendable, Codable {
    /// 画像内の位置(0...1、左上原点)。
    public var center: CGPoint
    /// 画像の長辺に対する半径の比。
    public var radius: Double

    /// ニキビ・シミの大きさに合わせた既定値(長辺 1536px のプレビューで約 30px)。
    public static let defaultRadius = 0.02

    public init(center: CGPoint, radius: Double = HealSpot.defaultRadius) {
        self.center = center
        self.radius = radius
    }
}

/// 全調整値を保持する単一の値型。UI は書き換えるだけ、レンダラは読むだけ。
/// Undo/Redo はこの構造体のスナップショットで実現する。
public struct AdjustmentParameters: Equatable, Sendable, Codable {
    /// スライダー値の有効範囲。中央 0 の双方向スライダーに合わせて -1...1 に統一する。
    public static let range: ClosedRange<Double> = -1...1
    /// フィルター強度の有効範囲。
    public static let intensityRange: ClosedRange<Double> = 0...1
    /// 構図のズーム倍率。1 が全体、4 で縦横とも 1/4 の範囲を切り出す。
    public static let zoomRange: ClosedRange<Double> = 1...4
    /// 「切り抜きを直す」ペンの、太さの調整範囲(画像の長辺に対する比)。
    public static let maskBrushRadiusRange: ClosedRange<Double> = 0.01...0.12

    /// 肌。正で滑らかに、負で質感を強調する。
    public var skinSmoothing: Double = 0
    public var skinBrightness: Double = 0
    /// 血色。正で赤みを足し、負で赤みを抑える。
    public var skinFlush: Double = 0

    /// 顔立ち。小顔は正で輪郭を内側へ、目は正で拡大、あごは正で短く。
    public var faceSlim: Double = 0
    public var eyeEnlarge: Double = 0
    public var chin: Double = 0
    /// 鼻。正で小鼻を細く、負で広げる。鼻筋は 0...1 でハイライトを乗せる。
    public var noseSlim: Double = 0
    public var noseBridge: Double = 0

    /// メイクの濃さ(0...1)。
    public var lipstick: Double = 0
    /// リップの色。nil は既定の色(LipstickPreset.rose と同じ)。
    public var lipstickColor: MakeupTint?
    public var blush: Double = 0
    public var eyebrow: Double = 0
    public var teethWhitening: Double = 0
    public var darkCircles: Double = 0

    /// 背景。単色は人物マスクが取れているときだけ効く。単色を選ぶとぼかしより優先される。
    public var backgroundBlur: Double = 0
    public var backgroundColor: BackgroundColor?
    /// 選ぶと規格に合わせて切り出す(顔が見つからない・収まらない場合は切り出さない)。
    public var idPhoto: IDPhotoSpec?

    /// 仕上げ。
    public var autoEnhance = false
    /// 高画質化(2倍に拡大し、拡大でぼける分をシャープで補う)。書き出しの大きさ・時間が増える。
    /// nil は「しない」(以前のバージョンで保存したルックにこの項目がなくても読めるようにする)。
    public var highResolution: Bool?
    public var sharpness: Double = 0
    public var vignette: Double = 0
    /// 質感。フィルムの粒子感と、光が漏れたような色のにじみ。
    public var filmGrain: Double = 0
    public var lightLeak: Double = 0
    public var warmth: Double = 0
    public var shadows: Double = 0
    public var highlightRecovery: Double = 0

    public var brightness: Double = 0
    public var contrast: Double = 0
    public var saturation: Double = 0

    public var filter: FilterPreset?
    public var filterIntensity: Double = 1

    public var spots: [HealSpot] = []
    /// 背景の切り抜きを、ペンで直した線。nil(または空)は自動検出のまま。
    public var maskStrokes: [MaskStroke]?

    /// 構図。回転は時計回りに 90° の回数(0...3)、傾き補正は ±1 が ±30°。
    public var rotationQuarterTurns = 0
    public var flipHorizontal = false
    public var straighten: Double = 0
    public var cropAspect: CropAspect?
    /// ズーム(アップ)。切り出す範囲の中心は、構図を決めた枠に対する相対位置(0...1、左上原点)。
    public var cropZoom: Double = 1
    public var cropCenter = CGPoint(x: 0.5, y: 0.5)

    public var texts: [TextOverlay] = []
    /// スタンプ(SF Symbols)。nil(または空)は「なし」。
    public var stamps: [StampOverlay]?

    /// 加工の対象から外した顔の番号(検出順)。nil は全員が対象。
    /// 保存済みのルックにこの項目が無くても読めるよう、空配列ではなく nil を「全員」とする。
    public var unselectedFaces: [Int]?

    public init() {}

    /// 初期状態(未調整)か。書き出し時の無駄な再処理を避けるために使う。
    /// 対象から外した顔の番号。全員が対象なら空。
    public var excludedFaces: [Int] { unselectedFaces ?? [] }

    public var isIdentity: Bool { self == AdjustmentParameters() }

    var hasSkinOrMakeup: Bool {
        skinSmoothing != 0 || skinBrightness != 0 || skinFlush != 0 || noseBridge != 0 || lipstick != 0 || blush != 0 || eyebrow != 0
            || teethWhitening != 0 || darkCircles != 0
    }

    /// 範囲外の値を有効範囲に収めた複製を返す。
    public func clamped() -> AdjustmentParameters {
        var result = self
        result.skinSmoothing = Self.clamp(skinSmoothing, to: Self.range)
        result.skinBrightness = Self.clamp(skinBrightness, to: Self.range)
        result.faceSlim = Self.clamp(faceSlim, to: Self.range)
        result.eyeEnlarge = Self.clamp(eyeEnlarge, to: Self.range)
        result.chin = Self.clamp(chin, to: Self.range)
        result.noseSlim = Self.clamp(noseSlim, to: Self.range)
        result.noseBridge = Self.clamp(noseBridge, to: Self.intensityRange)
        result.skinFlush = Self.clamp(skinFlush, to: Self.range)
        result.filmGrain = Self.clamp(filmGrain, to: Self.intensityRange)
        result.lightLeak = Self.clamp(lightLeak, to: Self.intensityRange)
        result.lipstick = Self.clamp(lipstick, to: Self.intensityRange)
        result.blush = Self.clamp(blush, to: Self.intensityRange)
        result.eyebrow = Self.clamp(eyebrow, to: Self.intensityRange)
        result.teethWhitening = Self.clamp(teethWhitening, to: Self.intensityRange)
        result.darkCircles = Self.clamp(darkCircles, to: Self.intensityRange)
        result.backgroundBlur = Self.clamp(backgroundBlur, to: Self.intensityRange)
        result.sharpness = Self.clamp(sharpness, to: Self.intensityRange)
        result.vignette = Self.clamp(vignette, to: Self.intensityRange)
        result.warmth = Self.clamp(warmth, to: Self.range)
        result.shadows = Self.clamp(shadows, to: Self.range)
        result.highlightRecovery = Self.clamp(highlightRecovery, to: Self.intensityRange)
        result.brightness = Self.clamp(brightness, to: Self.range)
        result.contrast = Self.clamp(contrast, to: Self.range)
        result.saturation = Self.clamp(saturation, to: Self.range)
        result.filterIntensity = Self.clamp(filterIntensity, to: Self.intensityRange)
        result.straighten = Self.clamp(straighten, to: Self.range)
        result.cropZoom = Self.clamp(cropZoom, to: Self.zoomRange)
        result.cropCenter = CGPoint(x: min(max(cropCenter.x, 0), 1), y: min(max(cropCenter.y, 0), 1))
        result.rotationQuarterTurns = ((rotationQuarterTurns % 4) + 4) % 4
        return result
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// 「ルック」として保存・適用する範囲。写真ごとの内容(修復の位置・構図・文字・スタンプ・証明写真・加工する人・切り抜きの直し)は含めない。
    public func lookOnly() -> AdjustmentParameters {
        var look = self
        look.spots = []
        look.texts = []
        look.rotationQuarterTurns = 0
        look.flipHorizontal = false
        look.straighten = 0
        look.cropAspect = nil
        look.cropZoom = 1
        look.cropCenter = CGPoint(x: 0.5, y: 0.5)
        look.idPhoto = nil
        look.unselectedFaces = nil
        look.maskStrokes = nil
        look.stamps = nil
        return look
    }

    /// ルックを当てる。写真ごとの内容(修復の位置・構図・文字・スタンプ・証明写真・切り抜きの直し)は、今の写真のものを保つ。
    public func applyingLook(_ look: AdjustmentParameters) -> AdjustmentParameters {
        var result = look.lookOnly()
        result.spots = spots
        result.texts = texts
        result.rotationQuarterTurns = rotationQuarterTurns
        result.flipHorizontal = flipHorizontal
        result.straighten = straighten
        result.cropAspect = cropAspect
        result.cropZoom = cropZoom
        result.cropCenter = cropCenter
        result.idPhoto = idPhoto
        result.unselectedFaces = unselectedFaces
        result.maskStrokes = maskStrokes
        result.stamps = stamps
        return result
    }
}

