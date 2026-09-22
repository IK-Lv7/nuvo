import CoreGraphics

/// 1人分の顔ランドマーク。
/// 座標は画像サイズに依存しない正規化座標(0...1、左上原点)で持つ。
/// プレビューで検出した結果を、フル解像度の書き出しにもそのまま使うため。
public struct FaceLandmarks: Equatable, Sendable {
    public var boundingBox: CGRect
    public var faceContour: [CGPoint]
    public var leftEye: [CGPoint]
    public var rightEye: [CGPoint]
    public var leftEyebrow: [CGPoint]
    public var rightEyebrow: [CGPoint]
    public var outerLips: [CGPoint]
    public var innerLips: [CGPoint]
    /// 鼻の輪郭(小鼻・鼻先)と、鼻筋(鼻根から鼻先へ通る線)。
    public var nose: [CGPoint]
    public var noseCrest: [CGPoint]
    /// 瞳の中心。Vision が返さないこともあるため、空のことがある(カラコンでは目の重心で代用する)。
    public var leftPupil: [CGPoint]
    public var rightPupil: [CGPoint]

    public init(boundingBox: CGRect,
                faceContour: [CGPoint] = [],
                leftEye: [CGPoint] = [], rightEye: [CGPoint] = [],
                leftEyebrow: [CGPoint] = [], rightEyebrow: [CGPoint] = [],
                outerLips: [CGPoint] = [], innerLips: [CGPoint] = [],
                nose: [CGPoint] = [], noseCrest: [CGPoint] = [],
                leftPupil: [CGPoint] = [], rightPupil: [CGPoint] = []) {
        self.boundingBox = boundingBox
        self.faceContour = faceContour
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.leftEyebrow = leftEyebrow
        self.rightEyebrow = rightEyebrow
        self.outerLips = outerLips
        self.innerLips = innerLips
        self.nose = nose
        self.noseCrest = noseCrest
        self.leftPupil = leftPupil
        self.rightPupil = rightPupil
    }
}
