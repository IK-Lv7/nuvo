import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// 自作フィルター。既存アプリの LUT は流用せず、数式から 3D LUT を生成する。
public enum FilterPreset: String, CaseIterable, Sendable, Codable {
    case warm, cool, film, fade, vivid, mono
    case sunset, peach, rose, mint, sky, matte
    case cinematic, vintage, noir, pastel, polaroid, moody
}

public enum LUTFilter {
    static let dimension = 32

    /// 使用時に初めて生成し、以降は保持する(起動時に全プリセットを作らないため)。
    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [FilterPreset: Data] = [:]

        func data(for preset: FilterPreset, make: () -> Data) -> Data {
            lock.lock()
            defer { lock.unlock() }
            if let cached = storage[preset] { return cached }
            let data = make()
            storage[preset] = data
            return data
        }
    }
    private static let cache = Cache()

    public static func apply(_ preset: FilterPreset, intensity: Double, to image: CIImage) -> CIImage {
        let amount = min(max(intensity, 0), 1)
        guard amount > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return image }

        let filter = CIFilter.colorCubeWithColorSpace()
        filter.inputImage = image
        filter.cubeDimension = Float(dimension)
        filter.cubeData = cubeData(for: preset)
        filter.colorSpace = space
        guard let filtered = filter.outputImage else { return image }
        guard amount < 1 else { return filtered }

        let mix = CIFilter.dissolveTransition()
        mix.inputImage = image
        mix.targetImage = filtered
        mix.time = Float(amount)
        return mix.outputImage ?? filtered
    }

    /// RGBA(Float, プリマルチ済み)で R が最も速く変化する並び。CIColorCube の規約に合わせる。
    public static func cubeData(for preset: FilterPreset) -> Data {
        cache.data(for: preset) {
            let n = dimension
            var values: [Float] = []
            values.reserveCapacity(n * n * n * 4)
            for b in 0..<n {
                for g in 0..<n {
                    for r in 0..<n {
                        let scale = Float(n - 1)
                        let (tr, tg, tb) = transform(preset, r: Float(r) / scale, g: Float(g) / scale, b: Float(b) / scale)
                        values.append(contentsOf: [tr, tg, tb, 1])
                    }
                }
            }
            return values.withUnsafeBufferPointer { Data(buffer: $0) }
        }
    }

    // 以下の係数はすべて自作の初期値。実機で見て調整する前提。
    static func transform(_ preset: FilterPreset, r: Float, g: Float, b: Float) -> (Float, Float, Float) {
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        func saturate(_ c: Float, _ k: Float) -> Float { luma + (c - luma) * k }
        func curve(_ c: Float, _ k: Float) -> Float { c + k * (c * c * (3 - 2 * c) - c) }
        func clamp(_ c: Float) -> Float { min(max(c, 0), 1) }

        switch preset {
        case .warm:
            return (clamp(r * 1.06 + 0.02), clamp(g + 0.005), clamp(b * 0.92))
        case .cool:
            return (clamp(r * 0.94), clamp(g), clamp(b * 1.06 + 0.02))
        case .film:
            // 黒を少し持ち上げ、影を青緑・ハイライトを暖色へ寄せる。
            func base(_ c: Float) -> Float { curve(0.04 + c * 0.94, 0.35) }
            return (clamp(base(r) - 0.02 * (1 - luma) + 0.03 * luma),
                    clamp(base(g)),
                    clamp(base(b) + 0.02 * (1 - luma) - 0.03 * luma))
        case .fade:
            func lift(_ c: Float) -> Float { 0.08 + saturate(c, 0.9) * 0.86 }
            return (clamp(lift(r)), clamp(lift(g)), clamp(lift(b)))
        case .vivid:
            return (clamp(curve(saturate(r, 1.3), 0.2)), clamp(curve(saturate(g, 1.3), 0.2)),
                    clamp(curve(saturate(b, 1.3), 0.2)))
        case .mono:
            let y = clamp(curve(luma, 0.3))
            return (y, y, y)
        case .sunset:
            // 夕焼け。全体を暖色へ寄せ、影に紅を残す。
            return (clamp(curve(0.02 + r * 1.10, 0.15)), clamp(g * 0.96 + 0.01), clamp(b * 0.82 + 0.03 * (1 - luma)))
        case .peach:
            func base(_ c: Float) -> Float { 0.05 + saturate(c, 0.95) * 0.92 }
            return (clamp(base(r) + 0.04), clamp(base(g) + 0.015), clamp(base(b) - 0.02))
        case .rose:
            func base(_ c: Float) -> Float { 0.03 + c * 0.94 }
            return (clamp(base(r) + 0.05), clamp(base(g) - 0.02), clamp(base(b) + 0.03))
        case .mint:
            func base(_ c: Float) -> Float { 0.04 + saturate(c, 0.95) * 0.93 }
            return (clamp(base(r) - 0.03), clamp(base(g) + 0.03), clamp(base(b) + 0.01))
        case .sky:
            return (clamp(saturate(r, 1.05) * 0.92), clamp(saturate(g, 1.05) + 0.01), clamp(saturate(b, 1.05) * 1.08 + 0.02))
        case .matte:
            // 黒を持ち上げ、白を落とした、ツヤのない仕上がり。
            func base(_ c: Float) -> Float { 0.07 + saturate(c, 0.9) * 0.88 }
            return (clamp(base(r)), clamp(base(g)), clamp(base(b)))
        case .cinematic:
            // 映画調。影を青緑、ハイライトを橙へ振る。
            return (clamp(curve(r, 0.3) + 0.07 * luma - 0.04 * (1 - luma)),
                    clamp(curve(g, 0.3)),
                    clamp(curve(b, 0.3) - 0.06 * luma + 0.05 * (1 - luma)))
        case .vintage:
            let sepiaR = 0.393 * r + 0.769 * g + 0.189 * b
            let sepiaG = 0.349 * r + 0.686 * g + 0.168 * b
            let sepiaB = 0.272 * r + 0.534 * g + 0.131 * b
            func blend(_ original: Float, _ sepia: Float) -> Float { 0.05 + (original * 0.4 + sepia * 0.6) * 0.92 }
            return (clamp(blend(r, sepiaR)), clamp(blend(g, sepiaG)), clamp(blend(b, sepiaB)))
        case .noir:
            // モノクロより強いコントラストで、全体をやや暗く。
            let y = clamp(curve(luma, 0.7) * 0.95)
            return (y, y, y)
        case .pastel:
            func base(_ c: Float) -> Float { 0.10 + saturate(c, 0.75) * 0.88 }
            return (clamp(base(r) + 0.02), clamp(base(g)), clamp(base(b)))
        case .polaroid:
            // インスタントフィルム風。黒を持ち上げ、暖色の中に影の青緑を少し残す。
            func base(_ c: Float) -> Float { 0.06 + c * 0.90 }
            return (clamp(base(r) * 1.04), clamp(base(g) + 0.02 * (1 - luma)), clamp(base(b) * 0.94 + 0.03 * (1 - luma)))
        case .moody:
            // 暗く落ち着いた、彩度を抑えた青緑寄りの色。
            func base(_ c: Float) -> Float { curve(saturate(c * 0.9, 0.8), 0.35) }
            return (clamp(base(r) - 0.02), clamp(base(g)), clamp(base(b) + 0.02 * (1 - luma)))
        }
    }
}
