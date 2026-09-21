import CoreGraphics
import CoreImage

/// 反転・回転・傾き補正・縦横比の切り出し・ズーム。適用順は 反転 → 回転 → 傾き補正 → 縦横比 → ズーム。
enum GeometryAdjust {
    /// 傾き補正スライダー ±1 に対応する角度。水平の微調整には ±30° あれば十分で、
    /// それ以上は余白の切り落としが大きくなりすぎる。
    static let maxStraightenDegrees = 30.0

    static func apply(_ p: AdjustmentParameters, to image: CIImage) -> CIImage {
        let turns = ((p.rotationQuarterTurns % 4) + 4) % 4
        guard turns != 0 || p.flipHorizontal || p.straighten != 0 || p.cropAspect != nil || p.cropZoom > 1 else { return image }

        var result = originAtZero(image)
        if p.flipHorizontal {
            result = originAtZero(result.transformed(by: CGAffineTransform(scaleX: -1, y: 1)))
        }
        if turns != 0 {
            // Core Image の座標は上が正なので、時計回りは負の角度。
            result = originAtZero(result.transformed(by: CGAffineTransform(rotationAngle: -CGFloat.pi / 2 * CGFloat(turns))))
        }
        if p.straighten != 0 {
            result = straightened(result, degrees: p.straighten * maxStraightenDegrees)
        }
        if let aspect = p.cropAspect {
            result = centerCropped(result, ratio: aspect.ratio)
        }
        if p.cropZoom > 1 {
            result = zoomed(result, zoom: p.cropZoom, center: p.cropCenter)
        }
        return result
    }

    /// 縦横とも 1/zoom の範囲を、`center`(0...1、左上原点)を中心に切り出す。範囲が画像の外に出ないよう、中心を内側へ寄せる。
    static func zoomed(_ image: CIImage, zoom: Double, center: CGPoint) -> CIImage {
        let width = image.extent.width, height = image.extent.height
        guard zoom > 1, width > 0, height > 0 else { return image }
        let cropWidth = width / CGFloat(zoom), cropHeight = height / CGFloat(zoom)
        let x = min(max(center.x * width - cropWidth / 2, 0), width - cropWidth)
        // Core Image は上が正なので、左上原点の中心 y を反転して扱う。
        let y = min(max((1 - center.y) * height - cropHeight / 2, 0), height - cropHeight)
        return originAtZero(image.cropped(to: snapped(CGRect(x: x, y: y, width: cropWidth, height: cropHeight))))
    }

    /// 画像の中心で回し、回転で生じる余白が出ない最大の矩形(元と同じ縦横比)に切り出す。
    static func straightened(_ image: CIImage, degrees: Double) -> CIImage {
        let width = image.extent.width, height = image.extent.height
        guard width > 0, height > 0 else { return image }
        let radians = CGFloat(degrees) * .pi / 180  // 正で時計回り
        let center = CGPoint(x: width / 2, y: height / 2)
        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: -radians)
            .translatedBy(x: -center.x, y: -center.y)
        let scale = inscribedScale(width: width, height: height, radians: abs(radians))
        let crop = CGRect(x: center.x - width * scale / 2, y: center.y - height * scale / 2,
                          width: width * scale, height: height * scale)
        return originAtZero(image.transformed(by: transform).cropped(to: snapped(crop)))
    }

    /// 幅 w・高さ h の画像を θ 回した内側に収まる、同じ縦横比の最大矩形の倍率。
    /// 切り出し矩形の四隅が、回した元画像の内側にある条件から求める:
    /// s(cosθ + (h/w)sinθ) ≤ 1 かつ s(cosθ + (w/h)sinθ) ≤ 1。
    static func inscribedScale(width: CGFloat, height: CGFloat, radians: CGFloat) -> CGFloat {
        guard width > 0, height > 0 else { return 1 }
        let longer = max(width / height, height / width)
        return 1 / (cos(radians) + longer * sin(radians))
    }

    static func centerCropped(_ image: CIImage, ratio: CGFloat) -> CIImage {
        let width = image.extent.width, height = image.extent.height
        guard width > 0, height > 0, ratio > 0 else { return image }
        let newWidth = width / height > ratio ? height * ratio : width
        let newHeight = width / height > ratio ? height : width / ratio
        let crop = CGRect(x: (width - newWidth) / 2, y: (height - newHeight) / 2,
                          width: newWidth, height: newHeight)
        return originAtZero(image.cropped(to: snapped(crop)))
    }

    /// 原点を (0, 0) に戻す。回転で生じる 1e-13 程度の誤差で、切り出しが 1px ずれないよう整数に丸める。
    private static func originAtZero(_ image: CIImage) -> CIImage {
        let extent = image.extent
        let moved = image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
        return moved.cropped(to: snapped(moved.extent))
    }

    private static func snapped(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX.rounded(), y: rect.minY.rounded(),
               width: rect.width.rounded(), height: rect.height.rounded())
    }
}
