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
        let result = try XCTUnwrap(output, "モデルが読み込めているのに処理結果が nil だった")

        // このモデルは 4 倍に拡大する(RestorationModel.loadBundled の outputScale と合わせる)。
        XCTAssertEqual(result.extent.width, CGFloat(size * 4), accuracy: 0.5)
        XCTAssertEqual(result.extent.height, CGFloat(size * 4), accuracy: 0.5)
    }
}
