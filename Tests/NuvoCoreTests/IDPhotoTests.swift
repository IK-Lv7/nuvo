import CoreGraphics
import XCTest
@testable import NuvoCore

final class IDPhotoTests: XCTestCase {
    private let imageSize = CGSize(width: 1000, height: 1000)

    /// 画像中央に小さめの顔。顎は y = 0.7。
    private func face() -> FaceLandmarks {
        FaceLandmarks(boundingBox: CGRect(x: 0.35, y: 0.3, width: 0.3, height: 0.4),
                      faceContour: [CGPoint(x: 0.35, y: 0.5), CGPoint(x: 0.5, y: 0.7), CGPoint(x: 0.65, y: 0.5)])
    }

    func testCropMatchesSpecAspectRatio() throws {
        let rect = try XCTUnwrap(IDPhotoLayout.cropRect(face: face(), crown: 0.25, imageSize: imageSize, spec: .passport))
        XCTAssertEqual(rect.width / rect.height, 35.0 / 45.0, accuracy: 0.01)
    }

    func testFaceOccupiesTheSpecifiedFractionOfTheFrame() throws {
        let rect = try XCTUnwrap(IDPhotoLayout.cropRect(face: face(), crown: 0.25, imageSize: imageSize, spec: .passport))
        let crownFraction = (0.25 * 1000 - rect.minY) / rect.height
        let chinFraction = (0.7 * 1000 - rect.minY) / rect.height
        // 頭頂の余白 4/45、顔の長さ 34/45(いずれも規格の範囲内: 2〜6mm と 32〜36mm)。
        XCTAssertEqual(crownFraction, 4.0 / 45.0, accuracy: 0.01)
        XCTAssertEqual(chinFraction - crownFraction, 34.0 / 45.0, accuracy: 0.01)
    }

    func testCropIsCenteredOnTheFaceAndInsideTheImage() throws {
        let rect = try XCTUnwrap(IDPhotoLayout.cropRect(face: face(), crown: 0.25, imageSize: imageSize, spec: .resume))
        XCTAssertEqual(rect.midX, 500, accuracy: 2)
        XCTAssertTrue(CGRect(origin: .zero, size: imageSize).contains(rect))
    }

    func testReturnsNilWhenThereIsNoRoomAboveTheHead() {
        // 頭頂が画像の上端に接していて、上余白が取れない。
        XCTAssertNil(IDPhotoLayout.cropRect(face: face(), crown: 0.0, imageSize: imageSize, spec: .passport))
    }

    func testReturnsNilWhenTheFaceIsTooLargeForTheImage() {
        let big = FaceLandmarks(boundingBox: CGRect(x: 0.1, y: 0.05, width: 0.8, height: 0.9),
                                faceContour: [CGPoint(x: 0.5, y: 0.95)])
        XCTAssertNil(IDPhotoLayout.cropRect(face: big, crown: 0.05, imageSize: imageSize, spec: .passport))
    }

    func testFallsBackToEstimatedCrownWithoutMask() {
        let rect = IDPhotoLayout.cropRect(face: face(), crown: nil, imageSize: imageSize, spec: .passport)
        XCTAssertNotNil(rect)
    }
}
