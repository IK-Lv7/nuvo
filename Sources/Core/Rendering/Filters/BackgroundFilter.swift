import CoreImage
import CoreImage.CIFilterBuiltins

/// 背景の単色。証明写真で一般的な色から選ぶ(初期値。実機で見て調整する)。
public enum BackgroundColor: String, CaseIterable, Sendable, Codable {
    case white, lightBlue, lightGray

    var ciColor: CIColor {
        switch self {
        case .white: CIColor(red: 1, green: 1, blue: 1)
        case .lightBlue: CIColor(red: 0.72, green: 0.85, blue: 0.98)
        case .lightGray: CIColor(red: 0.90, green: 0.90, blue: 0.90)
        }
    }
}

/// 人物マスクを使った背景のぼかし・単色化。
enum BackgroundFilter {
    /// ぼかし 100% のときの半径(長辺比)。長辺 1536px で約 30px。
    /// これ以上は被写体との境目のにじみが目立つため上限にしている。
    private static let maxBlurRatio = 0.02

    static func apply(blur: Double, color: BackgroundColor?, mask: SubjectMask, to image: CIImage) -> CIImage {
        let extent = image.extent
        let background: CIImage
        if let color {
            background = CIImage(color: color.ciColor).cropped(to: extent)
        } else if blur > 0 {
            let filter = CIFilter.gaussianBlur()
            // 端の色を延長してからぼかす(端が暗く沈むのを防ぐ)。
            filter.inputImage = image.clampedToExtent()
            filter.radius = Float(min(blur, 1) * maxBlurRatio * max(extent.width, extent.height))
            background = (filter.outputImage ?? image).cropped(to: extent)
        } else {
            return image
        }

        let maskExtent = mask.image.extent
        guard maskExtent.width > 0, maskExtent.height > 0 else { return image }
        let scaledMask = mask.image.transformed(by: CGAffineTransform(
            scaleX: extent.width / maskExtent.width, y: extent.height / maskExtent.height))

        let blend = CIFilter.blendWithMask()
        blend.inputImage = image
        blend.backgroundImage = background
        blend.maskImage = scaledMask
        return blend.outputImage?.cropped(to: extent) ?? image
    }
}
