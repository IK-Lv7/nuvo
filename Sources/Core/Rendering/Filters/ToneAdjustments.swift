import CoreImage
import CoreImage.CIFilterBuiltins

/// Core Image 標準フィルタによる仕上げ調整。
enum ToneAdjustments {
    /// 色温度の ±1 に対する赤・青の増減。±8% なら色かぶりに見えず、はっきり暖色・寒色になる(初期値)。
    private static let warmthGain = 0.08
    /// シャープの最大値。それ以上は肌の粗が目立つ(初期値)。
    private static let maxSharpness = 1.5

    /// Core Image が画像を解析して選ぶ自動補正。
    static func autoEnhance(_ image: CIImage) -> CIImage {
        var result = image
        for filter in image.autoAdjustmentFilters(options: [.enhance: true, .redEye: false]) {
            filter.setValue(result, forKey: kCIInputImageKey)
            result = filter.outputImage ?? result
        }
        return result
    }

    /// 粒子の大きさの基準となる長辺。プレビューと書き出しで、粒の見た目(画面に対する大きさ)を揃えるため、
    /// 画像の長辺がこれを超える分だけ、粒を大きくする。
    private static let grainReferenceEdge: CGFloat = 1536
    /// 粒子・光漏れの最大の濃さ。これ以上は、写真が荒れたり、色に埋もれたりする(初期値)。
    private static let grainMaxAlpha = 0.5
    private static let leakMaxAlpha = 0.85

    /// 適用順: 影・ハイライト → 色温度 → シャープ → ビネット → 光漏れ → 粒子
    /// (粒子を最後にして、ぼかしやシャープの影響を受けないようにする)。
    static func apply(_ p: AdjustmentParameters, to image: CIImage) -> CIImage {
        var result = image
        if p.shadows != 0 || p.highlightRecovery != 0 {
            let filter = CIFilter.highlightShadowAdjust()
            filter.inputImage = result
            filter.shadowAmount = Float(p.shadows)
            // 1 が無変化で、小さいほどハイライトを抑える。
            filter.highlightAmount = Float(1 - p.highlightRecovery)
            result = filter.outputImage ?? result
        }
        if p.warmth != 0 {
            let k = CGFloat(p.warmth * warmthGain)
            let filter = CIFilter.colorMatrix()
            filter.inputImage = result
            filter.rVector = CIVector(x: 1 + k, y: 0, z: 0, w: 0)
            filter.gVector = CIVector(x: 0, y: 1, z: 0, w: 0)
            filter.bVector = CIVector(x: 0, y: 0, z: 1 - k, w: 0)
            filter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            filter.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)
            result = filter.outputImage ?? result
        }
        if p.sharpness > 0 {
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = result
            filter.sharpness = Float(p.sharpness * maxSharpness)
            result = filter.outputImage ?? result
        }
        if p.vignette > 0 {
            let extent = result.extent
            let filter = CIFilter.vignetteEffect()
            filter.inputImage = result
            filter.center = CGPoint(x: extent.midX, y: extent.midY)
            filter.radius = Float(min(extent.width, extent.height) * 0.75)
            filter.intensity = Float(p.vignette)
            filter.falloff = 0.5
            result = filter.outputImage?.cropped(to: extent) ?? result
        }
        if p.lightLeak > 0 { result = lightLeak(result, amount: p.lightLeak) }
        if p.filmGrain > 0 { result = grain(result, amount: p.filmGrain) }
        return result
    }

    /// 端から光が漏れたような、暖色の色のにじみ。右上の橙と、左下の桃色を、スクリーン合成で重ねる。
    static func lightLeak(_ image: CIImage, amount: Double) -> CIImage {
        let extent = image.extent
        let longEdge = max(extent.width, extent.height)
        let alpha = CGFloat(min(max(amount, 0), 1) * leakMaxAlpha)

        func glow(center: CGPoint, radius: CGFloat, color: CIColor) -> CIImage? {
            let gradient = CIFilter.radialGradient()
            gradient.center = center
            gradient.radius0 = 0
            gradient.radius1 = Float(radius)
            gradient.color0 = color
            gradient.color1 = CIColor(red: color.red, green: color.green, blue: color.blue, alpha: 0)
            return gradient.outputImage?.cropped(to: extent)
        }
        var result = image
        let layers = [
            glow(center: CGPoint(x: extent.maxX, y: extent.maxY), radius: longEdge * 0.9,
                 color: CIColor(red: 1, green: 0.55, blue: 0.22, alpha: alpha)),
            glow(center: CGPoint(x: extent.minX, y: extent.minY), radius: longEdge * 0.6,
                 color: CIColor(red: 1, green: 0.25, blue: 0.5, alpha: alpha * 0.6)),
        ]
        for case let layer? in layers {
            let blend = CIFilter.screenBlendMode()
            blend.inputImage = layer
            blend.backgroundImage = result
            result = blend.outputImage?.cropped(to: extent) ?? result
        }
        return result
    }

    /// フィルムのような粒子。灰色(中間値)を中心にしたノイズを、ソフトライトで重ねる。
    /// ノイズの並びは固定なので、同じ設定なら何度描いても同じ見た目になる。
    static func grain(_ image: CIImage, amount: Double) -> CIImage {
        guard let noise = CIFilter.randomGenerator().outputImage else { return image }
        let extent = image.extent
        let scale = max(1, max(extent.width, extent.height) / grainReferenceEdge)

        // 乱数は RGBA が独立なので、RGB を平均して無彩色のノイズにし、透明度で濃さを決める。
        let monochrome = CIFilter.colorMatrix()
        monochrome.inputImage = noise
        monochrome.rVector = CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0)
        monochrome.gVector = CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0)
        monochrome.bVector = CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0)
        monochrome.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        monochrome.biasVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(min(max(amount, 0), 1) * grainMaxAlpha))
        guard let gray = monochrome.outputImage else { return image }

        let sized = gray.transformed(by: CGAffineTransform(scaleX: scale, y: scale)).cropped(to: extent)
        let blend = CIFilter.softLightBlendMode()
        blend.inputImage = sized
        blend.backgroundImage = image
        return blend.outputImage?.cropped(to: extent) ?? image
    }
}
