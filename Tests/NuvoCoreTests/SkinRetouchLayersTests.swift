import CoreGraphics
import XCTest
@testable import NuvoCore

final class SkinRetouchLayersTests: XCTestCase {
    private func layers(original: UInt8, smoothed: UInt8, mask: UInt8) -> SkinRetouchLayers {
        func plane(_ v: UInt8) -> [UInt8] { [v, v, v, 255] }
        return SkinRetouchLayers(roi: CGRect(x: 0, y: 0, width: 1, height: 1), width: 1, height: 1,
                                 original: plane(original), smoothed: plane(smoothed), mask: [mask])
    }

    func testZeroStrengthReturnsOriginal() {
        let result = layers(original: 200, smoothed: 100, mask: 255).blended(smoothing: 0, brightness: 0)
        XCTAssertEqual(result[0], 200)
    }

    func testFullSmoothingKeepsPartOfTheOriginal() {
        // 200 + (100 - 200) * 0.6 = 140。強度 100% でも元画像を 40% 残す。
        let result = layers(original: 200, smoothed: 100, mask: 255).blended(smoothing: 1, brightness: 0)
        XCTAssertEqual(Int(result[0]), 140, accuracy: 1)
    }

    func testMaskZeroLeavesPixelUnchanged() {
        let result = layers(original: 200, smoothed: 100, mask: 0).blended(smoothing: 1, brightness: 1)
        XCTAssertEqual(result[0], 200)
    }

    func testNegativeSmoothingEmphasizesDetail() {
        let result = layers(original: 200, smoothed: 100, mask: 255).blended(smoothing: -1, brightness: 0)
        XCTAssertGreaterThan(result[0], 200)
    }

    func testBrightnessDirection() {
        let base = layers(original: 128, smoothed: 128, mask: 255)
        XCTAssertGreaterThan(base.blended(smoothing: 0, brightness: 1)[0], 128)
        XCTAssertLessThan(base.blended(smoothing: 0, brightness: -1)[0], 128)
    }

    func testFlushAddsRednessWithoutChangingBrightnessMuch() {
        let skin = SkinRetouchLayers(roi: CGRect(x: 0, y: 0, width: 1, height: 1), width: 1, height: 1,
                                     original: [200, 150, 140, 255], smoothed: [200, 150, 140, 255], mask: [255])
        let rosy = skin.blended(smoothing: 0, brightness: 0, flush: 1)
        XCTAssertGreaterThan(rosy[0], 200)
        XCTAssertLessThan(rosy[1], 150)
        let lumaBefore = 0.299 * 200 + 0.587 * 150 + 0.114 * 140
        let lumaAfter = 0.299 * Double(rosy[0]) + 0.587 * Double(rosy[1]) + 0.114 * Double(rosy[2])
        XCTAssertEqual(lumaAfter, lumaBefore, accuracy: 3)
    }

    func testNegativeFlushReducesRedness() {
        let skin = SkinRetouchLayers(roi: CGRect(x: 0, y: 0, width: 1, height: 1), width: 1, height: 1,
                                     original: [200, 150, 140, 255], smoothed: [200, 150, 140, 255], mask: [255])
        XCTAssertLessThan(skin.blended(smoothing: 0, brightness: 0, flush: -1)[0], 200)
    }

    func testFlushIgnoresPixelsOutsideTheSkinMask() {
        let outside = SkinRetouchLayers(roi: CGRect(x: 0, y: 0, width: 1, height: 1), width: 1, height: 1,
                                        original: [200, 150, 140, 255], smoothed: [200, 150, 140, 255], mask: [0])
        XCTAssertEqual(Array(outside.blended(smoothing: 0, brightness: 0, flush: 1).prefix(3)), [200, 150, 140])
    }
}

