import CoreGraphics
import Foundation

/// 肌の中から、周囲より暗い・赤い小さな塊(ニキビ・シミ)を見つける。
/// 毛穴や肌のざらつきは弱く、目や眉のような大きな構造は塊が大きすぎるため、大きさと形で除外する。
enum BlemishDetector {
    struct Blob: Equatable {
        var center: CGPoint
        var radius: Double
    }

    /// 周囲との差(暗さ + 赤み)がこの値を超えた画素を候補とする。
    /// 肌のざらつきは 8 程度までに収まり、ニキビ・シミは 15〜40 程度になることを目安にした初期値。
    private static let threshold: Float = 14
    private static let rednessWeight: Float = 0.7
    private static let maxBlobs = 24

    /// - Parameter faceWidth: 顔の幅(ピクセル)。塊の大きさの基準に使う。
    static func detect(rgba: [UInt8], mask: [UInt8], width: Int, height: Int, faceWidth: Double) -> [Blob] {
        guard width > 0, height > 0, rgba.count == width * height * 4, mask.count == width * height else { return [] }

        let pixelCount = width * height
        var luma = [UInt8](repeating: 0, count: pixelCount)
        var redness = [UInt8](repeating: 0, count: pixelCount)
        for i in 0..<pixelCount {
            let r = Float(rgba[i * 4]), g = Float(rgba[i * 4 + 1]), b = Float(rgba[i * 4 + 2])
            luma[i] = UInt8(min(max(0.299 * r + 0.587 * g + 0.114 * b, 0), 255))
            // R - G は赤みの指標。負にもなるため 128 を足して 8bit に収める。
            redness[i] = UInt8(min(max(r - g + 128, 0), 255))
        }
        let radius = max(3, Int(faceWidth * 0.03))
        let localLuma = SkinMask.boxBlur(luma, width: width, height: height, radius: radius)
        let localRedness = SkinMask.boxBlur(redness, width: width, height: height, radius: radius)

        var candidate = [Bool](repeating: false, count: pixelCount)
        for i in 0..<pixelCount where mask[i] > 200 {
            let darkness = Float(localLuma[i]) - Float(luma[i])
            let redExcess = Float(redness[i]) - Float(localRedness[i])
            candidate[i] = darkness + rednessWeight * redExcess > threshold
        }

        let minArea = Double.pi * pow(faceWidth * 0.005, 2)
        let maxArea = Double.pi * pow(faceWidth * 0.04, 2)
        var visited = [Bool](repeating: false, count: pixelCount)
        var blobs: [Blob] = []

        for start in 0..<pixelCount where candidate[start] && !visited[start] {
            var stack = [start]
            visited[start] = true
            var area = 0
            var sumX = 0.0, sumY = 0.0
            var minX = width, maxX = 0, minY = height, maxY = 0
            while let index = stack.popLast() {
                let x = index % width, y = index / width
                area += 1
                sumX += Double(x) + 0.5
                sumY += Double(y) + 0.5
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                for dy in -1...1 {
                    for dx in -1...1 {
                        let nx = x + dx, ny = y + dy
                        guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                        let neighbor = ny * width + nx
                        if candidate[neighbor] && !visited[neighbor] {
                            visited[neighbor] = true
                            stack.append(neighbor)
                        }
                    }
                }
            }

            let boxWidth = Double(maxX - minX + 1), boxHeight = Double(maxY - minY + 1)
            let aspect = max(boxWidth, boxHeight) / min(boxWidth, boxHeight)
            let fill = Double(area) / (boxWidth * boxHeight)
            // 丸くて小さい塊だけを残す(細長い線=毛や輪郭、環状=大きな影の縁を除く)。
            guard Double(area) >= minArea, Double(area) <= maxArea, aspect <= 2.2, fill >= 0.35 else { continue }
            let blobRadius = (Double(area) / Double.pi).squareRoot() * 1.4 + 1
            blobs.append(Blob(center: CGPoint(x: sumX / Double(area), y: sumY / Double(area)), radius: blobRadius))
        }
        return Array(blobs.prefix(maxBlobs))
    }
}
