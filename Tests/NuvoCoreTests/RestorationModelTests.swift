import CoreGraphics
import CoreImage
import XCTest
@testable import NuvoCore

/// `RealESRGANGeneralX4V3.mlpackage` は `Sources/Core/Resources/Models/` に同梱済み。
/// リソース自体が見つからない(将来ファイルを移動・削除した等)ときだけスキップし、
/// 「同梱されているのに読み込み・推論に失敗する」場合はテストを失敗させる
/// (`.mlpackage` はコンパイルしてから読み込む必要があり、この違いを区別しないと
/// コンパイル忘れのような不具合が「モデルなし」として握りつぶされてしまう)。
final class RestorationModelTests: XCTestCase {
    func testLoadsOrGracefullyReturnsNilWhenNotBundled() throws {
        let isBundled = RestorationModel.bundledPackageURL() != nil
        guard let model = RestorationModel.loadBundled() else {
            if isBundled {
                XCTFail("RealESRGANGeneralX4V3.mlpackage は同梱されているのに RestorationModel.loadBundled() が nil を返した")
            }
            throw XCTSkip("RealESRGANGeneralX4V3.mlpackage がまだ Sources/Core/Resources/Models/ に無い")
        }
        // モデルがあれば、タイル分割が要る大きさの画像で実際に処理できることを確認する
        // (128 = 変換スクリプトの既定タイルサイズより大きい、複数タイルに分かれる大きさ)。
        let size = 200
        let pixels = [UInt8](repeating: 0, count: size * size * 4)
            .enumerated().map { index, _ -> UInt8 in
                switch index % 4 {
                case 0: return 120
                case 1: return 90
                case 2: return 70
                default: return 255
                }
            }
        let cgImage = try XCTUnwrap(BitmapIO.cgImage(fromRGBA: pixels, width: size, height: size))
        let context = CIContext()

        let output = model.apply(to: CIImage(cgImage: cgImage), context: context)
        let result = try XCTUnwrap(output, """
            モデルが読み込めているのに処理結果が nil だった \
            (出力が真っ黒で、RestorationModel の安全弁が働いた可能性がある)
            """)

        // このモデルは 4 倍に拡大する(RestorationModel.loadBundled の outputScale と合わせる)。
        XCTAssertEqual(result.extent.width, CGFloat(size * 4), accuracy: 0.5)
        XCTAssertEqual(result.extent.height, CGFloat(size * 4), accuracy: 0.5)

        // 中身の確認。大きさだけを見ていると、モデルの出力レンジ(0〜1 と 0〜255)や
        // アルファの取り違えで「大きさは正しいが真っ黒・全面透明」になる不具合を見逃す
        // (実際にこの形で、高画質化した写真が真っ黒になる不具合が2度起きている)。
        let rendered = try XCTUnwrap(context.createCGImage(result, from: result.extent))
        let outputRGBA = try XCTUnwrap(BitmapIO.rgba(from: rendered))
        let mean = meanLuminance(of: outputRGBA)
        // 入力(120, 90, 70)の平均輝度は約 97。復元で多少変わるため、下限だけを緩く見る。
        XCTAssertGreaterThan(mean, 40, "高画質化の出力がほぼ真っ黒(平均輝度 \(mean))")
    }

    /// コンパイル済みモデルのキャッシュは、この指紋で名前を分けている。
    /// 指紋が作れない(nil)と毎回コンパイルすることになり、起動が目に見えて遅くなる。
    /// 同じモデルからは必ず同じ指紋が出ることも確かめる(毎回変わると、キャッシュが効かない)。
    func testFingerprintIsStableForTheBundledModel() throws {
        guard let url = RestorationModel.bundledPackageURL(), url.pathExtension == "mlpackage" else {
            throw XCTSkip("RealESRGANGeneralX4V3.mlpackage がまだ Sources/Core/Resources/Models/ に無い")
        }
        let first = try XCTUnwrap(RestorationModel.fingerprint(of: url), "同梱モデルの指紋が作れなかった")
        XCTAssertEqual(first, RestorationModel.fingerprint(of: url))
        XCTAssertFalse(first.isEmpty)
    }

    /// タイル1枚だけをモデルに通し、「モデル自体が仕事をしているか」を数値で測る。
    ///
    /// `apply(to:)` はモデルの推論・タイルの合成・安全弁のフォールバックを全部まとめて行うため、
    /// 結果がおかしいときにどこが原因か分からない。このテストはモデル単体だけを見る:
    /// - 明るさが入力とかけ離れていないか(出力レンジ・アルファの取り違えで真っ黒になる不具合)
    /// - ノイズが実際に減っているか(モデルが読み込めていても、推論が素通しなら意味がない)
    ///
    /// 失敗メッセージには必ず実測値を載せる。Mac を持たない開発体制では、CI のログに出た
    /// この数値が唯一の手がかりになるため。
    func testModelRemovesNoiseFromASingleTile() throws {
        guard let model = RestorationModel.loadBundled() else {
            throw XCTSkip("RealESRGANGeneralX4V3.mlpackage がまだ Sources/Core/Resources/Models/ に無い")
        }
        let side = 128  // 変換スクリプトの既定タイルサイズ。モデルはこの大きさしか受け付けない。
        let noisy = try XCTUnwrap(BitmapIO.cgImage(fromRGBA: noisyTile(side: side), width: side, height: side))
        let context = CIContext()

        let upscaled = try XCTUnwrap(model.upscale(noisy, context: context), "タイル1枚の推論が nil を返した")
        XCTAssertEqual(upscaled.width, side * 4)

        let inputMean = try XCTUnwrap(RestorationModel.meanLuminance(of: noisy))
        let outputMean = try XCTUnwrap(RestorationModel.meanLuminance(of: upscaled))
        // 復元で多少は変わるが、桁で変わることはない。ここが大きく下がるなら出力の扱いを間違えている。
        XCTAssertEqual(outputMean, inputMean, accuracy: inputMean * 0.35,
                       "モデル出力の明るさが入力とかけ離れている(入力 \(inputMean) → 出力 \(outputMean))")

        // ノイズの量は「隣り合う画素の差の平均」で測る。出力は4倍の大きさなので、
        // 同じ距離を比べるために出力側だけ 4px 離れた画素と比べる。
        let inputNoise = try XCTUnwrap(meanNeighborDifference(of: noisy, step: 1))
        let outputNoise = try XCTUnwrap(meanNeighborDifference(of: upscaled, step: 4))
        XCTAssertLessThan(outputNoise, inputNoise,
                          "モデルを通してもノイズが減っていない(入力 \(inputNoise) → 出力 \(outputNoise))")
    }

    /// 肌色に近い下地へ、再現性のある擬似乱数でノイズを載せたタイル。
    /// 乱数を固定するのは、CI で失敗したときに同じ条件を手元で再現できるようにするため。
    private func noisyTile(side: Int) -> [UInt8] {
        var seed: UInt64 = 0x4E75_766F  // "Nuvo"
        func next() -> Int {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int(truncatingIfNeeded: seed >> 33) % 41 - 20  // -20...20
        }
        let base: [Int] = [120, 90, 70]
        var pixels = [UInt8](repeating: 255, count: side * side * 4)
        for pixel in 0..<(side * side) {
            for channel in 0..<3 {
                pixels[pixel * 4 + channel] = UInt8(min(max(base[channel] + next(), 0), 255))
            }
        }
        return pixels
    }

    /// 横方向に `step` 画素離れた隣どうしの、輝度の差の平均(0〜255)。
    /// ノイズが多いほど大きく、平滑化されるほど小さくなる。
    private func meanNeighborDifference(of image: CGImage, step: Int) -> Double? {
        guard let rgba = BitmapIO.rgba(from: image) else { return nil }
        let width = image.width, height = image.height
        guard width > step else { return nil }
        func luminance(_ x: Int, _ y: Int) -> Double {
            let index = (y * width + x) * 4
            return 0.299 * Double(rgba[index]) + 0.587 * Double(rgba[index + 1]) + 0.114 * Double(rgba[index + 2])
        }
        var total = 0.0
        for y in 0..<height {
            for x in 0..<(width - step) {
                total += abs(luminance(x + step, y) - luminance(x, y))
            }
        }
        return total / Double(height * (width - step))
    }

    /// 0〜255 の平均輝度。`BitmapIO.rgba` はアルファ済み乗算で描くため、全面が透明な結果も 0 になる。
    private func meanLuminance(of rgba: [UInt8]) -> Double {
        guard !rgba.isEmpty else { return 0 }
        var total = 0.0
        for index in stride(from: 0, to: rgba.count, by: 4) {
            total += 0.299 * Double(rgba[index]) + 0.587 * Double(rgba[index + 1]) + 0.114 * Double(rgba[index + 2])
        }
        return total / Double(rgba.count / 4)
    }
}
