import XCTest
@testable import NuvoCore

final class BilateralFilterTests: XCTestCase {
    private let width = 20
    private let height = 20

    /// 左半分が暗く(50)、右半分が明るい(200)画像に、±5 の市松ノイズを載せる。
    private func noisyStep() -> [UInt8] {
        var pixels: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width {
                let base = x < width / 2 ? 50 : 200
                let noise = (x + y) % 2 == 0 ? 5 : -5
                let v = UInt8(base + noise)
                pixels += [v, v, v, 255]
            }
        }
        return pixels
    }

    private func filtered() -> [UInt8] {
        BilateralFilter.apply(rgba: noisyStep(), mask: [UInt8](repeating: 255, count: width * height),
                              width: width, height: height, radius: 3, rangeSigma: 25)
    }

    private func value(_ pixels: [UInt8], x: Int, y: Int) -> Int { Int(pixels[(y * width + x) * 4]) }

    func testNoiseInsideFlatRegionIsSmoothed() {
        let result = filtered()
        XCTAssertEqual(value(result, x: 4, y: 10), 50, accuracy: 2)
        XCTAssertEqual(value(result, x: 15, y: 10), 200, accuracy: 2)
    }

    func testStrongEdgeIsPreserved() {
        let result = filtered()
        // 境界の両側が混ざらず、それぞれの側の明るさを保つ。
        XCTAssertLessThan(value(result, x: 9, y: 10), 70)
        XCTAssertGreaterThan(value(result, x: 10, y: 10), 180)
    }

    func testMaskedOutPixelsAreUntouched() {
        let source = noisyStep()
        let result = BilateralFilter.apply(rgba: source, mask: [UInt8](repeating: 0, count: width * height),
                                           width: width, height: height, radius: 3, rangeSigma: 25)
        XCTAssertEqual(result, source)
    }
}
