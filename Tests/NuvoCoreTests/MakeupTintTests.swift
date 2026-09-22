import XCTest
@testable import NuvoCore

final class MakeupTintTests: XCTestCase {
    func testInitFrom255ScaleMatchesUnitScale() {
        XCTAssertEqual(MakeupTint(r: 255, g: 0, b: 0), MakeupTint(red: 1, green: 0, blue: 0))
    }

    func testValuesAreClampedToUnitRange() {
        let tint = MakeupTint(red: 1.5, green: -0.2, blue: 0.5)
        XCTAssertEqual(tint, MakeupTint(red: 1, green: 0, blue: 0.5))
    }

    func testRGB255RoundTrips() {
        let tint = MakeupTint(r: 200, g: 140, b: 125)
        let (r, g, b) = tint.rgb255
        XCTAssertEqual(r, 200, accuracy: 0.001)
        XCTAssertEqual(g, 140, accuracy: 0.001)
        XCTAssertEqual(b, 125, accuracy: 0.001)
    }

    func testEveryPresetIsWithinRange() {
        for preset in LipstickPreset.allCases {
            let tint = preset.tint
            XCTAssertTrue((0...1).contains(tint.red))
            XCTAssertTrue((0...1).contains(tint.green))
            XCTAssertTrue((0...1).contains(tint.blue))
        }
    }

    func testPresetsAreAllDistinctColors() {
        let tints = LipstickPreset.allCases.map(\.tint)
        XCTAssertEqual(Set(tints).count, tints.count)
    }
}
