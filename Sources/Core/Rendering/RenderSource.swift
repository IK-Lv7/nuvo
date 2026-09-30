import CoreGraphics
import CoreImage

/// 加工の入力。画像と、事前計算済みの肌補正・人物マスクをまとめて保持する。
/// 顔検出・切り抜き・肌の平滑化は重いため、画像の読み込み時に1回だけ作って使い回す。
public final class RenderSource: @unchecked Sendable {
    public let image: CIImage
    let faces: [FaceLandmarks]
    let retouch: SkinRetouch?
    let subjectMask: SubjectMask?
    /// ポートレート写真の深度から作ったマスク。背景のぼかしで、切り抜きより優先して使う。
    let depthMask: SubjectMask?

    init(image: CIImage, faces: [FaceLandmarks], retouch: SkinRetouch?, subjectMask: SubjectMask?,
         depthMask: SubjectMask? = nil) {
        self.image = image
        self.faces = faces
        self.retouch = retouch
        self.subjectMask = subjectMask
        self.depthMask = depthMask
    }

    /// 検出した顔の数。加工する人を選ぶ操作は、2 人以上のときだけ意味がある。
    public var faceCount: Int { faces.count }
    public var faceBoxes: [CGRect] { faces.map(\.boundingBox) }

    public var hasSubjectMask: Bool { subjectMask != nil }
    public var hasDepthMask: Bool { depthMask != nil }

    /// ニキビ・シミらしい箇所を自動で探す。
    public func detectBlemishes() -> [HealSpot] {
        retouch?.detectBlemishes(imageSize: image.extent.size) ?? []
    }

}
