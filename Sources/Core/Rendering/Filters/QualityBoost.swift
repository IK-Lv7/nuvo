import CoreImage
import CoreImage.CIFilterBuiltins

/// 「高画質化」。Lanczos 法で拡大し、拡大でぼける分をシャープで補う。
/// 超解像 AI(学習済みモデル)は使わない。ゼロ依存の方針を保つため、Core Image 標準のフィルタだけで構成する
/// (AGENTS.md 第2章・第3章: 外部依存なし)。AI ほどの精細さは出ないが、通信も同梱ファイルも増えない。
enum QualityBoost {
    /// 拡大の倍率。大きくするほど書き出しが重くなるため、まずは無理のない 2 倍にとどめる。
    static let scale: CGFloat = 2
    /// 拡大後にかけるシャープの強さ。「シャープ」スライダー(ToneAdjustments)とは別に、
    /// 拡大で失われた輪郭のはっきりさを補う目的の固定値。強すぎると縁取りが目立つため、これで頭打ちにする。
    private static let sharpness: Float = 0.6

    static func apply(_ p: AdjustmentParameters, to image: CIImage) -> CIImage {
        guard p.highResolution == true else { return image }
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return image }

        let resize = CIFilter.lanczosScaleTransform()
        resize.inputImage = image
        resize.scale = Float(scale)
        resize.aspectRatio = 1
        guard let scaled = resize.outputImage else { return image }

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = scaled
        sharpen.sharpness = sharpness
        let sharpened = sharpen.outputImage ?? scaled

        // 拡大後の範囲(元の原点も同じ比率で動くため、それを基準に計算する)。
        let scaledExtent = CGRect(x: extent.minX * scale, y: extent.minY * scale,
                                  width: extent.width * scale, height: extent.height * scale)
        return sharpened.cropped(to: scaledExtent)
    }
}
