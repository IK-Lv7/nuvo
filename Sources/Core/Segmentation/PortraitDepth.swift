import CoreGraphics
import Foundation

/// ポートレートモードで撮った写真に含まれる深度(視差)から、ピントの合っている被写体のマスクを作る。
/// 背景のぼかしに使うと、人物の切り抜きより奥行きに応じた自然なぼけ方になる。
enum PortraitDepth {
    /// 正規化した視差(0...1)の差がこれ以下なら、ピントが合っている(=完全に被写体)とみなす。
    private static let fullFocusDifference: Float = 0.08
    /// 差がこれ以上なら完全に背景。間は滑らかにつなぐ。
    private static let noFocusDifference: Float = 0.22

    /// - Parameters:
    ///   - disparity: 視差の画像(8bit グレー)。大きいほど手前。
    ///   - focus: ピントを合わせる領域(0...1、左上原点)。この領域の中央値を「ピントの深度」とする。
    static func focusMask(disparity: [UInt8], width: Int, height: Int, focus: CGRect) -> [UInt8]? {
        guard width > 0, height > 0, disparity.count == width * height,
              let low = disparity.min(), let high = disparity.max(), high > low else { return nil }
        let lowValue = Float(low)
        let range = Float(high - low)

        let x0 = min(max(Int(focus.minX * CGFloat(width)), 0), width - 1)
        let x1 = min(max(Int(focus.maxX * CGFloat(width)), x0), width - 1)
        let y0 = min(max(Int(focus.minY * CGFloat(height)), 0), height - 1)
        let y1 = min(max(Int(focus.maxY * CGFloat(height)), y0), height - 1)
        var samples: [UInt8] = []
        for y in y0...y1 {
            for x in x0...x1 { samples.append(disparity[y * width + x]) }
        }
        let focusValue = (Float(samples.sorted()[samples.count / 2]) - lowValue) / range

        return disparity.map { value in
            let difference = abs((Float(value) - lowValue) / range - focusValue)
            let t = min(max((noFocusDifference - difference) / (noFocusDifference - fullFocusDifference), 0), 1)
            return UInt8((t * t * (3 - 2 * t) * 255).rounded())
        }
    }
}
