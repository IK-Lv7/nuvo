import CoreGraphics
import CoreImage
import XCTest
@testable import NuvoCore

final class GeometryAdjustTests: XCTestCase {
    private let renderer = ImageRenderer()

    /// 左半分が赤、右半分が青の画像。向きの変化を画素で確認できる。
    private func splitImage(width: CGFloat = 8, height: CGFloat = 4) -> CIImage {
        let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0))
            .cropped(to: CGRect(x: 0, y: 0, width: width / 2, height: height))
        let blue = CIImage(color: CIColor(red: 0, green: 0, blue: 1))
            .cropped(to: CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        return red.composited(over: blue)
    }

    private func render(_ p: AdjustmentParameters, _ image: CIImage) throws -> CGImage {
        try XCTUnwrap(renderer.render(renderer.makeSource(image: image), parameters: p))
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> [Int] {
        let data = try XCTUnwrap(BitmapIO.rgba(from: image))
        let i = (y * image.width + x) * 4
        return [Int(data[i]), Int(data[i + 1]), Int(data[i + 2])]
    }

    func testNoAdjustmentKeepsTheImage() throws {
        let image = try render(AdjustmentParameters(), splitImage())
        XCTAssertEqual(image.width, 8)
        XCTAssertEqual(image.height, 4)
    }

    func testQuarterTurnSwapsWidthAndHeight() throws {
        var p = AdjustmentParameters()
        p.rotationQuarterTurns = 1
        let image = try render(p, splitImage())
        XCTAssertEqual(image.width, 4)
        XCTAssertEqual(image.height, 8)
    }

    func testFullTurnsCycleBackToTheOriginal() throws {
        var p = AdjustmentParameters()
        p.rotationQuarterTurns = 4
        let image = try render(p, splitImage())
        XCTAssertEqual(image.width, 8)
        XCTAssertEqual(try pixel(image, x: 1, y: 1)[0], 255, accuracy: 8)
    }

    func testClockwiseTurnMovesTheLeftSideToTheTop() throws {
        // 時計回りに 90° 回すと、左にあった赤が上に来る。
        var p = AdjustmentParameters()
        p.rotationQuarterTurns = 1
        let image = try render(p, splitImage())
        XCTAssertEqual(try pixel(image, x: 2, y: 1)[0], 255, accuracy: 8)
        XCTAssertEqual(try pixel(image, x: 2, y: 6)[2], 255, accuracy: 8)
    }

    func testFlipSwapsLeftAndRight() throws {
        var p = AdjustmentParameters()
        p.flipHorizontal = true
        let image = try render(p, splitImage())
        XCTAssertEqual(try pixel(image, x: 1, y: 2)[2], 255, accuracy: 8)
        XCTAssertEqual(try pixel(image, x: 6, y: 2)[0], 255, accuracy: 8)
    }

    func testInscribedScaleMatchesKnownValues() {
        XCTAssertEqual(GeometryAdjust.inscribedScale(width: 1000, height: 1000, radians: 0), 1, accuracy: 1e-9)
        // 正方形を 45° 回すと、内側に収まる最大の正方形は 1/√2。
        XCTAssertEqual(GeometryAdjust.inscribedScale(width: 1000, height: 1000, radians: .pi / 4),
                       CGFloat(1 / 2.0.squareRoot()), accuracy: 1e-6)
    }

    func testInscribedScaleFitsInsideTheRotatedImage() {
        // 求めた倍率の矩形の四隅を、元の画像の座標へ戻して、はみ出さないことを確認する。
        let w: CGFloat = 400, h: CGFloat = 200, theta: CGFloat = 0.3
        let s = GeometryAdjust.inscribedScale(width: w, height: h, radians: theta)
        for (cx, cy) in [(1.0, 1.0), (1.0, -1.0), (-1.0, 1.0), (-1.0, -1.0)] {
            let x = CGFloat(cx) * w * s / 2, y = CGFloat(cy) * h * s / 2
            XCTAssertLessThanOrEqual(abs(x * cos(theta) + y * sin(theta)), w / 2 + 1e-6)
            XCTAssertLessThanOrEqual(abs(-x * sin(theta) + y * cos(theta)), h / 2 + 1e-6)
        }
    }

    func testStraightenShrinksTheImageWithoutBlankCorners() throws {
        var p = AdjustmentParameters()
        p.straighten = 0.5  // 15°
        let image = try render(p, splitImage(width: 100, height: 100))
        XCTAssertLessThan(image.width, 100)
        XCTAssertEqual(Double(image.width), Double(image.height), accuracy: 2)
    }

    func testAspectCropUsesTheLargestCenteredArea() throws {
        var p = AdjustmentParameters()
        p.cropAspect = .square
        let square = try render(p, splitImage(width: 400, height: 200))
        XCTAssertEqual(square.width, 200)
        XCTAssertEqual(square.height, 200)

        p.cropAspect = .r4x5
        let portrait = try render(p, splitImage(width: 400, height: 200))
        XCTAssertEqual(portrait.width, 160)
        XCTAssertEqual(portrait.height, 200)
    }

    func testWideCropOfAPortraitKeepsFullWidth() throws {
        var p = AdjustmentParameters()
        p.cropAspect = .r16x9
        let image = try render(p, splitImage(width: 160, height: 400))
        XCTAssertEqual(image.width, 160)
        XCTAssertEqual(Double(image.height), 90, accuracy: 1)
    }

    // MARK: ズーム

    func testZoomHalvesBothSides() throws {
        var p = AdjustmentParameters()
        p.cropZoom = 2
        let image = try render(p, splitImage(width: 400, height: 200))
        XCTAssertEqual(image.width, 200)
        XCTAssertEqual(image.height, 100)
    }

    func testZoomFollowsTheCenter() throws {
        // 左半分が赤・右半分が青。中心を左に置けば赤だけ、右に置けば青だけが残る。
        var p = AdjustmentParameters()
        p.cropZoom = 2
        p.cropCenter = CGPoint(x: 0.25, y: 0.5)
        let left = try render(p, splitImage())
        XCTAssertEqual(try pixel(left, x: 1, y: 1)[0], 255, accuracy: 8)
        XCTAssertEqual(try pixel(left, x: left.width - 1, y: 1)[2], 0, accuracy: 8)

        p.cropCenter = CGPoint(x: 0.75, y: 0.5)
        let right = try render(p, splitImage())
        XCTAssertEqual(try pixel(right, x: 0, y: 1)[2], 255, accuracy: 8)
        XCTAssertEqual(try pixel(right, x: 0, y: 1)[0], 0, accuracy: 8)
    }

    func testZoomKeepsTheWindowInsideTheImage() throws {
        // 中心が端でも、範囲は画像の外に出ない(大きさは変わらず、内側へ寄る)。
        var p = AdjustmentParameters()
        p.cropZoom = 2
        p.cropCenter = CGPoint(x: 0, y: 0)
        let corner = try render(p, splitImage(width: 400, height: 200))
        XCTAssertEqual(corner.width, 200)
        XCTAssertEqual(corner.height, 100)
        XCTAssertEqual(try pixel(corner, x: 0, y: 0)[0], 255, accuracy: 8)   // 左上は赤

        p.cropCenter = CGPoint(x: 1, y: 1)
        let far = try render(p, splitImage(width: 400, height: 200))
        XCTAssertEqual(try pixel(far, x: far.width - 1, y: far.height - 1)[2], 255, accuracy: 8)  // 右下は青
    }

    func testZoomOfOneChangesNothing() throws {
        var p = AdjustmentParameters()
        p.cropZoom = 1
        p.cropCenter = CGPoint(x: 0.9, y: 0.1)
        XCTAssertEqual(try render(p, splitImage()).width, 8)
    }

    func testZoomIsAppliedAfterTheAspectCrop() throws {
        var p = AdjustmentParameters()
        p.cropAspect = .square
        p.cropZoom = 2
        let image = try render(p, splitImage(width: 400, height: 200))
        // 400×200 → 正方形 200×200 → 2 倍 100×100。
        XCTAssertEqual(image.width, 100)
        XCTAssertEqual(image.height, 100)
    }
}

