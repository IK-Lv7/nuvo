import CoreGraphics
import CoreImage
import XCTest
@testable import NuvoCore

final class CollageLayoutTests: XCTestCase {
    func testEverySlotStaysWithinTheUnitSquare() {
        for layout in CollageLayout.allCases {
            for slot in layout.slots {
                XCTAssertGreaterThanOrEqual(slot.minX, -0.0001)
                XCTAssertGreaterThanOrEqual(slot.minY, -0.0001)
                XCTAssertLessThanOrEqual(slot.maxX, 1.0001)
                XCTAssertLessThanOrEqual(slot.maxY, 1.0001)
            }
        }
    }

    func testLayoutsForCountOnlyReturnsMatchingLayouts() {
        for layout in CollageLayout.layouts(forCount: 2) { XCTAssertEqual(layout.slotCount, 2) }
        for layout in CollageLayout.layouts(forCount: 3) { XCTAssertEqual(layout.slotCount, 3) }
        for layout in CollageLayout.layouts(forCount: 4) { XCTAssertEqual(layout.slotCount, 4) }
        // 2〜4枚それぞれに、選べるレイアウトが複数用意されている。
        XCTAssertGreaterThan(CollageLayout.layouts(forCount: 2).count, 1)
        XCTAssertGreaterThan(CollageLayout.layouts(forCount: 3).count, 1)
        XCTAssertGreaterThan(CollageLayout.layouts(forCount: 4).count, 1)
    }
}

final class CollageComposerTests: XCTestCase {
    private let renderer = ImageRenderer()
    private let canvas = CGSize(width: 200, height: 200)

    private func solid(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, width: CGFloat = 100, height: CGFloat = 100) -> CIImage {
        CIImage(color: CIColor(red: red, green: green, blue: blue)).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> [Int] {
        let rgba = try XCTUnwrap(BitmapIO.rgba(from: image))
        let i = (y * image.width + x) * 4
        return [Int(rgba[i]), Int(rgba[i + 1]), Int(rgba[i + 2])]
    }

    func testMismatchedImageCountReturnsNil() {
        XCTAssertNil(CollageComposer.compose(images: [solid(1, 0, 0)], layout: .twoSideBySide,
                                             canvasSize: canvas, spacingRatio: 0, background: .white))
    }

    func testTwoPhotosLandOnTheirOwnSides() throws {
        let composed = try XCTUnwrap(CollageComposer.compose(
            images: [solid(1, 0, 0), solid(0, 0, 1)], layout: .twoSideBySide,
            canvasSize: canvas, spacingRatio: 0, background: .white))
        let cgImage = try XCTUnwrap(renderer.cgImage(from: composed))
        XCTAssertEqual(try pixel(cgImage, x: 40, y: 100), [255, 0, 0])
        XCTAssertEqual(try pixel(cgImage, x: 160, y: 100), [0, 0, 255])
    }

    func testFourGridPutsEachPhotoInItsOwnQuadrant() throws {
        let images = [solid(1, 0, 0), solid(0, 1, 0), solid(0, 0, 1), solid(1, 1, 0)]
        let composed = try XCTUnwrap(CollageComposer.compose(
            images: images, layout: .fourGrid, canvasSize: canvas, spacingRatio: 0, background: .white))
        let cgImage = try XCTUnwrap(renderer.cgImage(from: composed))
        XCTAssertEqual(try pixel(cgImage, x: 50, y: 50), [255, 0, 0])    // 左上
        XCTAssertEqual(try pixel(cgImage, x: 150, y: 50), [0, 255, 0])  // 右上
        XCTAssertEqual(try pixel(cgImage, x: 50, y: 150), [0, 0, 255])  // 左下
        XCTAssertEqual(try pixel(cgImage, x: 150, y: 150), [255, 255, 0]) // 右下
    }

    func testSpacingShowsTheBackgroundColorBetweenTiles() throws {
        let composed = try XCTUnwrap(CollageComposer.compose(
            images: [solid(1, 0, 0), solid(0, 0, 1)], layout: .twoSideBySide,
            canvasSize: canvas, spacingRatio: 0.2, background: .white))
        let cgImage = try XCTUnwrap(renderer.cgImage(from: composed))
        // 境目付近(x=100 前後)は、間隔をあけたぶん背景色(白)が見える。
        XCTAssertEqual(try pixel(cgImage, x: 100, y: 100), [255, 255, 255])
    }

    func testOutputSizeMatchesTheRequestedCanvas() throws {
        let composed = try XCTUnwrap(CollageComposer.compose(
            images: [solid(1, 0, 0), solid(0, 0, 1)], layout: .twoStacked,
            canvasSize: canvas, spacingRatio: 0, background: .white))
        XCTAssertEqual(composed.extent.width, canvas.width)
        XCTAssertEqual(composed.extent.height, canvas.height)
    }

    func testANonSquareSourcePhotoIsCroppedNotStretched() throws {
        // 横長の写真(200x50)を、正方形の枠(100x100)に入れる。引き伸ばさず、中央を切り出す。
        let wide = solid(1, 0, 0, width: 200, height: 50)
        let composed = try XCTUnwrap(CollageComposer.compose(
            images: [wide, solid(0, 0, 1)], layout: .twoSideBySide,
            canvasSize: canvas, spacingRatio: 0, background: .white))
        let cgImage = try XCTUnwrap(renderer.cgImage(from: composed))
        // 枠いっぱいが赤で埋まる(隙間に背景色が見えない)ことを確かめる。
        XCTAssertEqual(try pixel(cgImage, x: 10, y: 10), [255, 0, 0])
        XCTAssertEqual(try pixel(cgImage, x: 90, y: 190), [255, 0, 0])
    }
}
