import CoreGraphics
import Foundation

/// メイク・部分補正の強さ(0...1)。
struct MakeupAmounts: Equatable, Sendable {
    var lips = 0.0
    var blush = 0.0
    var brows = 0.0
    var teeth = 0.0
    var darkCircles = 0.0
    var noseBridge = 0.0

    var isNone: Bool { lips == 0 && blush == 0 && brows == 0 && teeth == 0 && darkCircles == 0 && noseBridge == 0 }
}

/// 1人分の顔領域について、元画像・平滑化済み画像・各種マスクを保持する。
/// 重い平滑化は読み込み時に1回だけ行い、スライダー操作では `blended` の軽い合成だけを行う。
final class SkinRetouchLayers: @unchecked Sendable {
    /// 強度 100% でも元画像を 40% 残す。毛穴や質感を消しきると「のっぺり」して即座に安っぽく見えるため。
    static let smoothingCap: Float = 0.6
    /// 負の値(質感の強調)の上限。強すぎると肌荒れが目立つため半分に抑える。
    static let detailBoost: Float = 0.5
    /// 美白・暗め補正のガンマ変化量。±1 で顔が白飛び・黒つぶれしない範囲に収める初期値(要実機調整)。
    static let brightnessGamma: Float = 0.35

    // メインの色と上限。いずれも自作の初期値で、実機で見て調整する前提。
    // 上限は「塗った感」が出る手前で止める。元の質感(唇のしわ、眉の毛流れ)は輝度として残す。
    private static let lipColor: (Float, Float, Float) = (190, 60, 75)
    private static let blushColor: (Float, Float, Float) = (235, 110, 120)
    private static let browColor: (Float, Float, Float) = (70, 50, 42)
    private static let lipCap: Float = 0.75
    private static let blushCap: Float = 0.5
    private static let browCap: Float = 0.6
    /// 歯は白くしすぎると不自然(作り物に見える)ため、8 割で止める。
    private static let teethCap: Float = 0.8
    private static let darkCircleCap: Float = 0.7
    /// 血色 ±1 での赤・緑・青の増減(0〜255 の値)。赤を足して緑・青を少し抜くと、明るさをほぼ変えずに赤みだけが動く
    /// (0.299×14 − 0.587×6 − 0.114×4 ≈ 0)。初期値で、実機で見て調整する。
    private static let flushShift: (Float, Float, Float) = (14, -6, -4)
    /// 鼻筋のハイライトで、白へ寄せる割合の上限。強いと鼻だけが白く浮く。
    private static let noseBridgeLift: Float = 0.2

    /// この領域が、写真の何番目の顔か。加工する人を選ぶときに、この番号で対象から外す。
    let faceIndex: Int
    let roi: CGRect
    let width: Int
    let height: Int
    private let original: [UInt8]
    private let smoothed: [UInt8]
    private let mask: [UInt8]
    private let makeupMasks: MakeupMasks?

    init(roi: CGRect, width: Int, height: Int, original: [UInt8], smoothed: [UInt8],
         mask: [UInt8], makeupMasks: MakeupMasks? = nil, faceIndex: Int = 0) {
        self.faceIndex = faceIndex
        self.roi = roi
        self.width = width
        self.height = height
        self.original = original
        self.smoothed = smoothed
        self.mask = mask
        self.makeupMasks = makeupMasks
    }

    /// - Parameters:
    ///   - smoothing: 正で滑らかに、負で質感を強調する(-1...1)。
    ///   - brightness: 肌の明るさ(-1...1)。
    func blended(smoothing: Double, brightness: Double, makeup: MakeupAmounts = MakeupAmounts(),
                 flush: Double = 0) -> [UInt8] {
        let s = Float(min(max(smoothing, -1), 1))
        let b = Float(min(max(brightness, -1), 1))
        let f = Float(min(max(flush, -1), 1))
        let masks = makeup.isNone ? nil : makeupMasks
        guard s != 0 || b != 0 || f != 0 || masks != nil else { return original }

        let gamma = 1 / (1 + Self.brightnessGamma * b)
        let gammaTable = (0..<256).map { 255 * pow(Float($0) / 255, gamma) }
        let lipAmount = Float(min(max(makeup.lips, 0), 1)) * Self.lipCap
        let blushAmount = Float(min(max(makeup.blush, 0), 1)) * Self.blushCap
        let browAmount = Float(min(max(makeup.brows, 0), 1)) * Self.browCap
        let teethAmount = Float(min(max(makeup.teeth, 0), 1)) * Self.teethCap
        let circleAmount = Float(min(max(makeup.darkCircles, 0), 1)) * Self.darkCircleCap
        let noseAmount = Float(min(max(makeup.noseBridge, 0), 1))

        var out = original
        for i in 0..<(width * height) {
            let m = Float(mask[i]) / 255
            let lipMask = masks.map { Self.value($0.lips, i) } ?? 0
            let browMask = masks.map { Self.value($0.brows, i) } ?? 0
            let blushMask = masks.map { Self.value($0.blush, i) } ?? 0
            let teethMask = masks.map { Self.value($0.teeth, i) } ?? 0
            let circleMask = masks.map { Self.value($0.darkCircles, i) } ?? 0
            let noseMask = masks.map { Self.value($0.noseBridge, i) } ?? 0
            guard m > 0 || noseMask > 0 || lipMask > 0 || browMask > 0 || blushMask > 0 || teethMask > 0 || circleMask > 0 else {
                continue
            }

            var rgb = (Float(original[i * 4]), Float(original[i * 4 + 1]), Float(original[i * 4 + 2]))
            if m > 0 {
                let sm = (Float(smoothed[i * 4]), Float(smoothed[i * 4 + 1]), Float(smoothed[i * 4 + 2]))
                rgb = (skin(rgb.0, sm.0, m, s, b, gammaTable),
                       skin(rgb.1, sm.1, m, s, b, gammaTable),
                       skin(rgb.2, sm.2, m, s, b, gammaTable))
                if f != 0 {
                    rgb = (rgb.0 + Self.flushShift.0 * f * m, rgb.1 + Self.flushShift.1 * f * m, rgb.2 + Self.flushShift.2 * f * m)
                }
            }
            // 肌の補正のあとに乗せる。チーク → リップ → 眉の順(重なりは眉が最後に勝つ)。
            rgb = Self.colorize(rgb, target: Self.blushColor, amount: blushMask * blushAmount)
            rgb = Self.colorize(rgb, target: Self.lipColor, amount: lipMask * lipAmount)
            rgb = Self.colorize(rgb, target: Self.browColor, amount: browMask * browAmount)
            rgb = Self.whiten(rgb, amount: teethMask * teethAmount)
            rgb = Self.lift(rgb, amount: noseMask * noseAmount * Self.noseBridgeLift)
            if circleMask > 0 {
                let sm = (Float(smoothed[i * 4]), Float(smoothed[i * 4 + 1]), Float(smoothed[i * 4 + 2]))
                rgb = Self.liftDarkCircle(rgb, smoothed: sm, amount: circleMask * circleAmount)
            }

            out[i * 4] = Self.byte(rgb.0)
            out[i * 4 + 1] = Self.byte(rgb.1)
            out[i * 4 + 2] = Self.byte(rgb.2)
        }
        return out
    }

    private func skin(_ o: Float, _ sm: Float, _ m: Float, _ s: Float, _ b: Float, _ table: [Float]) -> Float {
        var v = o
        if s > 0 {
            v = o + (sm - o) * m * s * Self.smoothingCap
        } else if s < 0 {
            v = o + (o - sm) * m * -s * Self.detailBoost
        }
        if b != 0 {
            let lifted = table[Int(min(max(v, 0), 255).rounded())]
            v += (lifted - v) * m
        }
        return v
    }

    /// 元の輝度を保ったまま色味だけを目標色へ寄せる。
    /// 単純な塗りつぶしと違い、唇のしわや眉の毛流れが陰影として残る。
    private static func colorize(_ rgb: (Float, Float, Float), target: (Float, Float, Float),
                                 amount: Float) -> (Float, Float, Float) {
        guard amount > 0 else { return rgb }
        func luma(_ c: (Float, Float, Float)) -> Float { 0.299 * c.0 + 0.587 * c.1 + 0.114 * c.2 }
        let shift = luma(rgb) - luma(target)
        func mix(_ o: Float, _ t: Float) -> Float { o + (min(max(t + shift, 0), 255) - o) * amount }
        return (mix(rgb.0, target.0), mix(rgb.1, target.1), mix(rgb.2, target.2))
    }

    /// マスクの値(0...1)。旧形式のマスク(配列が短い)でも範囲外に触れないようにする。
    private static func value(_ plane: [UInt8], _ i: Int) -> Float {
        i < plane.count ? Float(plane[i]) / 255 : 0
    }

    /// 白へ寄せる。暗い部分ほど動く量が大きいので、鼻筋の立体感(明暗の差)が出る。
    private static func lift(_ rgb: (Float, Float, Float), amount: Float) -> (Float, Float, Float) {
        guard amount > 0 else { return rgb }
        return (rgb.0 + (255 - rgb.0) * amount, rgb.1 + (255 - rgb.1) * amount, rgb.2 + (255 - rgb.2) * amount)
    }

    /// 色味を抜いて少しだけ明るくする。黄ばみは色の偏りなので、無彩色へ寄せると目立たなくなる。
    private static func whiten(_ rgb: (Float, Float, Float), amount: Float) -> (Float, Float, Float) {
        guard amount > 0 else { return rgb }
        let gray = min((0.299 * rgb.0 + 0.587 * rgb.1 + 0.114 * rgb.2) * 1.06, 255)
        return (rgb.0 + (gray - rgb.0) * amount, rgb.1 + (gray - rgb.1) * amount, rgb.2 + (gray - rgb.2) * amount)
    }

    /// 周囲へ馴染ませつつ明るくする。暗い色ほど持ち上がるガンマ補正なので、明るい部分は変わりにくい。
    private static func liftDarkCircle(_ rgb: (Float, Float, Float), smoothed: (Float, Float, Float),
                                       amount: Float) -> (Float, Float, Float) {
        let gamma = 1 / (1 + 0.6 * amount)
        func lift(_ v: Float, _ s: Float) -> Float {
            let base = min(max(v + (s - v) * amount * 0.4, 0), 255)
            return 255 * pow(base / 255, gamma)
        }
        return (lift(rgb.0, smoothed.0), lift(rgb.1, smoothed.1), lift(rgb.2, smoothed.2))
    }

    /// 塊検出用。平滑化前の画素とマスクから、ニキビ・シミらしい塊を探す。
    func blemishBlobs() -> [BlemishDetector.Blob] {
        BlemishDetector.detect(rgba: original, mask: mask, width: width, height: height,
                               faceWidth: Double(roi.width) * 0.75)
    }

    private static func byte(_ v: Float) -> UInt8 { UInt8(min(max(v, 0), 255).rounded()) }
}
