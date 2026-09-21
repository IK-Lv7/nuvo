import CoreGraphics
import XCTest
@testable import NuvoCore

final class PortraitDepthTests: XCTestCase {
    private let side = 40

    /// 左半分が手前(200)、右半分が奥(50)の視差。
    private func disparity() -> [UInt8] {
        (0..<(side * side)).map { ($0 % side) < side / 2 ? 200 : 50 }
    }

    func testTheSubjectAtTheFocusDepthStaysSharp() throws {
        let mask = try XCTUnwrap(PortraitDepth.focusMask(
            disparity: disparity(), width: side, height: side, focus: CGRect(x: 0.1, y: 0.4, width: 0.2, height: 0.2)))
        XCTAssertEqual(mask[20 * side + 5], 255)   // 手前 = ピントが合っている
        XCTAssertEqual(mask[20 * side + 35], 0)    // 奥 = 背景
    }

    func testFocusingOnTheFarSideReversesTheMask() throws {
        let mask = try XCTUnwrap(PortraitDepth.focusMask(
            disparity: disparity(), width: side, height: side, focus: CGRect(x: 0.7, y: 0.4, width: 0.2, height: 0.2)))
        XCTAssertEqual(mask[20 * side + 35], 255)
        XCTAssertEqual(mask[20 * side + 5], 0)
    }

    func testGradedDepthProducesGradedMask() throws {
        // なだらかに変わる視差では、ピントから離れるほどマスクが弱くなる。
        let ramp: [UInt8] = (0..<(side * side)).map { UInt8(($0 % side) * 255 / (side - 1)) }
        let mask = try XCTUnwrap(PortraitDepth.focusMask(
            disparity: ramp, width: side, height: side, focus: CGRect(x: 0.0, y: 0.4, width: 0.1, height: 0.2)))
        XCTAssertGreaterThan(mask[20 * side + 1], mask[20 * side + 10])
        XCTAssertGreaterThan(mask[20 * side + 10], mask[20 * side + 30])
    }

    func testFlatDepthHasNoMask() {
        XCTAssertNil(PortraitDepth.focusMask(disparity: [UInt8](repeating: 100, count: side * side),
                                             width: side, height: side, focus: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)))
    }

    func testMismatchedSizeHasNoMask() {
        XCTAssertNil(PortraitDepth.focusMask(disparity: [1, 2, 3], width: 2, height: 2, focus: .zero))
    }

    func testGrayBytesBuildASubjectMask() throws {
        let mask = try XCTUnwrap(SubjectMask(grayBytes: [UInt8](repeating: 255, count: 16), width: 4, height: 4))
        XCTAssertEqual(try XCTUnwrap(mask.topEdge(columns: 0...1)), 0, accuracy: 0.01)
    }
}
