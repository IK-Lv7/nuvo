import CoreGraphics
import CoreImage
import CoreML
import CoreVideo

/// 画像の復元・強化(超解像・将来的なノイズ除去など)に使う、同梱の Core ML モデルのラッパー。
/// タイル分割は `TileLayout` に任せ、ここでは Core ML の呼び出しと画像の結合だけを行う。
///
/// 対応するモデルは、1枚の正方形タイル(`tileSize` 四方)を受け取り、`outputScale` 倍の
/// 大きさのタイルを返すもの。入力の特徴量名は "tile"、出力は "upscaledTile"
/// (`scripts/model_conversion/convert_realesrgan.py` と対応させること。名前が食い違うと
/// `loadBundled()` が nil を返し、Core Image だけの処理にフォールバックする)。
public struct RestorationModel {
    private let model: MLModel
    private let tileSize: Int
    private let overlap: Int
    private let outputScale: Int
    private let inputConstraint: MLImageConstraint

    private init?(model: MLModel, tileSize: Int, overlap: Int, outputScale: Int) {
        guard let input = model.modelDescription.inputDescriptionsByName["tile"]?.imageConstraint else {
            return nil
        }
        self.model = model
        self.tileSize = tileSize
        self.overlap = overlap
        self.outputScale = outputScale
        inputConstraint = input
    }

    /// アプリに同梱したモデルを読み込む。同梱していない、またはうまく読み込めない場合は nil
    /// (呼び出し側は、その場合 Core Image だけの処理にフォールバックすること)。
    public static func loadBundled() -> RestorationModel? {
        guard let url = Bundle.module.url(forResource: "RealESRGANGeneralX4V3", withExtension: "mlpackage")
            ?? Bundle.module.url(forResource: "RealESRGANGeneralX4V3", withExtension: "mlmodelc") else {
            return nil
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        guard let model = try? MLModel(contentsOf: url, configuration: configuration) else { return nil }
        // tileSize・overlap は変換スクリプトの既定値、outputScale はモデルの拡大率(4倍)に合わせる。
        return RestorationModel(model: model, tileSize: 128, overlap: 16, outputScale: 4)
    }

    /// `image` を `outputScale` 倍に拡大しながら、モデルで復元する。
    /// タイル1枚ぶんより小さい画像など、分割できない場合や、途中の推論が1つでも失敗した場合は nil。
    public func apply(to image: CIImage, context: CIContext) -> CIImage? {
        let size = image.extent.size
        let tiles = TileLayout.tiles(for: size, tileSize: tileSize, overlap: overlap)
        guard !tiles.isEmpty else { return nil }

        let scale = CGFloat(outputScale)
        let outputSize = CGSize(width: size.width * scale, height: size.height * scale)
        var canvas = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0))
            .cropped(to: CGRect(origin: .zero, size: outputSize))

        for tile in tiles {
            guard let sourcePatch = BitmapIO.crop(image, topLeftRect: tile.sourceRect, context: context),
                  let upscaledPatch = upscale(sourcePatch, context: context) else { return nil }

            // keepRect を、切り出したタイル(source)基準の相対位置に直し、拡大率をかける。
            let keepInSource = CGRect(x: tile.keepRect.minX - tile.sourceRect.minX,
                                      y: tile.keepRect.minY - tile.sourceRect.minY,
                                      width: tile.keepRect.width, height: tile.keepRect.height)
            let keepInUpscaled = CGRect(x: keepInSource.minX * scale, y: keepInSource.minY * scale,
                                        width: keepInSource.width * scale, height: keepInSource.height * scale)
                .integral
            guard let keptPatch = BitmapIO.crop(CIImage(cgImage: upscaledPatch), topLeftRect: keepInUpscaled,
                                                context: context) else { return nil }
            let pasteOrigin = CGPoint(x: tile.keepRect.minX * scale, y: tile.keepRect.minY * scale)
            canvas = BitmapIO.overlay(keptPatch, atTopLeft: pasteOrigin, on: canvas)
        }
        return canvas
    }

    /// 1枚のタイル(`tileSize` 四方)をモデルに通し、`outputScale` 倍のタイルを得る。
    private func upscale(_ tile: CGImage, context: CIContext) -> CGImage? {
        guard let input = try? MLFeatureValue(cgImage: tile, constraint: inputConstraint, options: nil),
              let features = try? MLDictionaryFeatureProvider(dictionary: ["tile": input]),
              let result = try? model.prediction(from: features),
              let buffer = result.featureValue(for: "upscaledTile")?.imageBufferValue else { return nil }
        let outputImage = CIImage(cvPixelBuffer: buffer)
        return context.createCGImage(outputImage, from: outputImage.extent)
    }
}
