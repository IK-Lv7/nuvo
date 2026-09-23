import CoreGraphics
import XCTest
@testable import NuvoCore

final class AdjustmentParametersTests: XCTestCase {
    func testDefaultIsIdentity() {
        XCTAssertTrue(AdjustmentParameters().isIdentity)
    }

    func testModifiedIsNotIdentity() {
        var p = AdjustmentParameters()
        p.skinSmoothing = 0.5
        XCTAssertFalse(p.isIdentity)
    }

    func testClampedLimitsToRange() {
        var p = AdjustmentParameters()
        p.brightness = 3
        p.contrast = -3
        let c = p.clamped()
        XCTAssertEqual(c.brightness, 1)
        XCTAssertEqual(c.contrast, -1)
    }
}

final class AdjustmentParametersExtendedTests: XCTestCase {
    func testFilterIntensityIsClampedToUnitRange() {
        var p = AdjustmentParameters()
        p.filterIntensity = 2
        XCTAssertEqual(p.clamped().filterIntensity, 1)
        p.filterIntensity = -1
        XCTAssertEqual(p.clamped().filterIntensity, 0)
    }

    func testAddingSpotBreaksIdentity() {
        var p = AdjustmentParameters()
        p.spots.append(HealSpot(center: CGPoint(x: 0.5, y: 0.5)))
        XCTAssertFalse(p.isIdentity)
    }

    func testSelectingFilterBreaksIdentity() {
        var p = AdjustmentParameters()
        p.filter = .warm
        XCTAssertFalse(p.isIdentity)
    }
}

final class AdjustmentParametersFaceTests: XCTestCase {
    func testMakeupIsClampedToUnitRange() {
        var p = AdjustmentParameters()
        p.lipstick = 3
        p.blush = -1
        XCTAssertEqual(p.clamped().lipstick, 1)
        XCTAssertEqual(p.clamped().blush, 0)
    }

    func testReshapeIsClampedToBidirectionalRange() {
        var p = AdjustmentParameters()
        p.faceSlim = 5
        p.chin = -5
        XCTAssertEqual(p.clamped().faceSlim, 1)
        XCTAssertEqual(p.clamped().chin, -1)
    }

    func testMakeupBreaksIdentity() {
        var p = AdjustmentParameters()
        p.eyebrow = 0.3
        XCTAssertFalse(p.isIdentity)
        XCTAssertTrue(p.hasSkinOrMakeup)
    }
}

final class AdjustmentParametersFinishTests: XCTestCase {
    func testFinishingValuesAreClamped() {
        var p = AdjustmentParameters()
        p.sharpness = 4
        p.warmth = -4
        p.backgroundBlur = 9
        let c = p.clamped()
        XCTAssertEqual(c.sharpness, 1)
        XCTAssertEqual(c.warmth, -1)
        XCTAssertEqual(c.backgroundBlur, 1)
    }

    func testBackgroundAndIDPhotoBreakIdentity() {
        var p = AdjustmentParameters()
        p.idPhoto = .passport
        XCTAssertFalse(p.isIdentity)
        p = AdjustmentParameters()
        p.autoEnhance = true
        XCTAssertFalse(p.isIdentity)
    }
}

final class LookTests: XCTestCase {
    private func customized() -> AdjustmentParameters {
        var p = AdjustmentParameters()
        p.skinSmoothing = 0.6
        p.filter = .film
        p.spots = [HealSpot(center: CGPoint(x: 0.2, y: 0.3))]
        p.texts = [TextOverlay(text: "hi")]
        p.rotationQuarterTurns = 1
        p.cropAspect = .square
        p.idPhoto = .passport
        return p
    }

    func testLookKeepsTheStyleButDropsPerPhotoContent() {
        let look = customized().lookOnly()
        XCTAssertEqual(look.skinSmoothing, 0.6)
        XCTAssertEqual(look.filter, .film)
        XCTAssertTrue(look.spots.isEmpty)
        XCTAssertTrue(look.texts.isEmpty)
        XCTAssertEqual(look.rotationQuarterTurns, 0)
        XCTAssertNil(look.cropAspect)
        XCTAssertNil(look.idPhoto)
    }

    func testApplyingALookKeepsThisPhotosOwnContent() {
        var current = AdjustmentParameters()
        current.spots = [HealSpot(center: CGPoint(x: 0.5, y: 0.5))]
        current.rotationQuarterTurns = 3
        current.texts = [TextOverlay(text: "mine")]
        let result = current.applyingLook(customized())
        XCTAssertEqual(result.skinSmoothing, 0.6)      // ルックから
        XCTAssertEqual(result.filter, .film)
        XCTAssertEqual(result.spots.count, 1)           // この写真から
        XCTAssertEqual(result.rotationQuarterTurns, 3)
        XCTAssertEqual(result.texts.first?.text, "mine")
        XCTAssertNil(result.cropAspect)
    }

    func testLipstickColorRoundTripsThroughJSON() throws {
        var p = AdjustmentParameters()
        p.lipstickColor = LipstickPreset.coral.tint
        let decoded = try JSONDecoder().decode(AdjustmentParameters.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded.lipstickColor, LipstickPreset.coral.tint)
    }

    func testSavedLooksWithoutALipstickColorStillDecode() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(AdjustmentParameters())) as? [String: Any])
        object.removeValue(forKey: "lipstickColor")
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertNoThrow(try JSONDecoder().decode(AdjustmentParameters.self, from: data))
    }

    func testChoosingALipstickColorBreaksIdentity() {
        var p = AdjustmentParameters()
        p.lipstickColor = LipstickPreset.berry.tint
        XCTAssertFalse(p.isIdentity)
    }

    func testLookKeepsTheChosenLipstickColor() {
        var p = AdjustmentParameters()
        p.lipstick = 0.5
        p.lipstickColor = LipstickPreset.plum.tint
        XCTAssertEqual(p.lookOnly().lipstickColor, LipstickPreset.plum.tint)
    }

    func testEyeMakeupIsClampedToUnitRange() {
        var p = AdjustmentParameters()
        p.eyeliner = 3
        p.eyelashes = -1
        p.eyeshadow = 2
        p.lens = -2
        p.tearBags = 5
        let clamped = p.clamped()
        XCTAssertEqual(clamped.eyeliner, 1)
        XCTAssertEqual(clamped.eyelashes, 0)
        XCTAssertEqual(clamped.eyeshadow, 1)
        XCTAssertEqual(clamped.lens, 0)
        XCTAssertEqual(clamped.tearBags, 1)
    }

    func testEyeMakeupCountsAsMakeup() {
        for keyPath: WritableKeyPath<AdjustmentParameters, Double> in
            [\.eyeliner, \.eyelashes, \.eyeshadow, \.lens, \.tearBags] {
            var p = AdjustmentParameters()
            p[keyPath: keyPath] = 0.5
            XCTAssertTrue(p.hasSkinOrMakeup)
            XCTAssertFalse(p.isIdentity)
        }
    }

    func testEyeMakeupRoundTripsThroughJSON() throws {
        var p = AdjustmentParameters()
        p.eyeliner = 0.4
        p.eyeshadow = 0.6
        p.eyeshadowColor = EyeshadowPreset.lavender.tint
        p.lens = 0.3
        p.lensColor = LensPreset.gray.tint
        p.tearBags = 0.2
        let decoded = try JSONDecoder().decode(AdjustmentParameters.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded, p)
    }

    // MARK: 以前のバージョンで保存した値の読み込み

    func testLenientDecodingFillsInValuesThatDidNotExistYet() throws {
        // 目もとの項目が無かった頃に保存された内容を模した JSON。
        let saved: [String: Any] = ["skinSmoothing": 0.5, "lipstick": 0.3]
        let decoded = try XCTUnwrap(AdjustmentParameters.lenientlyDecoded(from: saved))
        XCTAssertEqual(decoded.skinSmoothing, 0.5)
        XCTAssertEqual(decoded.lipstick, 0.3)
        // 増えた項目は既定値(0)で埋まる。
        XCTAssertEqual(decoded.eyeliner, 0)
        XCTAssertEqual(decoded.tearBags, 0)
        XCTAssertNil(decoded.eyeshadowColor)
    }

    func testLenientDecodingKeepsEverySavedValue() throws {
        var p = AdjustmentParameters()
        p.skinSmoothing = 0.7
        p.eyeshadow = 0.4
        p.eyeshadowColor = EyeshadowPreset.gold.tint
        p.texts = [TextOverlay(text: "A")]
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as? [String: Any])
        XCTAssertEqual(AdjustmentParameters.lenientlyDecoded(from: object), p)
    }

    func testLenientDecodingRejectsValuesOfTheWrongType() {
        XCTAssertNil(AdjustmentParameters.lenientlyDecoded(from: ["skinSmoothing": "とても強く"]))
    }

    func testBlushColorRoundTripsThroughJSON() throws {
        var p = AdjustmentParameters()
        p.blushColor = BlushPreset.coral.tint
        let decoded = try JSONDecoder().decode(AdjustmentParameters.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded.blushColor, BlushPreset.coral.tint)
    }

    func testSavedLooksWithoutABlushColorStillDecode() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(AdjustmentParameters())) as? [String: Any])
        object.removeValue(forKey: "blushColor")
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertNoThrow(try JSONDecoder().decode(AdjustmentParameters.self, from: data))
    }

    func testChoosingABlushColorBreaksIdentity() {
        var p = AdjustmentParameters()
        p.blushColor = BlushPreset.mauve.tint
        XCTAssertFalse(p.isIdentity)
    }

    func testLookKeepsTheChosenBlushColor() {
        var p = AdjustmentParameters()
        p.blush = 0.5
        p.blushColor = BlushPreset.apricot.tint
        XCTAssertEqual(p.lookOnly().blushColor, BlushPreset.apricot.tint)
    }

    func testMaskStrokesRoundTripThroughJSON() throws {
        var p = AdjustmentParameters()
        p.maskStrokes = [MaskStroke(points: [CGPoint(x: 0.3, y: 0.4)], radius: 0.05, mode: .erase)]
        let decoded = try JSONDecoder().decode(AdjustmentParameters.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded.maskStrokes, p.maskStrokes)
    }

    func testSavedLooksWithoutMaskStrokesStillDecode() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(AdjustmentParameters())) as? [String: Any])
        object.removeValue(forKey: "maskStrokes")
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertNoThrow(try JSONDecoder().decode(AdjustmentParameters.self, from: data))
    }

    func testAddingAMaskStrokeBreaksIdentity() {
        var p = AdjustmentParameters()
        p.maskStrokes = [MaskStroke(points: [CGPoint(x: 0.5, y: 0.5)], radius: 0.05, mode: .keep)]
        XCTAssertFalse(p.isIdentity)
    }

    func testLookDoesNotCarryMaskStrokesButApplyingItKeepsThisPhotosOwn() {
        var current = AdjustmentParameters()
        current.maskStrokes = [MaskStroke(points: [CGPoint(x: 0.5, y: 0.5)], radius: 0.05, mode: .keep)]
        XCTAssertNil(current.lookOnly().maskStrokes)

        var look = AdjustmentParameters()
        look.skinSmoothing = 0.5
        let applied = current.applyingLook(look)
        XCTAssertEqual(applied.maskStrokes, current.maskStrokes)
    }

    func testHighResolutionRoundTripsThroughJSON() throws {
        var p = AdjustmentParameters()
        p.highResolution = true
        let decoded = try JSONDecoder().decode(AdjustmentParameters.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded.highResolution, true)
    }

    func testSavedLooksWithoutHighResolutionStillDecode() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(AdjustmentParameters())) as? [String: Any])
        object.removeValue(forKey: "highResolution")
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertNoThrow(try JSONDecoder().decode(AdjustmentParameters.self, from: data))
    }

    func testEnablingHighResolutionBreaksIdentity() {
        var p = AdjustmentParameters()
        p.highResolution = true
        XCTAssertFalse(p.isIdentity)
    }

    func testStampsRoundTripThroughJSON() throws {
        var p = AdjustmentParameters()
        p.stamps = [StampOverlay(symbolName: "heart.fill", center: CGPoint(x: 0.3, y: 0.4), size: 0.2,
                                 color: TextColorPreset.pink.tint)]
        let decoded = try JSONDecoder().decode(AdjustmentParameters.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded.stamps, p.stamps)
    }

    func testSavedLooksWithoutStampsStillDecode() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(AdjustmentParameters())) as? [String: Any])
        object.removeValue(forKey: "stamps")
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertNoThrow(try JSONDecoder().decode(AdjustmentParameters.self, from: data))
    }

    func testAddingAStampBreaksIdentity() {
        var p = AdjustmentParameters()
        p.stamps = [StampOverlay(symbolName: "star.fill")]
        XCTAssertFalse(p.isIdentity)
    }

    func testLookDoesNotCarryStampsButApplyingItKeepsThisPhotosOwn() {
        var current = AdjustmentParameters()
        current.stamps = [StampOverlay(symbolName: "star.fill")]
        XCTAssertNil(current.lookOnly().stamps)

        var look = AdjustmentParameters()
        look.skinSmoothing = 0.5
        let applied = current.applyingLook(look)
        XCTAssertEqual(applied.stamps, current.stamps)
    }

    func testParametersRoundTripThroughJSON() throws {
        let original = customized()
        let decoded = try JSONDecoder().decode(AdjustmentParameters.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
    }

    func testCompositionValuesAreClamped() {
        var p = AdjustmentParameters()
        p.straighten = 4
        p.rotationQuarterTurns = -1
        let c = p.clamped()
        XCTAssertEqual(c.straighten, 1)
        XCTAssertEqual(c.rotationQuarterTurns, 3)
    }

    func testCompositionChangesBreakIdentity() {
        var p = AdjustmentParameters()
        p.flipHorizontal = true
        XCTAssertFalse(p.isIdentity)
    }
}

final class AdjustmentParametersExtraTests: XCTestCase {
    func testNewValuesAreClamped() {
        var p = AdjustmentParameters()
        p.skinFlush = 9
        p.noseSlim = -9
        p.noseBridge = 9
        p.filmGrain = -1
        p.lightLeak = 9
        let c = p.clamped()
        XCTAssertEqual(c.skinFlush, 1)
        XCTAssertEqual(c.noseSlim, -1)
        XCTAssertEqual(c.noseBridge, 1)
        XCTAssertEqual(c.filmGrain, 0)
        XCTAssertEqual(c.lightLeak, 1)
    }

    func testFlushAndNoseBridgeCountAsSkinOrMakeup() {
        var p = AdjustmentParameters()
        p.skinFlush = 0.3
        XCTAssertTrue(p.hasSkinOrMakeup)
        p = AdjustmentParameters()
        p.noseBridge = 0.3
        XCTAssertTrue(p.hasSkinOrMakeup)
    }

    func testLookKeepsTheNewStyleValues() {
        var p = AdjustmentParameters()
        p.skinFlush = 0.4
        p.filmGrain = 0.6
        let look = p.lookOnly()
        XCTAssertEqual(look.skinFlush, 0.4)
        XCTAssertEqual(look.filmGrain, 0.6)
    }
}

final class CropZoomParametersTests: XCTestCase {
    func testZoomIsClampedToItsRange() {
        var p = AdjustmentParameters()
        p.cropZoom = 9
        XCTAssertEqual(p.clamped().cropZoom, 4)
        p.cropZoom = 0.2
        XCTAssertEqual(p.clamped().cropZoom, 1)
    }

    func testCenterIsClampedToTheFrame() {
        var p = AdjustmentParameters()
        p.cropCenter = CGPoint(x: -3, y: 4)
        XCTAssertEqual(p.clamped().cropCenter, CGPoint(x: 0, y: 1))
    }

    func testZoomBelongsToThePhotoNotTheLook() {
        var p = AdjustmentParameters()
        p.cropZoom = 3
        p.cropCenter = CGPoint(x: 0.2, y: 0.8)
        p.skinSmoothing = 0.5
        XCTAssertEqual(p.lookOnly().cropZoom, 1)
        XCTAssertEqual(p.lookOnly().skinSmoothing, 0.5)

        var current = AdjustmentParameters()
        current.cropZoom = 2
        current.cropCenter = CGPoint(x: 0.3, y: 0.3)
        let applied = current.applyingLook(p)
        XCTAssertEqual(applied.cropZoom, 2)
        XCTAssertEqual(applied.cropCenter, CGPoint(x: 0.3, y: 0.3))
        XCTAssertEqual(applied.skinSmoothing, 0.5)
    }

    func testZoomBreaksIdentity() {
        var p = AdjustmentParameters()
        p.cropZoom = 1.5
        XCTAssertFalse(p.isIdentity)
    }
}

