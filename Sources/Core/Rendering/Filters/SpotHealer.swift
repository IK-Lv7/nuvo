import CoreGraphics
import CoreImage
import Foundation

/// タップした位置のニキビ・シミを、周囲の肌色で埋める。
/// 周囲のリング上の色を採取して中央値を取り、境界をぼかして馴染ませる。
/// 中央値なので、リング上に別のシミや毛が混じっても引きずられにくい。
enum SpotHealer {
    /// 修復範囲より少し外側から色を採る(範囲内のシミ自身を拾わないため)。
    private static let ringScale = 1.6
    private static let ringSamples = 24
    /// 修復範囲の外側をぼかす幅(半径に対する比)。境目が浮かないようにする。
    private static let featherRatio = 0.25

    static func apply(_ spots: [HealSpot], to image: CIImage, context: CIContext) -> CIImage {
        let size = image.extent.size
        let bounds = CGRect(origin: .zero, size: size)
        let longEdge = max(size.width, size.height)
        var result = image

        for spot in spots {
            let radius = max(spot.radius * longEdge, 3)
            let half = (radius * 2.2).rounded(.up)
            let center = CGPoint(x: spot.center.x * size.width, y: spot.center.y * size.height)
            let rect = CGRect(x: center.x - half, y: center.y - half, width: half * 2, height: half * 2)
                .integral.intersection(bounds).integral
            guard rect.width >= 4, rect.height >= 4,
                  let patch = BitmapIO.crop(result, topLeftRect: rect, context: context),
                  var pixels = BitmapIO.rgba(from: patch) else { continue }

            heal(rgba: &pixels, width: patch.width, height: patch.height,
                 center: CGPoint(x: center.x - rect.minX, y: center.y - rect.minY), radius: radius)
            guard let healed = BitmapIO.cgImage(fromRGBA: pixels, width: patch.width, height: patch.height) else {
                continue
            }
            result = BitmapIO.overlay(healed, atTopLeft: rect.origin, on: result)
        }
        return result
    }

    /// `center` は画素の左上を原点とする連続座標(画素 i の中心は i + 0.5)。
    static func heal(rgba: inout [UInt8], width: Int, height: Int, center: CGPoint, radius: Double) {
        guard radius >= 1, width > 0, height > 0, rgba.count == width * height * 4 else { return }

        var channels: [[Int]] = [[], [], []]
        for k in 0..<ringSamples {
            let angle = 2 * Double.pi * Double(k) / Double(ringSamples)
            let x = min(max(Int((center.x + cos(angle) * radius * ringScale).rounded(.down)), 0), width - 1)
            let y = min(max(Int((center.y + sin(angle) * radius * ringScale).rounded(.down)), 0), height - 1)
            for c in 0..<3 { channels[c].append(Int(rgba[(y * width + x) * 4 + c])) }
        }
        let target = channels.map { $0.sorted()[$0.count / 2] }

        let feather = radius * featherRatio
        let outer = radius + feather
        let minX = max(0, Int((center.x - outer).rounded(.down)))
        let maxX = min(width - 1, Int((center.x + outer).rounded(.up)))
        let minY = max(0, Int((center.y - outer).rounded(.down)))
        let maxY = min(height - 1, Int((center.y + outer).rounded(.up)))
        guard minX <= maxX, minY <= maxY else { return }

        for y in minY...maxY {
            for x in minX...maxX {
                let distance = hypot(Double(x) + 0.5 - center.x, Double(y) + 0.5 - center.y)
                let weight: Double
                if distance <= radius {
                    weight = 1
                } else if distance >= outer {
                    weight = 0
                } else {
                    let t = (distance - radius) / feather
                    weight = 1 - t * t * (3 - 2 * t)
                }
                guard weight > 0 else { continue }
                let i = (y * width + x) * 4
                for c in 0..<3 {
                    let value = Double(rgba[i + c]) * (1 - weight) + Double(target[c]) * weight
                    rgba[i + c] = UInt8(min(max(value.rounded(), 0), 255))
                }
            }
        }
    }
}
