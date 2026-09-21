import CoreImage
import CoreVideo
import Vision

/// Vision による人物の切り抜き。端末内で完結し、外部モデルや通信は使わない。
/// 処理が重いためバックグラウンドから呼ぶこと。入力は向きを反映済み(上向き)の画像であること。
struct SubjectSegmenter: Sendable {
    func segment(_ image: CGImage, context: CIContext) throws -> SubjectMask? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])

        guard let buffer = request.results?.first?.pixelBuffer else { return nil }
        let raw = CIImage(cvPixelBuffer: buffer)
        guard raw.extent.width > 0, raw.extent.height > 0 else { return nil }
        // マスクは入力より小さいことがあるため、元画像と同じ大きさに拡大しておく。
        let scaled = raw.transformed(by: CGAffineTransform(
            scaleX: CGFloat(image.width) / raw.extent.width,
            y: CGFloat(image.height) / raw.extent.height))
        return SubjectMask(image: scaled, context: context)
    }
}
