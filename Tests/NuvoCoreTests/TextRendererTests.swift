import CoreGraphics
import CoreImage
import XCTest
@testable import NuvoCore

final class TextRendererTests: XCTestCase {
    private let renderer = ImageRenderer()
    private let side = 200

    private func black() -> CIImage {
        CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: side, height: side))
    }

    private func render(_ overlays: [TextOverlay]) throws -> [UInt8] {
        var p = AdjustmentParameters()
        p.texts = overlays
        let cgImage = try XCTUnwrap(renderer.render(renderer.makeSource(image: black()), parameters: p))
        return try XCTUnwrap(BitmapIO.rgba(from: cgImage))
    }

    private func brightPixels(_ data: [UInt8], columns: Range<Int>) -> Int {
        var count = 0
        for y in 0..<side {
            for x in columns where data[(y * side + x) * 4] > 128 { count += 1 }
        }
        return count
    }

    private func overlay(text: String = "MMM", center: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> TextOverlay {
        TextOverlay(text: text, center: center, size: 0.25, color: TextColorPreset.white.tint, style: .standard,
                    isBold: true, hasShadow: false)
    }

    func testTextDrawsBrightPixelsNearTheCenter() throws {
        let data = try render([overlay()])
        XCTAssertGreaterThan(brightPixels(data, columns: 60..<140), 100)
        XCTAssertEqual(data[0], 0)  // 隅は変わらない
    }

    func testEmptyTextChangesNothing() throws {
        let data = try render([overlay(text: "")])
        XCTAssertEqual(brightPixels(data, columns: 0..<side), 0)
    }

    func testPositionFollowsTheCenter() throws {
        let left = try render([overlay(center: CGPoint(x: 0.25, y: 0.5))])
        XCTAssertGreaterThan(brightPixels(left, columns: 0..<100), brightPixels(left, columns: 100..<200) * 3)
        let right = try render([overlay(center: CGPoint(x: 0.75, y: 0.5))])
        XCTAssertGreaterThan(brightPixels(right, columns: 100..<200), brightPixels(right, columns: 0..<100) * 3)
    }

    func testBiggerSizeCoversMoreArea() throws {
        var small = overlay()
        small.size = 0.1
        var large = overlay()
        large.size = 0.3
        XCTAssertGreaterThan(brightPixels(try render([large]), columns: 0..<side),
                             brightPixels(try render([small]), columns: 0..<side))
    }

    func testColorIsApplied() throws {
        var pink = overlay()
        pink.color = TextColorPreset.pink.tint
        let data = try render([pink])
        // ピンクは R が G・B より強い。
        var red = 0, green = 0
        for i in stride(from: 0, to: data.count, by: 4) { red += Int(data[i]); green += Int(data[i + 1]) }
        XCTAssertGreaterThan(red, green)
    }

    func testTextSurvivesRotation() throws {
        // 文字は構図(回転・切り出し)のあとに重ねるため、最終画像の中に必ず収まる。
        var p = AdjustmentParameters()
        p.rotationQuarterTurns = 1
        p.texts = [overlay()]
        let cgImage = try XCTUnwrap(renderer.render(renderer.makeSource(image: black()), parameters: p))
        let data = try XCTUnwrap(BitmapIO.rgba(from: cgImage))
        XCTAssertTrue(stride(from: 0, to: data.count, by: 4).contains { data[$0] > 128 })
    }

    func testTextOverlayRoundTripsThroughJSON() throws {
        let original = TextOverlay(text: "こんにちは", center: CGPoint(x: 0.3, y: 0.7), size: 0.1,
                                   color: TextColorPreset.yellow.tint, style: .serif, isBold: false, hasShadow: true)
        let decoded = try JSONDecoder().decode(TextOverlay.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
    }

    /// `color` を `MakeupTint`(カラーピック対応)にする前に保存されたルックは、
    /// 色の名前の文字列("pink" など)で入っている。それも読めることを確かめる
    /// (StampOverlayCodableTests.testDecodesWithoutImageAssetNameField と同じ考え方)。
    func testDecodesTheOldColorNameFormat() throws {
        // CGPoint の Codable 実装は {"x":...,"y":...} ではなく [x, y](順序付きコンテナ)でエンコードされる。
        let json = """
        {"id":"9D3E1B9E-1234-4A5B-9C1D-000000000001","text":"Nuvo","center":[0.5,0.5],"size":0.08,
         "color":"pink","style":"standard","isBold":true,"hasShadow":true}
        """
        let decoded = try JSONDecoder().decode(TextOverlay.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.color, TextColorPreset.pink.tint)
    }

    func testEveryStyleDrawsVisibleText() throws {
        for style in TextStyle.allCases {
            var text = overlay(text: "あA")
            text.style = style
            let data = try render([text])
            XCTAssertGreaterThan(brightPixels(data, columns: 0..<side), 20, "\(style)")
        }
    }

    func testBoldAndRegularBothDraw() throws {
        for style in TextStyle.allCases {
            for bold in [true, false] {
                var text = overlay(text: "Aa")
                text.style = style
                text.isBold = bold
                XCTAssertGreaterThan(brightPixels(try render([text]), columns: 0..<side), 20, "\(style) bold=\(bold)")
            }
        }
    }

    func testOnlyTheSystemStyleHasNoPreviewFont() {
        XCTAssertNil(TextStyle.standard.previewFontName)
        for style in TextStyle.allCases where style != .standard {
            XCTAssertNotNil(style.previewFontName, "\(style)")
        }
    }

    func testStylesSurviveJSONRoundTrip() throws {
        for style in TextStyle.allCases {
            let decoded = try JSONDecoder().decode(TextStyle.self, from: JSONEncoder().encode(style))
            XCTAssertEqual(decoded, style)
        }
    }

    func testTextOverflowingThePhotoKeepsTheOutputSize() throws {
        // 文字が写真の端をはみ出しても、書き出す画像の大きさは変わらない(はみ出した部分は切り落とす)。
        for center in [CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5), CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 1)] {
            var p = AdjustmentParameters()
            var big = overlay(center: center)
            big.size = 0.5
            p.texts = [big]
            let cgImage = try XCTUnwrap(renderer.render(renderer.makeSource(image: black()), parameters: p))
            XCTAssertEqual(cgImage.width, side, "center \(center)")
            XCTAssertEqual(cgImage.height, side, "center \(center)")
        }
    }

    func testSeveralOverflowingTextsKeepTheSize() throws {
        var p = AdjustmentParameters()
        p.texts = [overlay(center: CGPoint(x: 0, y: 0)), overlay(center: CGPoint(x: 1, y: 1))]
        let cgImage = try XCTUnwrap(renderer.render(renderer.makeSource(image: black()), parameters: p))
        XCTAssertEqual(cgImage.width, side)
        XCTAssertEqual(cgImage.height, side)
    }
}

