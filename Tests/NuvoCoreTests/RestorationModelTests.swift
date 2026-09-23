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
