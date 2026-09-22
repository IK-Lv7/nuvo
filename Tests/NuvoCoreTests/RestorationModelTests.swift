import CoreGraphics
import CoreImage
import XCTest
@testable import NuvoCore

/// `Sources/Core/Resources/Models/RealESRGANGeneralX4V3.mlpackage` をまだ同梱していない今は、
/// 「nil を返し、呼び出し側が Core Image にフォールバックする」ことだけを確認する(このテストは通る)。
///
/// モデルを追加したあとにこのテストを実行すると、実際に Core ML の推論(1タイルぶん)まで
/// 自動的に確認するようになる。Xcode を開かなくても、`swift test`(このリポジトリでは
/// `.github/workflows/test.yml` が macOS ランナーで毎回実行している)で分かる。
final class RestorationModelTests: XCTestCase {
    func testLoadsOrGracefullyReturnsNilWhenNotBundled() throws {
        guard let model = RestorationModel.loadBundled() else {
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
        let result = try XCTUnwrap(output, "モデルが読み込めているのに処理結果が nil だった")

        // このモデルは 4 倍に拡大する(RestorationModel.loadBundled の outputScale と合わせる)。
        XCTAssertEqual(result.extent.width, CGFloat(size * 4), accuracy: 0.5)
        XCTAssertEqual(result.extent.height, CGFloat(size * 4), accuracy: 0.5)
    }
}
