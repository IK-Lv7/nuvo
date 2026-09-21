import CoreGraphics
import XCTest
@testable import NuvoCore

final class CoordinateConversionTests: XCTestCase {
    private let size = CGSize(width: 200, height: 100)

    func testVisionOriginMapsToBottomLeft() {
        let p = CoordinateConversion.visionNormalizedToTopLeft(CGPoint.zero, imageSize: size)
        XCTAssertEqual(p, CGPoint(x: 0, y: 100))
    }

    func testVisionTopRightMapsToTopRight() {
        let p = CoordinateConversion.visionNormalizedToTopLeft(CGPoint(x: 1, y: 1), imageSize: size)
        XCTAssertEqual(p, CGPoint(x: 200, y: 0))
    }

    func testPointRoundTrip() {
        let original = CGPoint(x: 0.3, y: 0.8)
        let pixel = CoordinateConversion.visionNormalizedToTopLeft(original, imageSize: size)
        let back = CoordinateConversion.topLeftToVisionNormalized(pixel, imageSize: size)
        XCTAssertEqual(back.x, original.x, accuracy: 1e-9)
        XCTAssertEqual(back.y, original.y, accuracy: 1e-9)
    }

    func testRectFlipsVertically() {
        // 下半分の矩形(Vision 座標)は、左上原点では下半分のまま y=50 から始まる。
        let rect = CoordinateConversion.visionNormalizedToTopLeft(
            CGRect(x: 0, y: 0, width: 0.5, height: 0.5), imageSize: size)
        XCTAssertEqual(rect, CGRect(x: 0, y: 50, width: 100, height: 50))
    }
}

final class LandmarkConversionTests: XCTestCase {
    func testLandmarkAtBoxOriginMapsToBoxBottomLeft() {
        // Vision の顔ボックスは左下原点。ボックス左下 (0, 0) は、左上原点では y = 1 - minY。
        let box = CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.5)
        let p = CoordinateConversion.visionLandmarkToTopLeftUnit(CGPoint(x: 0, y: 0), boundingBox: box)
        XCTAssertEqual(p.x, 0.2, accuracy: 1e-9)
        XCTAssertEqual(p.y, 0.7, accuracy: 1e-9)
    }

    func testLandmarkAtBoxTopRightMapsToBoxTopRight() {
        let box = CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.5)
        let p = CoordinateConversion.visionLandmarkToTopLeftUnit(CGPoint(x: 1, y: 1), boundingBox: box)
        XCTAssertEqual(p.x, 0.6, accuracy: 1e-9)
        XCTAssertEqual(p.y, 0.2, accuracy: 1e-9)
    }
}
