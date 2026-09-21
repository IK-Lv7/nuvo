import CoreGraphics
import CoreImage
import XCTest
@testable import NuvoCore

final class FaceSelectionTests: XCTestCase {
    /// 横に並んだ 3 人。中心の x は 0.2 / 0.5 / 0.8、真ん中の人がいちばん大きい。
    private let faces = [
        FaceLandmarks(boundingBox: CGRect(x: 0.15, y: 0.4, width: 0.1, height: 0.15)),
        FaceLandmarks(boundingBox: CGRect(x: 0.4, y: 0.35, width: 0.2, height: 0.3)),
        FaceLandmarks(boundingBox: CGRect(x: 0.75, y: 0.4, width: 0.1, height: 0.15)),
    ]

    // MARK: 対象の絞り込み

    func testNoExclusionKeepsEveryone() {
        XCTAssertEqual(FaceSelection.selected(faces, excluding: []), faces)
    }

    func testExcludedFacesAreDropped() {
        XCTAssertEqual(FaceSelection.selected(faces, excluding: [0, 2]), [faces[1]])
    }

    func testUnknownIndexesAreIgnored() {
        XCTAssertEqual(FaceSelection.selected(faces, excluding: [9, -1]), faces)
    }

    func testUnselectedComesFromTheKeptSet() {
        XCTAssertEqual(FaceSelection.unselected(keeping: [1], faceCount: 3), [0, 2])
        XCTAssertEqual(FaceSelection.unselected(keeping: [0, 1, 2], faceCount: 3), [])
        XCTAssertEqual(FaceSelection.unselected(keeping: [], faceCount: 3), [0, 1, 2])
    }

    func testPrimaryIsTheLargestSelectedFace() {
        XCTAssertEqual(FaceSelection.primary(faces, excluding: []), faces[1])
        XCTAssertEqual(FaceSelection.primary(faces, excluding: [1]), faces[0])
        XCTAssertNil(FaceSelection.primary(faces, excluding: [0, 1, 2]))
    }

    // MARK: タップ

    func testTapInsideAFaceFindsIt() {
        XCTAssertEqual(FaceSelection.faceIndex(at: CGPoint(x: 0.2, y: 0.47), in: faces), 0)
        XCTAssertEqual(FaceSelection.faceIndex(at: CGPoint(x: 0.5, y: 0.5), in: faces), 1)
    }

    func testTapJustOutsideAFaceStillHitsBecauseOfPadding() {
        // 顔の枠から 0.01 外。枠の 15% 分は当たり判定に含める。
        XCTAssertEqual(FaceSelection.faceIndex(at: CGPoint(x: 0.14, y: 0.47), in: faces), 0)
    }

    func testTapOnBackgroundFindsNothing() {
        XCTAssertNil(FaceSelection.faceIndex(at: CGPoint(x: 0.05, y: 0.05), in: faces))
    }

    func testOverlappingFacesPreferTheSmallerOne() {
        let overlapping = [
            FaceLandmarks(boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)),
            FaceLandmarks(boundingBox: CGRect(x: 0.4, y: 0.4, width: 0.1, height: 0.1)),
        ]
        XCTAssertEqual(FaceSelection.faceIndex(at: CGPoint(x: 0.45, y: 0.45), in: overlapping), 1)
    }

    // MARK: 囲んで選ぶ

    private func circle(center: CGPoint, radius: CGFloat, points: Int = 24) -> [CGPoint] {
        (0..<points).map { i in
            let angle = Double(i) / Double(points) * 2 * .pi
            return CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
        }
    }

    func testLassoSelectsOnlyFacesWhoseCenterIsInside() {
        let lasso = circle(center: CGPoint(x: 0.2, y: 0.47), radius: 0.12)
        XCTAssertEqual(FaceSelection.indices(insideLasso: lasso, in: faces), [0])
    }

    func testLassoAroundSeveralFaces() {
        let lasso = [CGPoint(x: 0.1, y: 0.3), CGPoint(x: 0.9, y: 0.3), CGPoint(x: 0.9, y: 0.7), CGPoint(x: 0.1, y: 0.7)]
        XCTAssertEqual(FaceSelection.indices(insideLasso: lasso, in: faces), [0, 1, 2])
    }

    func testLassoMissingEveryoneSelectsNobody() {
        let lasso = circle(center: CGPoint(x: 0.5, y: 0.9), radius: 0.05)
        XCTAssertEqual(FaceSelection.indices(insideLasso: lasso, in: faces), [])
    }

    func testTooShortALineIsNotALasso() {
        XCTAssertEqual(FaceSelection.indices(insideLasso: [CGPoint(x: 0.2, y: 0.47), CGPoint(x: 0.3, y: 0.5)], in: faces), [])
    }

    func testAnOpenLineIsClosedBackToItsStart() {
        // 「コ」の字に囲んだだけで、終点を始点へ戻していない線でも、内側が囲みになる。
        let open = [CGPoint(x: 0.35, y: 0.3), CGPoint(x: 0.65, y: 0.3), CGPoint(x: 0.65, y: 0.7), CGPoint(x: 0.35, y: 0.7)]
        XCTAssertEqual(FaceSelection.indices(insideLasso: open, in: faces), [1])
    }

    // MARK: 設定値としての扱い

    func testDefaultSelectsEveryone() {
        XCTAssertNil(AdjustmentParameters().unselectedFaces)
        XCTAssertTrue(AdjustmentParameters().excludedFaces.isEmpty)
    }

    func testExcludingAFaceBreaksIdentity() {
        var p = AdjustmentParameters()
        p.unselectedFaces = [1]
        XCTAssertFalse(p.isIdentity)
    }

    func testLooksDoNotCarryWhoIsSelected() {
        var p = AdjustmentParameters()
        p.skinSmoothing = 0.5
        p.unselectedFaces = [1]
        XCTAssertNil(p.lookOnly().unselectedFaces)
        XCTAssertEqual(p.lookOnly().skinSmoothing, 0.5)
    }

    func testApplyingALookKeepsThisPhotosSelection() {
        var current = AdjustmentParameters()
        current.unselectedFaces = [0]
        var look = AdjustmentParameters()
        look.skinSmoothing = 0.5
        let applied = current.applyingLook(look)
        XCTAssertEqual(applied.unselectedFaces, [0])
        XCTAssertEqual(applied.skinSmoothing, 0.5)
    }

    func testSavedLooksWithoutTheFieldStillDecode() throws {
        // この項目を足す前に保存した JSON。読めないと、保存済みのルックがすべて消える。
        var object = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(AdjustmentParameters())) as? [String: Any])
        object.removeValue(forKey: "unselectedFaces")
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertNoThrow(try JSONDecoder().decode(AdjustmentParameters.self, from: data))
    }

    func testSelectionRoundTripsThroughJSON() throws {
        var p = AdjustmentParameters()
        p.unselectedFaces = [0, 2]
        let decoded = try JSONDecoder().decode(AdjustmentParameters.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded.unselectedFaces, [0, 2])
    }

    // MARK: 加工への反映

    /// 肌色の画像に、左右 1 人ずつの顔を置く。座標は正規化(左上原点)。
    private func twoFaces() -> [FaceLandmarks] {
        func shifted(_ dx: CGFloat) -> FaceLandmarks {
            var face = TestFaces.square()
            func map(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * 0.5 + dx, y: p.y) }
            face.boundingBox = CGRect(x: face.boundingBox.minX * 0.5 + dx, y: face.boundingBox.minY,
                                      width: face.boundingBox.width * 0.5, height: face.boundingBox.height)
            face.faceContour = face.faceContour.map(map)
            face.leftEye = face.leftEye.map(map)
            return face
        }
        return [shifted(0), shifted(0.5)]
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> [UInt8] {
        let rgba = try XCTUnwrap(BitmapIO.rgba(from: image))
        let i = (y * image.width + x) * 4
        return Array(rgba[i..<i + 3])
    }

    func testSkinBrighteningOnlyReachesTheSelectedFace() throws {
        let renderer = ImageRenderer()
        let base = CIImage(color: CIColor(red: 224.0 / 255, green: 172.0 / 255, blue: 150.0 / 255))
            .cropped(to: CGRect(x: 0, y: 0, width: 200, height: 100))
        let source = renderer.makeSource(image: base, faces: twoFaces())

        var p = AdjustmentParameters()
        p.skinBrightness = 1
        let everyone = try XCTUnwrap(renderer.render(source, parameters: p))
        p.unselectedFaces = [1]
        let onlyLeft = try XCTUnwrap(renderer.render(source, parameters: p))

        // 左の顔の中心 (50, 60) と、右の顔の中心 (150, 60)。
        XCTAssertEqual(try pixel(onlyLeft, x: 50, y: 60), try pixel(everyone, x: 50, y: 60))
        XCTAssertNotEqual(try pixel(everyone, x: 150, y: 60), try pixel(onlyLeft, x: 150, y: 60))
        assertPixel(try pixel(onlyLeft, x: 150, y: 60), [224, 172, 150].map { UInt8($0) }, accuracy: 4)
    }
}

private func assertPixel(_ a: [UInt8], _ b: [UInt8], accuracy: Int, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(a.count, b.count, file: file, line: line)
    for (x, y) in zip(a, b) {
        XCTAssertLessThanOrEqual(abs(Int(x) - Int(y)), accuracy, file: file, line: line)
    }
}
