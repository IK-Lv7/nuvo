import CoreGraphics
import CoreImage

/// 複数の写真を1枚に組み合わせる、決まったレイアウト。各写真が入る枠は、
/// キャンバスに対する相対位置(0...1、左上原点)で持つので、大きさに依存しない。
public enum CollageLayout: String, CaseIterable, Sendable {
    case twoSideBySide, twoStacked
    case threeBigLeft, threeBigTop, threeColumns
    case fourGrid, fourColumns, fourRows

    public var slots: [CGRect] {
        switch self {
        case .twoSideBySide:
            [CGRect(x: 0, y: 0, width: 0.5, height: 1), CGRect(x: 0.5, y: 0, width: 0.5, height: 1)]
        case .twoStacked:
            [CGRect(x: 0, y: 0, width: 1, height: 0.5), CGRect(x: 0, y: 0.5, width: 1, height: 0.5)]
        case .threeBigLeft:
            [CGRect(x: 0, y: 0, width: 0.6, height: 1),
             CGRect(x: 0.6, y: 0, width: 0.4, height: 0.5), CGRect(x: 0.6, y: 0.5, width: 0.4, height: 0.5)]
        case .threeBigTop:
            [CGRect(x: 0, y: 0, width: 1, height: 0.6),
             CGRect(x: 0, y: 0.6, width: 0.5, height: 0.4), CGRect(x: 0.5, y: 0.6, width: 0.5, height: 0.4)]
        case .threeColumns:
            (0..<3).map { CGRect(x: CGFloat($0) / 3, y: 0, width: 1.0 / 3, height: 1) }
        case .fourGrid:
            [CGRect(x: 0, y: 0, width: 0.5, height: 0.5), CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5),
             CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5), CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)]
        case .fourColumns:
            (0..<4).map { CGRect(x: CGFloat($0) / 4, y: 0, width: 0.25, height: 1) }
        case .fourRows:
            (0..<4).map { CGRect(x: 0, y: CGFloat($0) / 4, width: 1, height: 0.25) }
        }
    }

    public var slotCount: Int { slots.count }

    /// 選んだ枚数に合うレイアウトだけを返す(2〜4枚に対応)。
    public static func layouts(forCount count: Int) -> [CollageLayout] {
        allCases.filter { $0.slotCount == count }
    }
}

/// 複数の写真を、決まったレイアウトで1枚に組み合わせる。組み合わせたあとは、
/// 通常の1枚の写真として、以降の編集(フィルター・文字入れなど)を適用できる。
public enum CollageComposer {
    public static func compose(images: [CIImage], layout: CollageLayout, canvasSize: CGSize,
                               spacingRatio: CGFloat, background: BackgroundColor) -> CIImage? {
        guard images.count == layout.slotCount, canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        let spacing = min(canvasSize.width, canvasSize.height) * max(spacingRatio, 0)
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        var result = CIImage(color: background.ciColor).cropped(to: canvasRect)

        for (image, slot) in zip(images, layout.slots) {
            let rawRect = CGRect(x: slot.minX * canvasSize.width, y: slot.minY * canvasSize.height,
                                 width: slot.width * canvasSize.width, height: slot.height * canvasSize.height)
            let tileRect = rawRect.insetBy(dx: spacing / 2, dy: spacing / 2)
            guard tileRect.width >= 1, tileRect.height >= 1 else { continue }

            let filled = aspectFilled(image, to: tileRect.size)
            // レイアウトの枠は上が 0 の正規化座標だが、Core Image は左下原点のため、y を反転する。
            let flippedY = canvasSize.height - tileRect.maxY
            let positioned = filled.transformed(by: CGAffineTransform(translationX: tileRect.minX, y: flippedY))
            result = positioned.composited(over: result)
        }
        return result.cropped(to: canvasRect)
    }

    /// 縦横比を保ったまま拡大・縮小し、目的の大きさぴったりに中央から切り出す
    /// (`UIView.ContentMode.scaleAspectFill` と同じ考え方)。
    private static func aspectFilled(_ image: CIImage, to size: CGSize) -> CIImage {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return image }
        let scale = max(size.width / extent.width, size.height / extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let scaledExtent = scaled.extent
        let cropRect = CGRect(x: scaledExtent.midX - size.width / 2, y: scaledExtent.midY - size.height / 2,
                              width: size.width, height: size.height)
        return scaled.cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -cropRect.minX, y: -cropRect.minY))
    }
}
