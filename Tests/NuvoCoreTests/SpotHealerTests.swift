import CoreGraphics
import XCTest
@testable import NuvoCore

final class SpotHealerTests: XCTestCase {
    private let side = 21

    /// 灰色(128)の画像の中央に、半径 2 の暗いシミ(30)を置く。
    private func imageWithSpot() -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        for y in 0..<side {
            for x in 0..<side {
                let isSpot = hypot(Double(x) + 0.5 - 10.5, Double(y) + 0.5 - 10.5) <= 2
                let v: UInt8 = isSpot ? 30 : 128
                pixels[(y * side + x) * 4 ..< (y * side + x) * 4 + 4] = [v, v, v, 255]
            }
        }
        return pixels
    }

    func testSpotIsRemoved() {
        var pixels = imageWithSpot()
        XCTAssertEqual(pixels[(10 * side + 10) * 4], 30)
        SpotHealer.heal(rgba: &pixels, width: side, height: side, center: CGPoint(x: 10.5, y: 10.5), radius: 4)
        XCTAssertEqual(Int(pixels[(10 * side + 10) * 4]), 128, accuracy: 2)
    }

    func testFarPixelsAreUntouched() {
        var pixels = imageWithSpot()
        SpotHealer.heal(rgba: &pixels, width: side, height: side, center: CGPoint(x: 10.5, y: 10.5), radius: 4)
        XCTAssertEqual(pixels[0], 128)
    }

    func testTinyRadiusIsIgnored() {
        var pixels = imageWithSpot()
        let before = pixels
        SpotHealer.heal(rgba: &pixels, width: side, height: side, center: CGPoint(x: 10.5, y: 10.5), radius: 0.5)
        XCTAssertEqual(pixels, before)
    }
}
