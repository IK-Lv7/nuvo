import CoreGraphics
import CoreImage

/// スタンプ(SF Symbols)を画像に焼き込む。文字入れ(TextRenderer)と同じ考え方で、
/// 位置・大きさは画像サイズに依存しない値を使うので、プレビューでも書き出しでも同じ見た目になる。
enum StampRenderer {
    static func apply(_ stamps: [StampOverlay], to image: CIImage) -> CIImage {
        // 文字と同じ理由で、はみ出しても書き出す画像の大きさは変えない。
        let extent = image.extent
        var result = image
        for stamp in stamps {
            guard let patch = render(stamp, imageSize: extent.size) else { continue }
            let cx = extent.minX + stamp.center.x * extent.width
            let cy = extent.maxY - stamp.center.y * extent.height
            let moved = CIImage(cgImage: patch).transformed(by: CGAffineTransform(
                translationX: cx - CGFloat(patch.width) / 2, y: cy - CGFloat(patch.height) / 2))
            result = moved.composited(over: result).cropped(to: extent)
        }
        return result
    }

    private static func render(_ stamp: StampOverlay, imageSize: CGSize) -> CGImage? {
        let pointSize = CGFloat(min(max(stamp.size, 0.01), 1)) * min(imageSize.width, imageSize.height)
        guard pointSize >= 4 else { return nil }
        return SymbolRenderer.image(symbolName: stamp.symbolName, pointSize: pointSize, color: stamp.color.cgColor)
    }
}
