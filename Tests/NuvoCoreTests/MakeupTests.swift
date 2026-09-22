import CoreGraphics
import XCTest
@testable import NuvoCore

final class MakeupTests: XCTestCase {
    private let side = 100

    private func skinMask() -> [UInt8] { [UInt8](repeating: 255, count: side * side) }

    private func flat(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> [UInt8] {
        (0..<(side * side)).flatMap { _ in [r, g, b, 255] }
    }

    private func masks(pixels: [UInt8]? = nil) -> MakeupMasks {
        MakeupMasks.make(face: TestFaces.full(), skinMask: skinMask(), rgba: pixels ?? flat(224, 172, 150),
                         imageSize: CGSize(width: side, height: side), roiOrigin: .zero,
                         width: side, height: side)
    }

    func testLipMaskCoversLipsButNotOpenMouthInterior() {
        let m = masks()
        // 唇の縁 (50, 67) は塗り、口の内側 (50, 70) は塗らない。
        XCTAssertGreaterThan(m.lips[66 * side + 50], 200)
        XCTAssertLessThan(m.lips[70 * side + 50], 10)
        XCTAssertEqual(m.lips[10 * side + 10], 0)
    }

    func testBrowMaskCoversBothBrows() {
        let m = masks()
        XCTAssertGreaterThan(m.brows[38 * side + 40], 200)
        XCTAssertGreaterThan(m.brows[38 * side + 60], 200)
        XCTAssertEqual(m.brows[80 * side + 50], 0)
    }

    func testBlushPeaksOnCheeksAndFadesAway() {
        let centers = FaceGeometry.cheekCenters(TestFaces.full())
        XCTAssertEqual(centers.count, 2)
        let m = masks()
        for center in centers {
            let index = Int(center.y * CGFloat(side)) * side + Int(center.x * CGFloat(side))
            XCTAssertGreaterThan(m.blush[index], 200)
        }
        XCTAssertEqual(m.blush[2 * side + 2], 0)
    }

    func testBlushRespectsSkinMask() {
        let empty = [UInt8](repeating: 0, count: side * side)
        let m = MakeupMasks.make(face: TestFaces.full(), skinMask: empty, rgba: flat(224, 172, 150),
                                 imageSize: CGSize(width: side, height: side), roiOrigin: .zero,
                                 width: side, height: side)
        XCTAssertTrue(m.blush.allSatisfy { $0 == 0 })
    }

    func testCheeksAreOutsideTheEyesAndBelowThem() {
        let face = TestFaces.full()
        let centers = FaceGeometry.cheekCenters(face).sorted { $0.x < $1.x }
        XCTAssertLessThan(centers[0].x, 0.4)
        XCTAssertGreaterThan(centers[1].x, 0.6)
        XCTAssertGreaterThan(centers[0].y, 0.45)
    }

    // MARK: 合成

    private func layers(lips: UInt8 = 0, brows: UInt8 = 0, blush: UInt8 = 0) -> SkinRetouchLayers {
        let gray: [UInt8] = [128, 128, 128, 255]
        return SkinRetouchLayers(roi: CGRect(x: 0, y: 0, width: 1, height: 1), width: 1, height: 1,
                                 original: gray, smoothed: gray, mask: [0],
                                 makeupMasks: MakeupMasks(lips: [lips], brows: [brows], blush: [blush]))
    }

    func testZeroAmountLeavesPixelUntouched() {
        let result = layers(lips: 255).blended(smoothing: 0, brightness: 0, makeup: MakeupAmounts())
        XCTAssertEqual(Array(result.prefix(3)), [128, 128, 128])
    }

    func testLipstickShiftsTowardRed() {
        let result = layers(lips: 255).blended(smoothing: 0, brightness: 0, makeup: MakeupAmounts(lips: 1))
        XCTAssertGreaterThan(result[0], result[1])
        XCTAssertGreaterThan(result[0], 128)
    }

    func testLipstickKeepsTheOriginalLuminance() {
        // 色味だけを寄せ、明るさはほぼ保つ(質感を潰さない)。
        let result = layers(lips: 255).blended(smoothing: 0, brightness: 0, makeup: MakeupAmounts(lips: 1))
        let luma = 0.299 * Double(result[0]) + 0.587 * Double(result[1]) + 0.114 * Double(result[2])
        XCTAssertEqual(luma, 128, accuracy: 12)
    }

    func testLipstickColorChangesTheAppliedHue() {
        // 青いリップ色を選んだら、赤ではなく青のほうへ寄る。
        let blueLip = MakeupAmounts(lips: 1, lipColor: MakeupTint(r: 40, g: 60, b: 200))
        let result = layers(lips: 255).blended(smoothing: 0, brightness: 0, makeup: blueLip)
        XCTAssertGreaterThan(result[2], result[0])
    }

    func testDefaultLipstickColorMatchesThePreviousFixedColor() {
        // 色を指定しなければ、以前から固定だった色(現在の LipstickPreset.rose)と同じ結果になる。
        let withDefault = layers(lips: 255).blended(smoothing: 0, brightness: 0, makeup: MakeupAmounts(lips: 1))
        let withRose = layers(lips: 255).blended(smoothing: 0, brightness: 0,
                                                 makeup: MakeupAmounts(lips: 1, lipColor: LipstickPreset.rose.tint))
        XCTAssertEqual(withDefault, withRose)
    }

    func testEyebrowDarkens() {
        let result = layers(brows: 255).blended(smoothing: 0, brightness: 0, makeup: MakeupAmounts(brows: 1))
        XCTAssertLessThan(result[1], 128)
    }

    func testMaskZeroMeansNoMakeup() {
        let result = layers().blended(smoothing: 0, brightness: 0, makeup: MakeupAmounts(lips: 1, blush: 1, brows: 1))
        XCTAssertEqual(Array(result.prefix(3)), [128, 128, 128])
    }

    // MARK: 歯・くま

    func testTeethMaskCoversBrightNeutralPixelsInsideTheMouth() {
        // 口の内側 (50, 70) が黄ばんだ歯の色なら塗る。
        let m = masks(pixels: flat(230, 215, 170))
        XCTAssertGreaterThan(m.teeth[70 * side + 50], 100)
        XCTAssertEqual(m.teeth[10 * side + 10], 0)
    }

    func testTeethMaskSkipsLipColoredAndDarkPixels() {
        XCTAssertLessThan(masks(pixels: flat(190, 90, 100)).teeth[70 * side + 50], 60)
        XCTAssertEqual(masks(pixels: flat(30, 20, 20)).teeth[70 * side + 50], 0)
    }

    func testToothScoreOrdering() {
        XCTAssertGreaterThan(MakeupMasks.toothScore(r: 230, g: 215, b: 170),
                             MakeupMasks.toothScore(r: 190, g: 90, b: 100))
    }

    func testDarkCircleMaskSitsBelowTheEyes() {
        let m = masks()
        // 目 (40, 45) の直下 (40, 50) にあり、目の上や顔の外にはない。
        XCTAssertGreaterThan(m.darkCircles[50 * side + 40], 100)
        XCTAssertEqual(m.darkCircles[30 * side + 40], 0)
        XCTAssertEqual(m.darkCircles[5 * side + 5], 0)
    }

    func testWhiteningRemovesYellowTint() {
        let yellow: [UInt8] = [230, 215, 170, 255]
        let layer = SkinRetouchLayers(roi: CGRect(x: 0, y: 0, width: 1, height: 1), width: 1, height: 1,
                                      original: yellow, smoothed: yellow, mask: [0],
                                      makeupMasks: MakeupMasks(lips: [0], brows: [0], blush: [0],
                                                               teeth: [255], darkCircles: [0]))
        let result = layer.blended(smoothing: 0, brightness: 0, makeup: MakeupAmounts(teeth: 1))
        // 青が増え、赤との差(黄ばみ)が縮む。
        XCTAssertGreaterThan(result[2], 170)
        XCTAssertLessThan(Int(result[0]) - Int(result[2]), 230 - 170)
    }

    func testDarkCircleLiftBrightensTheArea() {
        let dark: [UInt8] = [100, 90, 90, 255]
        let layer = SkinRetouchLayers(roi: CGRect(x: 0, y: 0, width: 1, height: 1), width: 1, height: 1,
                                      original: dark, smoothed: dark, mask: [0],
                                      makeupMasks: MakeupMasks(lips: [0], brows: [0], blush: [0],
                                                               teeth: [0], darkCircles: [255]))
        let result = layer.blended(smoothing: 0, brightness: 0, makeup: MakeupAmounts(darkCircles: 1))
        XCTAssertGreaterThan(result[0], 100)
    }

    // MARK: 鼻筋

    func testNoseBridgeMaskFollowsTheCrestLine() {
        let m = masks()
        XCTAssertGreaterThan(m.noseBridge[50 * side + 50], 150)   // 鼻筋の線の上
        XCTAssertEqual(m.noseBridge[50 * side + 20], 0)           // 離れた場所
    }

    func testNoseBridgeIsAbsentWithoutLandmarks() {
        let m = MakeupMasks.make(face: TestFaces.square(), skinMask: skinMask(), rgba: flat(224, 172, 150),
                                 imageSize: CGSize(width: side, height: side), roiOrigin: .zero, width: side, height: side)
        XCTAssertTrue(m.noseBridge.allSatisfy { $0 == 0 })
    }

    func testNoseBridgeBrightensOnlyOnTheLine() {
        let gray: [UInt8] = [120, 110, 100, 255]
        let layer = SkinRetouchLayers(roi: CGRect(x: 0, y: 0, width: 1, height: 1), width: 1, height: 1,
                                      original: gray, smoothed: gray, mask: [0],
                                      makeupMasks: MakeupMasks(lips: [0], brows: [0], blush: [0], teeth: [0],
                                                               darkCircles: [0], noseBridge: [255]))
        XCTAssertGreaterThan(layer.blended(smoothing: 0, brightness: 0, makeup: MakeupAmounts(noseBridge: 1))[0], 120)
        XCTAssertEqual(layer.blended(smoothing: 0, brightness: 0, makeup: MakeupAmounts())[0], 120)
    }
}

