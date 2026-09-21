import CoreGraphics
import XCTest
@testable import NuvoCore

final class SkinMaskTests: XCTestCase {
    private let side = 100

    /// 肌色(R224 G172 B150)で塗りつぶした画像。
    private func skinPixels(count: Int) -> [UInt8] {
        (0..<count).flatMap { _ in [UInt8(224), 172, 150, 255] }
    }

    private func makeMask(pixels: [UInt8]? = nil) -> [UInt8] {
        SkinMask.make(face: TestFaces.square(), imageSize: CGSize(width: side, height: side),
                      roiOrigin: .zero, width: side, height: side,
                      rgba: pixels ?? skinPixels(count: side * side))
    }

    func testInsideFaceIsMasked() {
        XCTAssertGreaterThan(makeMask()[60 * side + 50], 200)
    }

    func testOutsideFaceIsNotMasked() {
        XCTAssertEqual(makeMask()[5 * side + 5], 0)
    }

    func testEyeIsExcluded() {
        // 目の中心 (0.4, 0.45) → ピクセル (40, 45)。
        XCTAssertLessThan(makeMask()[45 * side + 40], 10)
    }

    func testNonSkinColorIsNotMasked() {
        let blue: [UInt8] = (0..<(side * side)).flatMap { _ in [20, 40, 220, 255] }
        XCTAssertEqual(makeMask(pixels: blue)[60 * side + 50], 0)
    }

    func testSkinColorScoreIsHighForSkinAndLowForBlue() {
        XCTAssertGreaterThan(SkinMask.skinScore(r: 224, g: 172, b: 150), 0.9)
        XCTAssertLessThan(SkinMask.skinScore(r: 20, g: 40, b: 220), 0.1)
    }
}
