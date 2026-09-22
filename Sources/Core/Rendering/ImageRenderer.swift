import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO

/// 画像の読み込み・縮小・描画・エンコードを担う。
/// `CIContext` は生成コストが大きいため、インスタンスを使い回す。
/// `CIContext` はスレッドセーフなので、バックグラウンドからの呼び出しを許可する。
public final class ImageRenderer: @unchecked Sendable {
    /// プレビューの長辺。スライダー操作中の応答性と見た目のバランスで決めた値。
    public static let previewLongEdge: CGFloat = 1536
    /// 書き出しの既定の画質。0.95 なら見た目の劣化がほぼ無く、ファイルは最高画質の半分以下に収まる。
    public static let defaultQuality = 0.95

    private let context = CIContext()
    private let pipeline = RenderPipeline()
    /// 高画質化で使う Core ML モデル。読み込みコストが大きいため `init` で1度だけ読み込んで使い回す。
    /// `lazy var` にしない理由: このクラスは `@unchecked Sendable` でバックグラウンドから並行して
    /// 呼ばれうるため、初回アクセスを競合させたくない。`let` なら `init` 時点で確定し、以降は読み取りだけになる。
    /// 同梱していない(または読み込めない)場合は nil のままで、高画質化は Core Image だけで処理する。
    private let restorationModel: RestorationModel?

    public init() {
        restorationModel = RestorationModel.loadBundled()
    }

    /// 写真の向き情報を反映した状態で読み込む。
    public func loadImage(from data: Data) -> CIImage? {
        CIImage(data: data, options: [.applyOrientationProperty: true]).map(originAtZero)
    }

    /// 長辺が `longEdge` を超える場合のみ縮小する。拡大はしない。
    public func downscaled(_ image: CIImage, longEdge: CGFloat = ImageRenderer.previewLongEdge) -> CIImage {
        let currentLongEdge = max(image.extent.width, image.extent.height)
        guard currentLongEdge > longEdge, currentLongEdge > 0 else { return image }

        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = image
        filter.scale = Float(longEdge / currentLongEdge)
        filter.aspectRatio = 1
        return filter.outputImage.map(originAtZero) ?? image
    }

    /// 顔検出と肌補正の事前計算を行う。重いのでバックグラウンドから呼ぶこと。
    public func makeSource(image: CIImage, faces: [FaceLandmarks] = [],
                           subjectMask: SubjectMask? = nil, depthMask: SubjectMask? = nil) -> RenderSource {
        RenderSource(image: image, faces: faces,
                     retouch: SkinRetouch.prepare(image: image, faces: faces, context: context),
                     subjectMask: subjectMask, depthMask: depthMask)
    }

    /// ポートレートモードで撮った写真に埋め込まれた、切り抜き(マット)と深度のマスク。
    /// 埋め込まれていない写真では、どちらも nil。重いのでバックグラウンドから呼ぶこと。
    public func portraitMasks(from data: Data, faces: [FaceLandmarks]) -> (matte: SubjectMask?, depth: SubjectMask?) {
        let matte = CIImage(data: data, options: [.auxiliaryPortraitEffectsMatte: true, .applyOrientationProperty: true])
            .flatMap { SubjectMask(image: originAtZero($0), context: context) }

        var depth: SubjectMask?
        if let disparity = CIImage(data: data, options: [.auxiliaryDisparity: true, .applyOrientationProperty: true]),
           let cgImage = context.createCGImage(disparity, from: disparity.extent),
           let rgba = BitmapIO.rgba(from: cgImage) {
            let gray: [UInt8] = stride(from: 0, to: rgba.count, by: 4).map { rgba[$0] }
            // ピントを合わせる位置は、最も大きく写っている顔の中央付近。顔がなければ画像の中央。
            let largest = faces.max { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }
            let focus = largest.map { $0.boundingBox.insetBy(dx: $0.boundingBox.width * 0.3, dy: $0.boundingBox.height * 0.3) }
                ?? CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
            depth = PortraitDepth.focusMask(disparity: gray, width: cgImage.width, height: cgImage.height, focus: focus)
                .flatMap { SubjectMask(grayBytes: $0, width: cgImage.width, height: cgImage.height) }
        }
        return (matte, depth)
    }

    /// 元画像のメタデータを読む(書き出しで引き継ぐため)。
    public func readMetadata(from data: Data) -> [String: Any] {
        ImageWriter.readMetadata(from: data)
    }

    /// 人物の切り抜きマスクを作る。重いのでバックグラウンドから呼ぶこと。
    public func segmentSubject(in image: CGImage) -> SubjectMask? {
        try? SubjectSegmenter().segment(image, context: context)
    }

    public func cgImage(from image: CIImage) -> CGImage? {
        context.createCGImage(image, from: image.extent)
    }

    public func render(_ source: RenderSource, parameters: AdjustmentParameters) -> CGImage? {
        let output = pipeline.apply(parameters, to: source, context: context, restorationModel: restorationModel)
        // 切り出し(証明写真)で範囲が変わるため、出力の範囲で描画する。
        let extent = output.extent.isInfinite || output.extent.isNull ? source.image.extent : output.extent
        return context.createCGImage(output, from: extent)
    }

    /// 書き出し用。透かしやロゴは入れない。
    /// - Parameters:
    ///   - metadata: 元画像のメタデータ。撮影情報(Exif)を引き継ぐ。
    ///   - stripLocation: true なら位置情報(GPS)を消す。
    ///   - format: 書き出し形式。HEIC が使えない端末では JPEG に戻す。
    ///   - quality: 画質(0.1...1)。PNG では無視される。
    public func encodedData(_ source: RenderSource, parameters: AdjustmentParameters,
                            format: ExportFormat = .jpeg, quality: Double = ImageRenderer.defaultQuality,
                            metadata: [String: Any] = [:], stripLocation: Bool = true) -> (data: Data, format: ExportFormat)? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let output = pipeline.apply(parameters, to: source, context: context, restorationModel: restorationModel)
        let extent = output.extent.isInfinite || output.extent.isNull ? source.image.extent : output.extent
        guard let cgImage = context.createCGImage(output, from: extent, format: .RGBA8, colorSpace: colorSpace) else { return nil }
        let properties = ImageWriter.sanitized(metadata, stripLocation: stripLocation,
                                               width: cgImage.width, height: cgImage.height)
        if let data = ImageWriter.data(from: cgImage, properties: properties, quality: quality, format: format) {
            return (data, format)
        }
        guard format != .jpeg,
              let fallback = ImageWriter.data(from: cgImage, properties: properties, quality: quality, format: .jpeg) else { return nil }
        return (fallback, .jpeg)
    }

    /// JPEG での書き出し(`encodedData` の簡易版)。
    public func jpegData(_ source: RenderSource, parameters: AdjustmentParameters,
                         metadata: [String: Any] = [:], stripLocation: Bool = true) -> Data? {
        encodedData(source, parameters: parameters, format: .jpeg, metadata: metadata, stripLocation: stripLocation)?.data
    }

    /// 以降の座標計算を単純にするため、画像の原点を (0, 0) に揃える。
    private func originAtZero(_ image: CIImage) -> CIImage {
        let extent = image.extent
        guard extent.minX != 0 || extent.minY != 0 else { return image }
        return image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
    }
}
