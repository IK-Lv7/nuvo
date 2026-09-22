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
        let stamp = StampOverlay(symbolName: "star.fill", center: CGPoint(x: 0.5, y: 0.5), size: 0.3, color: .white)
        XCTAssertGreaterThan(brightPixelCount(try render([stamp])), 0)
    }

    func testStampSizeControlsHowMuchOfThePhotoItCovers() throws {
        let small = StampOverlay(symbolName: "star.fill", size: 0.1, color: .white)
        let large = StampOverlay(symbolName: "star.fill", size: 0.4, color: .white)
        XCTAssertLessThan(try brightPixelCount(render([small])), try brightPixelCount(render([large])))
    }

    func testRenderingKeepsThePhotosOriginalSize() throws {
        let stamp = StampOverlay(symbolName: "heart.fill", size: 0.5, color: .white)
        var p = AdjustmentParameters()
        p.stamps = [stamp]
        let cgImage = try XCTUnwrap(renderer.render(renderer.makeSource(image: black()), parameters: p))
        XCTAssertEqual(cgImage.width, side)
        XCTAssertEqual(cgImage.height, side)
    }

    func testAStampNearTheEdgeDoesNotEnlargeTheOutput() throws {
        // 文字と同じ問題(端をはみ出すと出力が広がる)が、スタンプでも起きないことを確かめる。
        let stamp = StampOverlay(symbolName: "sun.max.fill", center: CGPoint(x: 0.02, y: 0.02), size: 0.3, color: .white)
        var p = AdjustmentParameters()
        p.stamps = [stamp]
        let cgImage = try XCTUnwrap(renderer.render(renderer.makeSource(image: black()), parameters: p))
        XCTAssertEqual(cgImage.width, side)
        XCTAssertEqual(cgImage.height, side)
    }
}
