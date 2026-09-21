import CoreGraphics
@testable import NuvoCore

/// テスト用の合成顔。座標は正規化(左上原点)。
enum TestFaces {
    static func square(eyeAt eye: CGPoint = CGPoint(x: 0.4, y: 0.45)) -> FaceLandmarks {
        let eyeSize: CGFloat = 0.06
        let eyePolygon = [
            CGPoint(x: eye.x - eyeSize, y: eye.y - eyeSize / 2), CGPoint(x: eye.x + eyeSize, y: eye.y - eyeSize / 2),
            CGPoint(x: eye.x + eyeSize, y: eye.y + eyeSize / 2), CGPoint(x: eye.x - eyeSize, y: eye.y + eyeSize / 2),
        ]
        return FaceLandmarks(
            boundingBox: CGRect(x: 0.2, y: 0.1, width: 0.6, height: 0.8),
            faceContour: [CGPoint(x: 0.2, y: 0.5), CGPoint(x: 0.3, y: 0.8), CGPoint(x: 0.5, y: 0.9),
                          CGPoint(x: 0.7, y: 0.8), CGPoint(x: 0.8, y: 0.5)],
            leftEye: eyePolygon)
    }

    /// 両目・眉・唇(口を開けた状態)を持つ合成顔。
    static func full() -> FaceLandmarks {
        func box(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> [CGPoint] {
            [CGPoint(x: cx - w / 2, y: cy - h / 2), CGPoint(x: cx + w / 2, y: cy - h / 2),
             CGPoint(x: cx + w / 2, y: cy + h / 2), CGPoint(x: cx - w / 2, y: cy + h / 2)]
        }
        var face = square()
        face.leftEye = box(0.4, 0.45, 0.12, 0.05)
        face.rightEye = box(0.6, 0.45, 0.12, 0.05)
        face.leftEyebrow = box(0.4, 0.38, 0.14, 0.03)
        face.rightEyebrow = box(0.6, 0.38, 0.14, 0.03)
        face.outerLips = box(0.5, 0.7, 0.2, 0.1)
        face.innerLips = box(0.5, 0.7, 0.1, 0.05)
        // 鼻: 小鼻と鼻先の輪郭、鼻根から鼻先へ通る鼻筋。
        face.nose = [CGPoint(x: 0.44, y: 0.58), CGPoint(x: 0.47, y: 0.62), CGPoint(x: 0.5, y: 0.63),
                     CGPoint(x: 0.53, y: 0.62), CGPoint(x: 0.56, y: 0.58)]
        face.noseCrest = [CGPoint(x: 0.5, y: 0.42), CGPoint(x: 0.5, y: 0.48), CGPoint(x: 0.5, y: 0.54), CGPoint(x: 0.5, y: 0.6)]
        return face
    }
}
