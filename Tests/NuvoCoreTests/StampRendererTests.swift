import CoreGraphics
import CoreImage
import XCTest
@testable import NuvoCore

final class SymbolRendererTests: XCTestCase {
    func testARealSymbolProducesAnImage() throws {
        let image = try XCTUnwrap(SymbolRenderer.image(symbolName: "heart.fill", pointSize: 40,
                                                        color: CGColor(red: 1, green: 0, blue: 0, alpha: 1)))
        XCTAssertGreaterThan(image.width, 0)
        XCTAssertGreaterThan(image.height, 0)
    }

    func testAnUnknownSymbolNameProducesNothing() {
        XCTAssertNil(SymbolRenderer.image(symbolName: "this.symbol.does.not.exist.at.all",
                                          pointSize: 40, color: CGColor(red: 1, green: 0, blue: 0, alpha: 1)))
    }

    func testTheImageIsTintedTheRequestedColor() throws {
        let red = try XCTUnwrap(SymbolRenderer.image(symbolName: "heart.fill", pointSize: 40,
                                                      color: CGColor(red: 1, green: 0, blue: 0, alpha: 1)))
        let blue = try XCTUnwrap(SymbolRenderer.image(symbolName: "heart.fill", pointSize: 40,
                                                       color: CGColor(red: 0, green: 0, blue: 1, alpha: 1)))
        let redPixels = try XCTUnwrap(BitmapIO.rgba(from: red))
        let bluePixels = try XCTUnwrap(BitmapIO.rgba(from: blue))
        // 不透明な画素(記号の内側)を探し、その色見本が要求どおりであることを確かめる。
        let redIndex = try XCTUnwrap((0..<(red.width * red.height)).first { redPixels[$0 * 4 + 3] > 200 })
        let blueIndex = try XCTUnwrap((0..<(blue.width * blue.height)).first { bluePixels[$0 * 4 + 3] > 200 })
        XCTAssertGreaterThan(redPixels[redIndex * 4], redPixels[redIndex * 4 + 2])
        XCTAssertGreaterThan(bluePixels[blueIndex * 4 + 2], bluePixels[blueIndex * 4])
    }

    func testEveryCatalogSymbolRenders() {
        for symbol in StampSymbol.allCases {
            XCTAssertNotNil(SymbolRenderer.image(symbolName: symbol.symbolName, pointSize: 30,
                                                 color: CGColor(gray: 1, alpha: 1)),
                            "\(symbol.rawValue) が描けなかった")
        }
    }
}

final class EmojiStampRendererTests: XCTestCase {
    func testEveryCatalogEmojiRenders() {
        for emoji in EmojiStamp.allCases {
            let image = EmojiStampRenderer.image(assetName: emoji.assetName, pointSize: 30)
            XCTAssertNotNil(image, "\(emoji.rawValue) が読み込めなかった(Sources/Core/Resources/Stamps/ を確認)")
        }
    }

    func testTheImageIsScaledToTheRequestedSize() throws {
        let image = try XCTUnwrap(EmojiStampRenderer.image(assetName: EmojiStamp.heart.assetName, pointSize: 50))
        XCTAssertEqual(image.width, 50)
        XCTAssertEqual(image.height, 50)
    }

    func testAnUnknownAssetNameProducesNothing() {
        XCTAssertNil(EmojiStampRenderer.image(assetName: "this-asset-does-not-exist", pointSize: 30))
    }
}

final class StampOverlayCodableTests: XCTestCase {
    /// `imageAssetName` を追加する前に保存されたルックにこの項目が無くても読めること
    /// (AdjustmentParameters.highResolution と同じ考え方)。
    func testDecodesWithoutImageAssetNameField() throws {
        // CGPoint の Codable 実装は {"x":...,"y":...} ではなく [x, y](順序付きコンテナ)でエンコードされる。
        let json = """
        {"id":"9D3E1B9E-1234-4A5B-9C1D-000000000000","symbolName":"heart.fill",
         "center":[0.5,0.5],"size":0.2,"color":"white"}
        """
        let stamp = try JSONDecoder().decode(StampOverlay.self, from: Data(json.utf8))
        XCTAssertNil(stamp.imageAssetName)
        XCTAssertEqual(stamp.symbolName, "heart.fill")
        // "white" という色の名前の文字列(color を MakeupTint にする前の形式)も読めること。
        XCTAssertEqual(stamp.color, TextColorPreset.white.tint)
    }

    func testEmojiInitializerSetsBothNames() {
        let stamp = StampOverlay(emoji: .sparklingHeart)
        XCTAssertEqual(stamp.imageAssetName, "sparklingHeart")
        // symbolName は絵文字画像が読み込めなかったときの手がかり用の値で、空にはしない。
        XCTAssertFalse(stamp.symbolName.isEmpty)
    }
}

final class StampRendererTests: XCTestCase {
    private let renderer = ImageRenderer()
    private let side = 200

    private func black() -> CIImage {
        CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: side, height: side))
    }

    private func render(_ stamps: [StampOverlay]) throws -> [UInt8] {
        var p = AdjustmentParameters()
        p.stamps = stamps
        let cgImage = try XCTUnwrap(renderer.render(renderer.makeSource(image: black()), parameters: p))
        return try XCTUnwrap(BitmapIO.rgba(from: cgImage))
    }

    private func brightPixelCount(_ data: [UInt8]) -> Int {
        stride(from: 0, to: data.count, by: 4).filter { data[$0] > 128 }.count
    }

    func testNoStampsLeavesThePhotoUntouched() throws {
        XCTAssertEqual(brightPixelCount(try render([])), 0)
    }

    func testAStampDrawsBrightPixelsOnADarkPhoto() throws {
        let stamp = StampOverlay(symbolName: "star.fill", center: CGPoint(x: 0.5, y: 0.5), size: 0.3, color: TextColorPreset.white.tint)
        XCTAssertGreaterThan(brightPixelCount(try render([stamp])), 0)
    }

    func testAnEmojiStampDrawsBrightPixelsOnADarkPhoto() throws {
        let stamp = StampOverlay(emoji: .sparklingHeart, center: CGPoint(x: 0.5, y: 0.5), size: 0.3)
        XCTAssertGreaterThan(brightPixelCount(try render([stamp])), 0)
    }

    func testStampSizeControlsHowMuchOfThePhotoItCovers() throws {
        let small = StampOverlay(symbolName: "star.fill", size: 0.1, color: TextColorPreset.white.tint)
        let large = StampOverlay(symbolName: "star.fill", size: 0.4, color: TextColorPreset.white.tint)
        XCTAssertLessThan(try brightPixelCount(render([small])), try brightPixelCount(render([large])))
    }

    func testRenderingKeepsThePhotosOriginalSize() throws {
        let stamp = StampOverlay(symbolName: "heart.fill", size: 0.5, color: TextColorPreset.white.tint)
        var p = AdjustmentParameters()
        p.stamps = [stamp]
        let cgImage = try XCTUnwrap(renderer.render(renderer.makeSource(image: black()), parameters: p))
        XCTAssertEqual(cgImage.width, side)
        XCTAssertEqual(cgImage.height, side)
    }

    func testAStampNearTheEdgeDoesNotEnlargeTheOutput() throws {
        // 文字と同じ問題(端をはみ出すと出力が広がる)が、スタンプでも起きないことを確かめる。
        let stamp = StampOverlay(symbolName: "sun.max.fill", center: CGPoint(x: 0.02, y: 0.02), size: 0.3, color: TextColorPreset.white.tint)
        var p = AdjustmentParameters()
        p.stamps = [stamp]
        let cgImage = try XCTUnwrap(renderer.render(renderer.makeSource(image: black()), parameters: p))
        XCTAssertEqual(cgImage.width, side)
        XCTAssertEqual(cgImage.height, side)
    }
}
