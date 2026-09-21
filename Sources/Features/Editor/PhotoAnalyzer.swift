import CoreImage
import NuvoCore

/// 顔検出・人物の切り抜き・深度の解析結果。
struct PhotoAnalysis: @unchecked Sendable {
    var faces: [FaceLandmarks]
    var subjectMask: SubjectMask?
    var depthMask: SubjectMask?
}

/// 写真の解析。重いのでバックグラウンドで呼ぶ。プレビュー解像度で行い、結果はフル解像度の書き出しにも使う
/// (顔の位置は画像サイズに依存しない座標で持ち、マスクは使うときに拡大するため)。
enum PhotoAnalyzer {
    static func analyze(preview: CIImage, data: Data, renderer: ImageRenderer) -> PhotoAnalysis {
        let cgImage = renderer.cgImage(from: preview)
        let faces = cgImage.flatMap { try? FaceLandmarkDetector().detect(in: $0) } ?? []
        let portrait = renderer.portraitMasks(from: data, faces: faces)
        // ポートレート写真に埋め込まれた切り抜きは、機械学習の推定より精度が高い。無ければ Vision を使う。
        let subject = portrait.matte ?? cgImage.flatMap { renderer.segmentSubject(in: $0) }
        return PhotoAnalysis(faces: faces, subjectMask: subject, depthMask: portrait.depth)
    }
}
