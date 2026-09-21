import CoreGraphics
import XCTest
@testable import NuvoCore

final class FaceGeometryTests: XCTestCase {
    func testSkinPolygonAddsForeheadPoints() {
        let face = TestFaces.square()
        let polygon = FaceGeometry.skinPolygon(face)
        XCTAssertEqual(polygon.count, face.faceContour.count + 3)
        // 額は輪郭の両端より上(y が小さい)にある。
        XCTAssertLessThan(polygon.map(\.y).min() ?? 1, 0.5)
    }

    func testSkinPolygonFallsBackToBoundingBoxWithoutContour() {
        let face = FaceLandmarks(boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5))
        XCTAssertEqual(FaceGeometry.skinPolygon(face).count, 4)
    }

    func testExclusionSkipsDegenerateRegions() {
        let face = TestFaces.square()
        XCTAssertEqual(FaceGeometry.exclusionPolygons(face).count, 1)
    }

    func testExpandedScalesAroundCentroid() {
        let square = [CGPoint(x: 0, y: 0), CGPoint(x: 2, y: 0), CGPoint(x: 2, y: 2), CGPoint(x: 0, y: 2)]
        let bigger = FaceGeometry.expanded(square, by: 2)
        let rect = FaceGeometry.boundingRect(of: bigger)
        XCTAssertEqual(rect, CGRect(x: -1, y: -1, width: 4, height: 4))
    }

    func testScaledConvertsToPixels() {
        let scaled = FaceGeometry.scaled([CGPoint(x: 0.5, y: 0.25)], to: CGSize(width: 200, height: 100))
        XCTAssertEqual(scaled, [CGPoint(x: 100, y: 25)])
    }
}
