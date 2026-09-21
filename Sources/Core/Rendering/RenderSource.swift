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

    /// 証明写真の切り出し範囲(左上原点のピクセル座標)。顔が見つからない・画像内に収まらない場合は nil。
    /// 複数人が写るときは、加工する人として選ばれている中で、最も大きく写っている人を本人とみなす。
    public func idPhotoCropRect(_ spec: IDPhotoSpec, unselectedFaces: [Int] = []) -> CGRect? {
        guard let face = FaceSelection.primary(faces, excluding: unselectedFaces) else { return nil }
        // 髪を含む頭頂は、人物マスクから顔の中央付近の最上端を実測する。
        let half = face.boundingBox.width * 0.3
        let crown = subjectMask?.topEdge(columns: (face.boundingBox.midX - half)...(face.boundingBox.midX + half))
        return IDPhotoLayout.cropRect(face: face, crown: crown, imageSize: image.extent.size, spec: spec)
    }
}
