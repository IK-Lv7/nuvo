import CoreGraphics
import CoreImage

/// 画像内の全ての顔に対する肌補正とメイク。`prepare` が重く、`apply` が軽い。
final class SkinRetouch: @unchecked Sendable {
    /// 輝度差がこの程度までは同じ肌とみなして均す。ニキビ・色ムラの輝度差(10〜30)を均し、
    /// 目や輪郭の強いエッジ(60 以上)は保つ値。
    private static let rangeSigma = 25.0
    /// 平滑化の半径は顔幅の 1.2%。大きいと質感まで消え、小さいと効果が出ない。
    private static let radiusRatio = 0.012

    private let layers: [SkinRetouchLayers]

    private init(layers: [SkinRetouchLayers]) {
        self.layers = layers
    }

    static func prepare(image: CIImage, faces: [FaceLandmarks], context: CIContext) -> SkinRetouch? {
        let size = image.extent.size
        let bounds = CGRect(origin: .zero, size: size)
        var layers: [SkinRetouchLayers] = []

        for (faceIndex, face) in faces.enumerated() {
            let polygon = FaceGeometry.scaled(FaceGeometry.skinPolygon(face), to: size)
            let margin = size.width * 0.01
            let rect = FaceGeometry.boundingRect(of: polygon)
                .insetBy(dx: -margin, dy: -margin).integral.intersection(bounds).integral
            guard rect.width >= 8, rect.height >= 8,
                  let patch = BitmapIO.crop(image, topLeftRect: rect, context: context),
                  let original = BitmapIO.rgba(from: patch) else { continue }

            let width = patch.width, height = patch.height
            let mask = SkinMask.make(face: face, imageSize: size, roiOrigin: rect.origin,
                                     width: width, height: height, rgba: original)
            let faceWidth = face.boundingBox.width * size.width
            let radius = min(max(Int((faceWidth * radiusRatio).rounded()), 2), 8)
            let smoothed = BilateralFilter.apply(rgba: original, mask: mask, width: width, height: height,
                                                 radius: radius, rangeSigma: rangeSigma)
            let makeup = MakeupMasks.make(face: face, skinMask: mask, rgba: original, imageSize: size,
                                          roiOrigin: rect.origin, width: width, height: height)
            layers.append(SkinRetouchLayers(roi: rect, width: width, height: height, original: original,
                                            smoothed: smoothed, mask: mask, makeupMasks: makeup,
                                            faceIndex: faceIndex))
        }
        return layers.isEmpty ? nil : SkinRetouch(layers: layers)
    }

    func apply(_ p: AdjustmentParameters, to image: CIImage) -> CIImage {
        let makeup = MakeupAmounts(lips: p.lipstick, lipColor: p.lipstickColor ?? LipstickPreset.rose.tint,
                                   blush: p.blush, blushColor: p.blushColor ?? BlushPreset.pink.tint,
                                   brows: p.eyebrow, teeth: p.teethWhitening, darkCircles: p.darkCircles, noseBridge: p.noseBridge)
        var result = image
        let excluded = Set(p.excludedFaces)
        for layer in layers where !excluded.contains(layer.faceIndex) {
            let pixels = layer.blended(smoothing: p.skinSmoothing, brightness: p.skinBrightness, makeup: makeup,
                                           flush: p.skinFlush)
            guard let patch = BitmapIO.cgImage(fromRGBA: pixels, width: layer.width, height: layer.height) else {
                continue
            }
            result = BitmapIO.overlay(patch, atTopLeft: layer.roi.origin, on: result)
        }
        return result
    }

    /// ニキビ・シミらしい塊を、画像全体に対する相対座標の修復位置として返す。
    func detectBlemishes(imageSize: CGSize) -> [HealSpot] {
        let longEdge = max(imageSize.width, imageSize.height)
        guard imageSize.width > 0, imageSize.height > 0 else { return [] }
        return layers.flatMap { layer in
            layer.blemishBlobs().map { blob in
                HealSpot(center: CGPoint(x: (layer.roi.minX + blob.center.x) / imageSize.width,
                                         y: (layer.roi.minY + blob.center.y) / imageSize.height),
                         radius: blob.radius / longEdge)
            }
        }
    }
}
