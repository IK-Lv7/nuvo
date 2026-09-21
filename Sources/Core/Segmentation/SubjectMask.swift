import CoreImage
import Foundation

/// 人物の切り抜きマスク(白が人物、黒が背景)。元画像と同じ向き。
/// 画像は加工の解像度に合わせて拡大縮小して使うため、検出はプレビュー解像度で1回だけ行えばよい。
public final class SubjectMask: @unchecked Sendable {
    let image: CIImage
    private let gray: [UInt8]
    private let width: Int
    private let height: Int

    init?(image: CIImage, context: CIContext) {
        guard let cgImage = context.createCGImage(image, from: image.extent),
              let rgba = BitmapIO.rgba(from: cgImage) else { return nil }
        self.image = image
        width = cgImage.width
        height = cgImage.height
        gray = stride(from: 0, to: rgba.count, by: 4).map { rgba[$0] }
    }

    /// 8bit グレーのバイト列(255 が人物)から作る。深度から作ったマスクに使う。
    init?(grayBytes: [UInt8], width: Int, height: Int) {
        guard width > 0, height > 0, grayBytes.count == width * height else { return nil }
        let rgba: [UInt8] = grayBytes.flatMap { [$0, $0, $0, 255] }
        guard let cgImage = BitmapIO.cgImage(fromRGBA: rgba, width: width, height: height) else { return nil }
        self.image = CIImage(cgImage: cgImage)
        self.width = width
        self.height = height
        self.gray = grayBytes
    }

    /// 指定した横範囲(0...1)で、人物が最初に現れる行(0...1、上が 0)。
    /// 証明写真で、髪を含む頭頂の位置を実測するために使う。
    func topEdge(columns: ClosedRange<CGFloat>) -> CGFloat? {
        let first = max(0, Int(columns.lowerBound * CGFloat(width)))
        let last = min(width - 1, Int(columns.upperBound * CGFloat(width)))
        guard first <= last else { return nil }
        for y in 0..<height {
            for x in first...last where gray[y * width + x] > 127 {
                return CGFloat(y) / CGFloat(height)
            }
        }
        return nil
    }
}
