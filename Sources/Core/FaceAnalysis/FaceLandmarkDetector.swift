import CoreGraphics
import Vision

/// Vision による顔ランドマーク検出。処理が重いためバックグラウンドから呼ぶこと。
/// 入力は向きを反映済み(上向き)の画像であること。
public struct FaceLandmarkDetector: Sendable {
    public init() {}

    public func detect(in image: CGImage) throws -> [FaceLandmarks] {
        let request = VNDetectFaceLandmarksRequest()
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? []).compactMap(Self.makeLandmarks)
    }

    static func makeLandmarks(from observation: VNFaceObservation) -> FaceLandmarks? {
        guard let landmarks = observation.landmarks, let contour = landmarks.faceContour else { return nil }
        let box = observation.boundingBox
        func points(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            (region?.normalizedPoints ?? []).map {
                CoordinateConversion.visionLandmarkToTopLeftUnit($0, boundingBox: box)
            }
        }
        return FaceLandmarks(
            boundingBox: CoordinateConversion.visionNormalizedToTopLeft(box, imageSize: CGSize(width: 1, height: 1)),
            faceContour: points(contour),
            leftEye: points(landmarks.leftEye), rightEye: points(landmarks.rightEye),
            leftEyebrow: points(landmarks.leftEyebrow), rightEyebrow: points(landmarks.rightEyebrow),
            outerLips: points(landmarks.outerLips), innerLips: points(landmarks.innerLips),
            nose: points(landmarks.nose), noseCrest: points(landmarks.noseCrest),
            leftPupil: points(landmarks.leftPupil), rightPupil: points(landmarks.rightPupil))
    }
}
