import CoreGraphics
import XCTest
@testable import NuvoCore

final class BlemishDetectorTests: XCTestCase {
    private let side = 80

    /// 肌色の画像に、指定した位置・半径・色の円を描く。
    private func skin(spotAt center: CGPoint? = nil, radius: Double = 0,
                      color: (UInt8, UInt8, UInt8) = (170, 110, 95)) -> [UInt8] {
        var pixels: [UInt8] = []
        for y in 0..<side {
            for x in 0..<side {
                var pixel: (UInt8, UInt8, UInt8) = (224, 172, 150)
                if let center, hypot(Double(x) + 0.5 - center.x, Double(y) + 0.5 - center.y) <= radius {
                    pixel = color
                }
                pixels += [pixel.0, pixel.1, pixel.2, 255]
            }
        }
        return pixels
    }

    private func detect(_ pixels: [UInt8]) -> [BlemishDetector.Blob] {
        BlemishDetector.detect(rgba: pixels, mask: [UInt8](repeating: 255, count: side * side),
                               width: side, height: side, faceWidth: 200)
    }

    func testFindsASmallDarkSpot() throws {
        let blobs = detect(skin(spotAt: CGPoint(x: 40, y: 40), radius: 3))
        XCTAssertEqual(blobs.count, 1)
        let blob = try XCTUnwrap(blobs.first)
        XCTAssertEqual(blob.center.x, 40, accuracy: 2)
        XCTAssertEqual(blob.center.y, 40, accuracy: 2)
        XCTAssertGreaterThanOrEqual(blob.radius, 3)
    }

    func testFindsARedSpotAsWell() {
        // 明るさは同程度で赤みだけが強いニキビ。
        let blobs = detect(skin(spotAt: CGPoint(x: 40, y: 40), radius: 3, color: (235, 120, 110)))
        XCTAssertEqual(blobs.count, 1)
    }

    func testUniformSkinHasNoBlemishes() {
        XCTAssertTrue(detect(skin()).isEmpty)
    }

    func testLargeDarkAreaIsNotTreatedAsABlemish() {
        // 大きな影や目のような構造は、塊が大きすぎるため対象外。
        XCTAssertTrue(detect(skin(spotAt: CGPoint(x: 40, y: 40), radius: 20)).isEmpty)
    }

    func testMaskedOutAreaIsIgnored() {
        let blobs = BlemishDetector.detect(rgba: skin(spotAt: CGPoint(x: 40, y: 40), radius: 3),
                                           mask: [UInt8](repeating: 0, count: side * side),
                                           width: side, height: side, faceWidth: 200)
        XCTAssertTrue(blobs.isEmpty)
    }

    func testMismatchedInputReturnsNothing() {
        XCTAssertTrue(BlemishDetector.detect(rgba: [0, 0, 0, 0], mask: [255, 255], width: 2, height: 2,
                                             faceWidth: 100).isEmpty)
    }
}
