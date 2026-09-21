import XCTest
@testable import NuvoCore

final class LUTFilterTests: XCTestCase {
    private func floats(_ preset: FilterPreset) -> [Float] {
        LUTFilter.cubeData(for: preset).withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    func testCubeHasExpectedSize() {
        let n = LUTFilter.dimension
        for preset in FilterPreset.allCases {
            XCTAssertEqual(floats(preset).count, n * n * n * 4, "\(preset)")
        }
    }

    func testAllValuesAreInRangeWithOpaqueAlpha() {
        for preset in FilterPreset.allCases {
            let values = floats(preset)
            for i in stride(from: 0, to: values.count, by: 4) {
                XCTAssertTrue((0...1).contains(values[i]) && (0...1).contains(values[i + 1])
                              && (0...1).contains(values[i + 2]), "\(preset) \(i)")
                XCTAssertEqual(values[i + 3], 1)
            }
        }
    }

    func testMonoProducesGray() {
        let values = floats(.mono)
        for i in stride(from: 0, to: values.count, by: 4 * 997) {
            XCTAssertEqual(values[i], values[i + 1], accuracy: 1e-6)
            XCTAssertEqual(values[i + 1], values[i + 2], accuracy: 1e-6)
        }
    }

    func testWarmAddsRedComparedToBlue() {
        // 中間の灰色 (16, 16, 16) 番地。暖色は R が B より高くなる。
        let n = LUTFilter.dimension
        let index = ((16 * n + 16) * n + 16) * 4
        let values = floats(.warm)
        XCTAssertGreaterThan(values[index], values[index + 2])
    }

    func testThereAreEighteenFilters() {
        XCTAssertEqual(FilterPreset.allCases.count, 18)
    }

    func testEveryFilterChangesColorsAndKeepsThemInRange() {
        for preset in FilterPreset.allCases {
            var changed = false
            for (r, g, b) in [(0.6, 0.4, 0.3), (0.2, 0.5, 0.8), (0.9, 0.9, 0.5)] as [(Float, Float, Float)] {
                let out = LUTFilter.transform(preset, r: r, g: g, b: b)
                for value in [out.0, out.1, out.2] { XCTAssertTrue((0...1).contains(value), "\(preset)") }
                if abs(out.0 - r) + abs(out.1 - g) + abs(out.2 - b) > 0.02 { changed = true }
            }
            XCTAssertTrue(changed, "\(preset) は色を変えていない")
        }
    }

    func testFiltersAreDistinctFromEachOther() {
        let samples: [(Float, Float, Float)] = [(0.6, 0.4, 0.3), (0.2, 0.5, 0.8), (0.9, 0.9, 0.5)]
        let all = FilterPreset.allCases
        for i in all.indices {
            for j in all.indices where j > i {
                let apart = samples.contains { sample in
                    let a = LUTFilter.transform(all[i], r: sample.0, g: sample.1, b: sample.2)
                    let b = LUTFilter.transform(all[j], r: sample.0, g: sample.1, b: sample.2)
                    return abs(a.0 - b.0) + abs(a.1 - b.1) + abs(a.2 - b.2) > 0.01
                }
                XCTAssertTrue(apart, "\(all[i]) と \(all[j]) が区別できない")
            }
        }
    }

    func testNoirIsDarkerAndHarsherThanMono() {
        let mono = LUTFilter.transform(.mono, r: 0.5, g: 0.5, b: 0.5)
        let noir = LUTFilter.transform(.noir, r: 0.5, g: 0.5, b: 0.5)
        XCTAssertLessThan(noir.0, mono.0)
    }
}

