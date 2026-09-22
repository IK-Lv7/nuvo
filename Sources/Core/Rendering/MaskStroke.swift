import CoreGraphics

/// 「切り抜きを直す」ペンで描いた、1回分(指を触れてから離すまで)の軌跡。
/// 座標・太さは画像サイズに依存しない値で持つ(HealSpot と同じ考え方。プレビューでも書き出しでも同じ線になる)。
public struct MaskStroke: Codable, Equatable, Sendable {
    /// 足す(人物として残す)か、消す(背景として扱う)か。
    public enum Mode: String, Codable, Sendable {
        case keep, erase
    }

    /// 軌跡上の点(0...1、左上原点)。ドラッグ中に少しずつ増える。
    public var points: [CGPoint]
    /// 画像の長辺に対する、線の太さの半径の比。
    public var radius: Double
    public var mode: Mode

    public init(points: [CGPoint], radius: Double, mode: Mode) {
        self.points = points
        self.radius = radius
        self.mode = mode
    }

    /// 境界をぼかす幅(太さに対する比)。SpotHealer と同じ考え方で、継ぎ目を目立たなくする。
    private static let featherRatio = 0.25

    /// この線に沿って、太さ分の値をグレーのバイト列に書き込む(255 = 人物として残す、0 = 背景として扱う)。
    /// 点と点の間は太い線分として塗るので、ドラッグの軌跡がつながって見える。
    func rasterize(into gray: inout [UInt8], width: Int, height: Int) {
        guard width > 0, height > 0, !points.isEmpty, gray.count == width * height else { return }
        let longEdge = Double(max(width, height))
        let r = max(radius * longEdge, 1)
        let feather = max(r * Self.featherRatio, 1)
        let target = Float(mode == .keep ? 255 : 0)

        func stamp(from a: CGPoint, to b: CGPoint) {
            let ax = Double(a.x) * Double(width), ay = Double(a.y) * Double(height)
            let bx = Double(b.x) * Double(width), by = Double(b.y) * Double(height)
            let minX = max(0, Int((min(ax, bx) - r - feather).rounded(.down)))
            let maxX = min(width - 1, Int((max(ax, bx) + r + feather).rounded(.up)))
            let minY = max(0, Int((min(ay, by) - r - feather).rounded(.down)))
            let maxY = min(height - 1, Int((max(ay, by) + r + feather).rounded(.up)))
            guard minX <= maxX, minY <= maxY else { return }

            let dx = bx - ax, dy = by - ay
            let lengthSquared = dx * dx + dy * dy
            for y in minY...maxY {
                for x in minX...maxX {
                    let px = Double(x) + 0.5, py = Double(y) + 0.5
                    // 線分上の最も近い点(点なら、その点)への距離。
                    let t = lengthSquared > 0
                        ? min(max(((px - ax) * dx + (py - ay) * dy) / lengthSquared, 0), 1) : 0
                    let distance = hypot(px - (ax + dx * t), py - (ay + dy * t))
                    guard distance <= r + feather else { continue }
                    let weight: Float
                    if distance <= r {
                        weight = 1
                    } else {
                        let u = Float((distance - r) / feather)
                        weight = 1 - u * u * (3 - 2 * u)
                    }
                    let i = y * width + x
                    gray[i] = UInt8((Float(gray[i]) * (1 - weight) + target * weight).rounded())
                }
            }
        }

        if points.count == 1 {
            stamp(from: points[0], to: points[0])
        } else {
            for i in 0..<(points.count - 1) { stamp(from: points[i], to: points[i + 1]) }
        }
    }
}
