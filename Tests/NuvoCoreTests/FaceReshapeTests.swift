import CoreGraphics
import XCTest
@testable import NuvoCore

final class FaceReshapeTests: XCTestCase {
    private let side = 100
    private let imageSize = CGSize(width: 100, height: 100)

    private func field(faceSlim: Double = 0, eyeEnlarge: Double = 0, chin: Double = 0) -> DisplacementField? {
        FaceReshape.field(face: TestFaces.full(), imageSize: imageSize, roiOrigin: .zero,
                          width: side, height: side, faceSlim: faceSlim, eyeEnlarge: eyeEnlarge, chin: chin)
    }

    /// 左から右へ明るくなる画像(R = 2x)。ずれの向きを値で確認できる。
    private func gradient() -> [UInt8] {
        (0..<(side * side)).flatMap { i in [UInt8((i % side) * 2), 0, 0, 255] }
    }

    func testNoAdjustmentProducesNoField() {
        XCTAssertNil(field())
    }

    func testZeroFieldKeepsPixels() {
        let pixels = gradient()
        let result = FaceReshape.warp(rgba: pixels, field: DisplacementField(width: side, height: side))
        XCTAssertEqual(result, pixels)
    }

    func testEyeEnlargeSamplesCloserToEyeCenter() throws {
        let field = try XCTUnwrap(field(eyeEnlarge: 1))
        let warped = FaceReshape.warp(rgba: gradient(), field: field)
        // 右目の中心 (60, 45) の右側では、拡大により中心寄りの(暗い)画素を参照する。
        let index = (45 * side + 66) * 4
        XCTAssertLessThan(warped[index], gradient()[index])
        // 左側では逆に明るい側を参照する。
        let leftIndex = (45 * side + 54) * 4
        XCTAssertGreaterThan(warped[leftIndex], gradient()[leftIndex])
    }

    func testEyeEnlargeDoesNotTouchFarPixels() throws {
        let field = try XCTUnwrap(field(eyeEnlarge: 1))
        XCTAssertEqual(field.dx[5 * side + 5], 0)
    }

    func testFaceSlimPullsContentInwardFromBothSides() throws {
        let field = try XCTUnwrap(field(faceSlim: 1))
        // 左の輪郭 (20, 50) は外側(左)から、右の輪郭 (80, 50) は外側(右)から色を引く。
        XCTAssertLessThan(field.dx[50 * side + 20], 0)
        XCTAssertGreaterThan(field.dx[50 * side + 80], 0)
        // 顔の中心は動かさない。
        XCTAssertEqual(field.dx[50 * side + 50], 0, accuracy: 0.001)
    }

    func testNegativeSlimReversesDirection() throws {
        let field = try XCTUnwrap(field(faceSlim: -1))
        XCTAssertGreaterThan(field.dx[50 * side + 20], 0)
    }

    func testChinMovesContentUpForPositiveValue() throws {
        let field = try XCTUnwrap(field(chin: 1))
        // あご先 (50, 90) では下側から色を引き、あごが短くなる。
        XCTAssertGreaterThan(field.dy[90 * side + 50], 0)
    }

    func testNoseSlimPullsTheWingsInwardFromBothSides() throws {
        let field = try XCTUnwrap(FaceReshape.field(face: TestFaces.full(), imageSize: imageSize, roiOrigin: .zero,
                                                    width: side, height: side, faceSlim: 0, eyeEnlarge: 0, chin: 0, noseSlim: 1))
        // 左の小鼻 (44, 58) は外側(左)から、右の小鼻 (56, 58) は外側(右)から色を引く。
        XCTAssertLessThan(field.dx[58 * side + 44], 0)
        XCTAssertGreaterThan(field.dx[58 * side + 56], 0)
        // 顔の他の部分(目・輪郭)は動かさない。
        XCTAssertEqual(field.dx[45 * side + 40], 0)
        XCTAssertEqual(field.dx[50 * side + 20], 0)
    }

    func testNegativeNoseSlimWidensTheNose() throws {
        let field = try XCTUnwrap(FaceReshape.field(face: TestFaces.full(), imageSize: imageSize, roiOrigin: .zero,
                                                    width: side, height: side, faceSlim: 0, eyeEnlarge: 0, chin: 0, noseSlim: -1))
        XCTAssertGreaterThan(field.dx[58 * side + 44], 0)
    }

    func testNoseSlimWithoutNoseLandmarksDoesNothing() {
        let field = FaceReshape.field(face: TestFaces.square(), imageSize: imageSize, roiOrigin: .zero,
                                      width: side, height: side, faceSlim: 0, eyeEnlarge: 0, chin: 0, noseSlim: 1)
        XCTAssertTrue(field?.dx.allSatisfy { $0 == 0 } ?? true)
    }
}

