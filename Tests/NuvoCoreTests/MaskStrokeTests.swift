import CoreGraphics
import XCTest
@testable import NuvoCore

final class MaskStrokeTests: XCTestCase {
    private let side = 40

    /// 全面「背景」(0)のマスク。
    private func emptyGray() -> [UInt8] { [UInt8](repeating: 0, count: side * side) }

    private func value(_ gray: [UInt8], x: Int, y: Int) -> UInt8 { gray[y * side + x] }

    // MARK: 1点(タップ)

    func testATapAddsACircleOfTheGivenRadius() {
        var gray = emptyGray()
        MaskStroke(points: [CGPoint(x: 0.5, y: 0.5)], radius: 0.1, mode: .keep)
            .rasterize(into: &gray, width: side, height: side)
        // 半径 0.1 × 長辺 40 = 4px。中心は塗られ、遠く離れた角は塗られない。
        XCTAssertGreaterThan(value(gray, x: 20, y: 20), 200)
        XCTAssertEqual(value(gray, x: 0, y: 0), 0)
    }

    func testEraseModePushesTowardZero() {
        var gray = [UInt8](repeating: 255, count: side * side)
        MaskStroke(points: [CGPoint(x: 0.5, y: 0.5)], radius: 0.1, mode: .erase)
            .rasterize(into: &gray, width: side, height: side)
        XCTAssertLessThan(value(gray, x: 20, y: 20), 50)
    }

    func testEdgeIsFeatheredNotHard() {
        var gray = emptyGray()
        MaskStroke(points: [CGPoint(x: 0.5, y: 0.5)], radius: 0.1, mode: .keep)
            .rasterize(into: &gray, width: side, height: side)
        // 半径のすぐ外側は、0 でも 255 でもない中間値になる(継ぎ目をぼかしているため)。
        let edge = Int(value(gray, x: 24, y: 20))
        XCTAssertGreaterThan(edge, 0)
        XCTAssertLessThan(edge, 255)
    }

    func testFarOutsidePixelsAreUntouched() {
        var gray = emptyGray()
        MaskStroke(points: [CGPoint(x: 0.5, y: 0.5)], radius: 0.05, mode: .keep)
            .rasterize(into: &gray, width: side, height: side)
        XCTAssertEqual(value(gray, x: 39, y: 39), 0)
    }

    // MARK: ドラッグ(複数点)

    func testADragConnectsThePointsIntoOneLine() {
        var gray = emptyGray()
        MaskStroke(points: [CGPoint(x: 0.2, y: 0.5), CGPoint(x: 0.8, y: 0.5)], radius: 0.05, mode: .keep)
            .rasterize(into: &gray, width: side, height: side)
        // 始点・終点だけでなく、線の途中(中央)も塗られている。
        XCTAssertGreaterThan(value(gray, x: 20, y: 20), 200)
    }

    // MARK: マスクへの適用(SubjectMask.applyingStrokes)

    func testApplyingNoStrokesReturnsTheSameInstance() throws {
        let base = try XCTUnwrap(SubjectMask(grayBytes: emptyGray(), width: side, height: side))
        XCTAssertTrue(base.applyingStrokes([]) === base)
    }

    func testAKeepStrokeAddsAPersonRegionToAnEmptyMask() throws {
        let base = try XCTUnwrap(SubjectMask(grayBytes: emptyGray(), width: side, height: side))
        let edited = base.applyingStrokes([MaskStroke(points: [CGPoint(x: 0.5, y: 0.5)], radius: 0.15, mode: .keep)])
        // 塗った場所には、人物として現れる行がある。
        XCTAssertNotNil(edited.topEdge(columns: 0.4...0.6))
    }

    func testLaterStrokesWinOverEarlierOnesWhereTheyOverlap() throws {
        let base = try XCTUnwrap(SubjectMask(grayBytes: emptyGray(), width: side, height: side))
        let strokes = [
            MaskStroke(points: [CGPoint(x: 0.5, y: 0.5)], radius: 0.2, mode: .keep),
            MaskStroke(points: [CGPoint(x: 0.5, y: 0.5)], radius: 0.2, mode: .erase),
        ]
        let edited = base.applyingStrokes(strokes)
        // 後から描いた消しゴムが勝ち、その場所は背景のままになる。
        XCTAssertNil(edited.topEdge(columns: 0.4...0.6))
    }
}
