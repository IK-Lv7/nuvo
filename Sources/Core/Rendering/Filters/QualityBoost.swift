import CoreImage
import CoreImage.CIFilterBuiltins

/// 「高画質化」。2倍に拡大する。
///
/// 同梱の Core ML モデル(`RestorationModel`。実写のノイズ・圧縮劣化を学習した復元モデル)が
/// 使えるときはそれを使う。ノイズを除去しながら4倍に拡大し、書き出しの大きさをこれまでと
/// 変えないために2倍まで縮める(縮める分、モデルが復元した細部は多少失われるが、
/// ノイズ除去の効果はほぼそのまま残る)。
/// モデルが同梱されていない・読み込めない・タイル処理の途中で失敗した場合は、
/// これまで通り Lanczos 法での拡大+シャープにフォールバックする(ゼロ依存でも動く)。
enum QualityBoost {
    /// 拡大の倍率。大きくするほど書き出しが重くなるため、まずは無理のない 2 倍にとどめる。
    static let scale: CGFloat = 2
    /// 拡大後にかけるシャープの強さ。「シャープ」スライダー(ToneAdjustments)とは別に、
    /// 拡大で失われた輪郭のはっきりさを補う目的の固定値。強すぎると縁取りが目立つため、これで頭打ちにする。
    private static let sharpness: Float = 0.6

    /// `model` はモデルの読み込みコストが大きいため、呼び出し側(`ImageRenderer`)で使い回す。
    static func apply(_ p: AdjustmentParameters, to image: CIImage, context: CIContext,
                      model: RestorationModel?) -> CIImage {
        guard p.highResolution == true else { return image }
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return image }

        if let model, let restored = model.apply(to: image, context: context) {
            // モデルの拡大率(4倍)から、このアプリの「高画質化」の拡大率(2倍)まで縮める。
            let ratio = scale / (restored.extent.width / extent.width)
            let resize = CIFilter.lanczosScaleTransform()
            resize.inputImage = restored
            resize.scale = Float(ratio)
            resize.aspectRatio = 1
            if let downscaled = resize.outputImage {
                let targetExtent = CGRect(x: extent.minX * scale, y: extent.minY * scale,
                                          width: extent.width * scale, height: extent.height * scale)
                return downscaled.cropped(to: targetExtent)
            }
        }
        return applyCoreImageOnly(to: image, extent: extent)
    }

    /// Core Image 標準のフィルタだけで拡大する(モデルが使えないときのフォールバック)。
    /// 超解像 AI ほどの精細さは出ないが、通信も同梱ファイルも増えない。
    private static func applyCoreImageOnly(to image: CIImage, extent: CGRect) -> CIImage {
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
