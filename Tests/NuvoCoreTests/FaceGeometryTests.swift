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

    // MARK: まぶた・瞳

    /// 目頭 (0, 0) と目尻 (10, 0) の間に、上に 1 点・下に 1 点ある目。
    private let eye = [CGPoint(x: 0, y: 0), CGPoint(x: 4, y: -3), CGPoint(x: 10, y: 0), CGPoint(x: 5, y: 3)]

    func testEyelidsSplitAboveAndBelowTheCornerLine() throws {
        let lids = try XCTUnwrap(FaceGeometry.eyelids(eye))
        // どちらの折れ線も、両端の角を含めて左から右へ並ぶ。
        XCTAssertEqual(lids.upper.first, CGPoint(x: 0, y: 0))
        XCTAssertEqual(lids.upper.last, CGPoint(x: 10, y: 0))
        XCTAssertEqual(lids.lower.first, CGPoint(x: 0, y: 0))
        XCTAssertEqual(lids.lower.last, CGPoint(x: 10, y: 0))
        // 上まぶたには y が小さい点、下まぶたには y が大きい点が入る。
        XCTAssertEqual(lids.upper.count, 3)
        XCTAssertEqual(lids.lower.count, 3)
        XCTAssertEqual(lids.upper[1], CGPoint(x: 4, y: -3))
        XCTAssertEqual(lids.lower[1], CGPoint(x: 5, y: 3))
    }

    func testEyelidsDoNotDependOnPointOrder() throws {
        let shuffled = [eye[2], eye[0], eye[3], eye[1]]
        let lids = try XCTUnwrap(FaceGeometry.eyelids(shuffled))
        XCTAssertEqual(lids.upper[1], CGPoint(x: 4, y: -3))
        XCTAssertEqual(lids.lower[1], CGPoint(x: 5, y: 3))
    }

    func testEyelidsNeedEnoughPointsOnBothSides() {
        XCTAssertNil(FaceGeometry.eyelids([CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 0)]))
        // 3 点未満や、幅がない(縦に並ぶ)輪郭では線にならない。
        XCTAssertNil(FaceGeometry.eyelids([CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1),
                                           CGPoint(x: 0, y: 2), CGPoint(x: 0, y: 3)]))
    }

    func testOffsetMovesVertically() {
        XCTAssertEqual(FaceGeometry.offset([CGPoint(x: 1, y: 2)], dy: 3), [CGPoint(x: 1, y: 5)])
    }

    func testPupilCenterPrefersThePointInsideThatEye() throws {
        let other = CGPoint(x: 100, y: 0)
        let mine = CGPoint(x: 5, y: 0)
        let center = try XCTUnwrap(FaceGeometry.pupilCenter(for: eye, pupils: [other, mine]))
        XCTAssertEqual(center, mine)
    }

    func testPupilCenterFallsBackToTheCentroid() throws {
        let center = try XCTUnwrap(FaceGeometry.pupilCenter(for: eye, pupils: []))
        XCTAssertEqual(center, FaceGeometry.centroid(eye))
    }

    // MARK: 顔の傾き(ロール)

    func testFaceAxesAreUprightWhenEyesAreLevel() {
        let axes = FaceGeometry.faceAxes(leftEye: [CGPoint(x: 40, y: 45)], rightEye: [CGPoint(x: 60, y: 45)],
                                         mouth: [CGPoint(x: 50, y: 70)])
        XCTAssertEqual(axes.horizontal.x, 1, accuracy: 0.001)
        XCTAssertEqual(axes.horizontal.y, 0, accuracy: 0.001)
        XCTAssertEqual(axes.vertical.x, 0, accuracy: 0.001)
        XCTAssertEqual(axes.vertical.y, 1, accuracy: 0.001)
    }

    /// 頭を右に 90° 傾けた状態(元は横並びの目が縦に並ぶ)。
    func testFaceAxesFollowARolledFace() {
        let axes = FaceGeometry.faceAxes(leftEye: [CGPoint(x: 50, y: 40)], rightEye: [CGPoint(x: 50, y: 60)],
                                         mouth: [CGPoint(x: 30, y: 50)])
        XCTAssertEqual(axes.horizontal.x, 0, accuracy: 0.001)
        XCTAssertEqual(axes.horizontal.y, 1, accuracy: 0.001)
        // 口が (30, 50) にあるので、「下(あご方向)」はマイナス x。
        XCTAssertEqual(axes.vertical.x, -1, accuracy: 0.001)
        XCTAssertEqual(axes.vertical.y, 0, accuracy: 0.001)
    }

    func testFaceAxesFallBackWhenEyesAreMissing() {
        let axes = FaceGeometry.faceAxes(leftEye: [], rightEye: [CGPoint(x: 60, y: 45)], mouth: [])
        XCTAssertEqual(axes.horizontal, CGPoint(x: 1, y: 0))
        XCTAssertEqual(axes.vertical, CGPoint(x: 0, y: 1))
    }

    func testProjectedMatchesImageAxesWhenUpright() {
        let axes = FaceGeometry.FaceAxes(horizontal: CGPoint(x: 1, y: 0), vertical: CGPoint(x: 0, y: 1))
        let local = FaceGeometry.projected(CGPoint(x: 70, y: 30), origin: CGPoint(x: 50, y: 50), axes: axes)
        XCTAssertEqual(local, CGPoint(x: 20, y: -20))
    }

    func testProjectedRotatesIntoTheFaceLocalFrame() {
        // 90° 傾いた顔の軸(上のテストと同じ。vertical=(-1, 0) なので、あご方向は画像上「左」)。
        // 画像上「右」(+x)に 20 ずれた点は、あごとは逆側(顔から見て「上」)に 20 ずれている。
        let axes = FaceGeometry.FaceAxes(horizontal: CGPoint(x: 0, y: 1), vertical: CGPoint(x: -1, y: 0))
        let local = FaceGeometry.projected(CGPoint(x: 70, y: 50), origin: CGPoint(x: 50, y: 50), axes: axes)
        XCTAssertEqual(local, CGPoint(x: 0, y: -20))
    }
}
