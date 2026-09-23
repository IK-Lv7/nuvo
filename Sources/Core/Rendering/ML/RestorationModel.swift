import CoreGraphics
import CoreImage
import CoreML
import CoreVideo
import Foundation

/// 画像の復元・強化(超解像・将来的なノイズ除去など)に使う、同梱の Core ML モデルのラッパー。
/// タイル分割は `TileLayout` に任せ、ここでは Core ML の呼び出しと画像の結合だけを行う。
///
/// 対応するモデルは、1枚の正方形タイル(`tileSize` 四方)を受け取り、`outputScale` 倍の
/// 大きさのタイルを返すもの。入力の特徴量名は "tile"、出力は "upscaledTile"
/// (`scripts/model_conversion/convert_realesrgan.py` と対応させること。名前が食い違うと
/// `loadBundled()` が nil を返し、Core Image だけの処理にフォールバックする)。
public struct RestorationModel {
    /// 同梱している `.mlpackage` の名前。リソースの検索とキャッシュの名前で共通に使う。
    static let modelName = "RealESRGANGeneralX4V3"

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
        guard let url = bundledPackageURL() else { return nil }
        guard let compiledURL = compiledModelURL(for: url) else { return nil }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        guard let model = try? MLModel(contentsOf: compiledURL, configuration: configuration) else { return nil }
        // tileSize・overlap は変換スクリプトの既定値、outputScale はモデルの拡大率(4倍)に合わせる。
        return RestorationModel(model: model, tileSize: 128, overlap: 16, outputScale: 4)
    }

    /// 同梱モデルの URL(`.mlpackage` または、あらかじめコンパイル済みの `.mlmodelc`)。
    /// リソースが本当に同梱されているかどうかをテストからも確認できるよう、`internal` で公開する
    /// (`loadBundled()` の nil は「同梱されていない」と「同梱されているが読み込みに失敗した」の
    /// 両方で起こりうるため、テスト側でこの2つを区別するのに使う)。
    static func bundledPackageURL() -> URL? {
        // Package.swift の `.copy("Resources/Models")` はフォルダ構造を保ったままコピーするため、
        // バンドル直下ではなく "Models" フォルダの中に入る。ここを省くと永遠に見つからず、
        // 常に Core Image だけのフォールバックになってしまう。
        Bundle.module.url(forResource: modelName, withExtension: "mlpackage", subdirectory: "Models")
            ?? Bundle.module.url(forResource: modelName, withExtension: "mlmodelc", subdirectory: "Models")
    }

    /// `.mlpackage` は未コンパイルの状態では `MLModel(contentsOf:)` に渡せない
    /// (「コンパイル済みでない」エラーで失敗する)。Xcode プロジェクトに直接モデルを追加した場合は
    /// ビルド時に Xcode の "Core ML Model Compiler" が自動でコンパイルしてくれるが、
    /// Swift Package のリソースとして `.copy()` しただけのファイルはその対象にならないため、
    /// ここで明示的にコンパイルする必要がある(すでに `.mlmodelc` を渡された場合は素通しする)。
    ///
    /// コンパイルは軽くない処理なので、一度コンパイルした結果はアプリのサポートフォルダに
    /// キャッシュし、次回起動時はそれを再利用する。
    ///
    /// キャッシュの名前には**モデルの中身から作った指紋**を入れる。同梱モデルを差し替えると
    /// 名前ごと変わるため、古いキャッシュに当たること自体が起こらない。
    /// (以前は更新日時を比べていた。しかしバンドル内のファイルの日時は、ビルドや配布の経路で
    ///  古いまま引き継がれることがあり、アプリを更新しても「キャッシュのほうが新しい」と
    ///  判定されうる。実際それで、直したモデルを同梱しても壊れた古いモデルが使われ続けた。)
    private static func compiledModelURL(for url: URL) -> URL? {
        guard url.pathExtension == "mlpackage" else { return url }
        guard let fingerprint = fingerprint(of: url), let directory = cacheDirectory() else {
            // 指紋が作れない場合は、古いものを使う危険を冒さず毎回コンパイルする。
            return try? MLModel.compileModel(at: url)
        }
        let cacheURL = directory.appendingPathComponent("\(modelName)-\(fingerprint).mlmodelc")
        if FileManager.default.fileExists(atPath: cacheURL.path) { return cacheURL }

        guard let compiled = try? MLModel.compileModel(at: url) else { return nil }
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        // 指紋が変わった = 前のモデルのキャッシュはもう使わないので、ここで捨てる。
        for stale in (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        where stale.pathExtension == "mlmodelc" && stale.lastPathComponent != cacheURL.lastPathComponent {
            try? fileManager.removeItem(at: stale)
        }
        if (try? fileManager.copyItem(at: compiled, to: cacheURL)) != nil { return cacheURL }
        // キャッシュへのコピーに失敗しても、コンパイル自体は成功しているのでそのまま使う。
        return compiled
    }

    private static func cacheDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CoreMLModels")
    }

    /// 同梱モデルの中身(`.mlpackage` 内の全ファイル)から作る短い指紋。
    /// 数 MB を読むことになるが、起動時に一度だけなので実用上の負担にはならない。
    static func fingerprint(of packageURL: URL) -> String? {
        let fileManager = FileManager.default
        guard let entries = fileManager.enumerator(at: packageURL, includingPropertiesForKeys: nil)?
            .compactMap({ $0 as? URL }).sorted(by: { $0.path < $1.path }), !entries.isEmpty else { return nil }

        // FNV-1a(64bit)。暗号用途ではなく「モデルが差し替わったか」を見るだけなので、
        // 衝突耐性より、外部モジュールを増やさずに済むことを優先する(AGENTS.md 第2章)。
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ bytes: UnsafeRawBufferPointer) {
            for byte in bytes {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01b3
            }
        }

        var hashedAnyFile = false
        for entry in entries {
            // ディレクトリは読み込みに失敗するだけなので、そのまま読み飛ばす。
            guard let data = try? Data(contentsOf: entry, options: .mappedIfSafe) else { continue }
            // 引数の型を明示するのは、Data.withUnsafeBytes の古い(非推奨の)多重定義と
            // 取り違えられないようにするため。
            Data(entry.lastPathComponent.utf8).withUnsafeBytes { (raw: UnsafeRawBufferPointer) in mix(raw) }
            data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in mix(raw) }
            hashedAnyFile = true
        }
        guard hashedAnyFile else { return nil }
        return String(hash, radix: 16)
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

        var isVerified = false
        for tile in tiles {
            guard let sourcePatch = BitmapIO.crop(image, topLeftRect: tile.sourceRect, context: context),
                  let upscaledPatch = upscale(sourcePatch, context: context) else { return nil }

            // 最初の1枚だけ、モデルの出力が壊れていないか(ほぼ真っ黒になっていないか)を確かめる。
            // 壊れていれば全体を諦めて nil を返し、Core Image だけの拡大にフォールバックさせる。
            // 真っ黒な写真を書き出してしまうより、精細さを諦めるほうがましなため。
            if !isVerified {
                guard Self.looksPlausible(source: sourcePatch, upscaled: upscaledPatch) else { return nil }
                isVerified = true
            }

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
    /// `internal` にしてあるのは、テストから「モデル単体の出力」と「タイルを合成した結果」を
    /// 切り分けて測れるようにするため(`bundledPackageURL()` と同じ理由)。
    func upscale(_ tile: CGImage, context: CIContext) -> CGImage? {
        guard let input = try? MLFeatureValue(cgImage: tile, constraint: inputConstraint, options: nil),
              let features = try? MLDictionaryFeatureProvider(dictionary: ["tile": input]),
              let result = try? model.prediction(from: features),
              let buffer = result.featureValue(for: "upscaledTile")?.imageBufferValue else { return nil }
        return Self.opaqueImage(from: buffer) ?? Self.imageIgnoringAlpha(from: buffer, context: context)
    }

    /// Core ML の画像出力(`CVPixelBuffer`)を、アルファを読まずに `CGImage` にする。
    ///
    /// 出力の画素形式は 32BGRA だが、モデルが書き込むのは RGB の3チャンネルだけで、
    /// アルファのバイトは 0 のまま返ることがある。これを `CIImage(cvPixelBuffer:)` で読むと
    /// 「アルファ済み乗算の、完全に透明なピクセル」と解釈され、タイルを重ねた結果も全面透明になる。
    /// 透明な画像を JPEG / HEIC に書き出すと透明部分が黒で埋まるため、写真全体が真っ黒になる
    /// (編集画面の背景も暗いため、プレビューでも黒く見える)。
    /// ここでは `noneSkipFirst` を指定してアルファのバイトを無視し、この解釈そのものを避ける。
    private static func opaqueImage(from buffer: CVPixelBuffer) -> CGImage? {
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer),
              let bitmap = CGContext(
                data: base, width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer),
                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        // makeImage() は画素をコピーするため、この後ロックを解いても安全。
        return bitmap.makeImage()
    }

    /// 32BGRA 以外の形式で返ってきた場合の保険。Core Image 経由で読み、アルファは 1 に上書きする。
    private static func imageIgnoringAlpha(from buffer: CVPixelBuffer, context: CIContext) -> CGImage? {
        let image = CIImage(cvPixelBuffer: buffer)
        return context.createCGImage(image.settingAlphaOne(in: image.extent), from: image.extent)
    }

    /// モデルの出力が「大きさは正しいが中身がほぼ真っ黒」になっていないかを、明るさで確かめる。
    /// 出力レンジ(0〜1 と 0〜255)やアルファの扱いを取り違えると、この形で壊れる。
    /// 元のタイル自体が暗い(夜景など)場合は判定材料にならないので、そのまま通す。
    private static func looksPlausible(source: CGImage, upscaled: CGImage) -> Bool {
        guard let sourceMean = meanLuminance(of: source), sourceMean > 16,
              let upscaledMean = meanLuminance(of: upscaled) else { return true }
        // 復元で明るさが多少変わるのは正常なため、しきい値は「明らかに黒い」側に大きく振る。
        return upscaledMean > sourceMean * 0.25
    }

    /// 0〜255 の平均輝度。`BitmapIO.rgba` はアルファ済み乗算で描くため、
    /// 全面が透明なタイルもここでは 0 になり、同じ判定で拾える。
    /// `internal` にしてあるのは、テストが同じ尺度で出力を測れるようにするため。
    static func meanLuminance(of image: CGImage) -> Double? {
        guard let rgba = BitmapIO.rgba(from: image), !rgba.isEmpty else { return nil }
        var total = 0.0
        for index in stride(from: 0, to: rgba.count, by: 4) {
            total += 0.299 * Double(rgba[index]) + 0.587 * Double(rgba[index + 1]) + 0.114 * Double(rgba[index + 2])
        }
        return total / Double(rgba.count / 4)
    }
}
