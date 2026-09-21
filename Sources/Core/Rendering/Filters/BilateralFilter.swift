import Foundation

/// エッジ保存平滑化。近くて色(輝度)の近い画素ほど重く平均するため、
/// 肌の細かいムラやニキビは均す一方、目・輪郭のような強いエッジは保たれる。
/// ガウスぼかしと違い、境界までは溶けない。
enum BilateralFilter {
    /// `mask` が 0 の画素は計算を省き、元の値をそのまま返す(顔領域だけを処理するための最適化)。
    static func apply(rgba source: [UInt8], mask: [UInt8], width: Int, height: Int,
                      radius: Int, rangeSigma: Double) -> [UInt8] {
        var output = source
        guard radius > 0, width > 0, height > 0, mask.count == width * height else { return output }

        let luma = (0..<(width * height)).map { i in
            (77 * Int(source[i * 4]) + 150 * Int(source[i * 4 + 1]) + 29 * Int(source[i * 4 + 2])) >> 8
        }
        let rangeWeights = (0..<256).map { Float(exp(-Double($0 * $0) / (2 * rangeSigma * rangeSigma))) }
        let spatialSigma = Double(radius) / 2
        var spatialWeights: [Float] = []
        for dy in -radius...radius {
            for dx in -radius...radius {
                let d2 = Double(dx * dx + dy * dy)
                spatialWeights.append(Float(exp(-d2 / (2 * spatialSigma * spatialSigma))))
            }
        }

        source.withUnsafeBufferPointer { src in
            luma.withUnsafeBufferPointer { lum in
                mask.withUnsafeBufferPointer { msk in
                    output.withUnsafeMutableBufferPointer { out in
                        DispatchQueue.concurrentPerform(iterations: height) { y in
                            for x in 0..<width {
                                let i = y * width + x
                                guard msk[i] > 0 else { continue }
                                let center = lum[i]
                                var sumR: Float = 0, sumG: Float = 0, sumB: Float = 0, sumW: Float = 0
                                var k = 0
                                for dy in -radius...radius {
                                    let yy = min(max(y + dy, 0), height - 1)
                                    for dx in -radius...radius {
                                        let xx = min(max(x + dx, 0), width - 1)
                                        let j = yy * width + xx
                                        let w = spatialWeights[k] * rangeWeights[abs(lum[j] - center)]
                                        k += 1
                                        sumR += w * Float(src[j * 4])
                                        sumG += w * Float(src[j * 4 + 1])
                                        sumB += w * Float(src[j * 4 + 2])
                                        sumW += w
                                    }
                                }
                                out[i * 4] = UInt8(min(sumR / sumW + 0.5, 255))
                                out[i * 4 + 1] = UInt8(min(sumG / sumW + 0.5, 255))
                                out[i * 4 + 2] = UInt8(min(sumB / sumW + 0.5, 255))
                            }
                        }
                    }
                }
            }
        }
        return output
    }
}
