import CoreGraphics
import XCTest
@testable import NuvoCore

final class TileLayoutTests: XCTestCase {
    // MARK: axis(1軸)

    /// `keep` を並べると、隙間も重なりもなく `[0, extent)` にちょうど一致する。
    private func assertKeepRangesTileExactly(_ segments: [TileLayout.Segment], extent: Int,
                                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(segments.first?.keep.lowerBound, 0, file: file, line: line)
        XCTAssertEqual(segments.last?.keep.upperBound, extent, file: file, line: line)
        for pair in zip(segments, segments.dropFirst()) {
            XCTAssertEqual(pair.0.keep.upperBound, pair.1.keep.lowerBound,
                           "隙間または重なりがある", file: file, line: line)
        }
    }

    /// すべての `source` は `tileSize` の幅で、`[0, extent)` に収まり、対応する `keep` を含む。
    private func assertSourcesAreValid(_ segments: [TileLayout.Segment], extent: Int, tileSize: Int,
                                       file: StaticString = #filePath, line: UInt = #line) {
        for segment in segments {
            XCTAssertEqual(segment.source.count, tileSize, file: file, line: line)
            XCTAssertGreaterThanOrEqual(segment.source.lowerBound, 0, file: file, line: line)
            XCTAssertLessThanOrEqual(segment.source.upperBound, extent, file: file, line: line)
            XCTAssertTrue(segment.source.contains(segment.keep.lowerBound)
                          || segment.keep.isEmpty, file: file, line: line)
            XCTAssertGreaterThanOrEqual(segment.keep.lowerBound, segment.source.lowerBound, file: file, line: line)
            XCTAssertLessThanOrEqual(segment.keep.upperBound, segment.source.upperBound, file: file, line: line)
        }
    }

    func testAxisExactMultipleOfStride() throws {
        // tileSize 128, overlap 16 → stride 96。extent をちょうど 3 枚ぶんにする。
        let segments = try XCTUnwrap(TileLayout.axis(extent: 96 * 3, tileSize: 128, overlap: 16))
        XCTAssertEqual(segments.count, 3)
        assertKeepRangesTileExactly(segments, extent: 96 * 3)
        assertSourcesAreValid(segments, extent: 96 * 3, tileSize: 128)
    }

    func testAxisNotAnExactMultiple() throws {
        // 端数が出るサイズ。最後のタイルの keep が縮む形になるはず。
        let segments = try XCTUnwrap(TileLayout.axis(extent: 250, tileSize: 128, overlap: 16))
        assertKeepRangesTileExactly(segments, extent: 250)
        assertSourcesAreValid(segments, extent: 250, tileSize: 128)
        let lastSegment = try XCTUnwrap(segments.last)
        XCTAssertLessThan(lastSegment.keep.count, 96, "最後のタイルは stride より短くなる")
    }

    func testAxisSmallerThanTileSizeReturnsNil() {
        XCTAssertNil(TileLayout.axis(extent: 100, tileSize: 128, overlap: 16))
    }

    func testAxisExactlyOneTileSize() throws {
        // 画像の一辺がちょうど tileSize と同じ場合、タイルは1枚だけ。
        let segments = try XCTUnwrap(TileLayout.axis(extent: 128, tileSize: 128, overlap: 16))
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].keep, 0..<128)
        XCTAssertEqual(segments[0].source, 0..<128)
    }

    func testAxisWithoutOverlap() throws {
        // overlap 0 なら keep と source は常に一致する。
        let segments = try XCTUnwrap(TileLayout.axis(extent: 300, tileSize: 100, overlap: 0))
        assertKeepRangesTileExactly(segments, extent: 300)
        for segment in segments {
            XCTAssertEqual(segment.keep, segment.source)
        }
    }

    func testAxisRejectsOverlapAtLeastHalfTileSize() {
        XCTAssertNil(TileLayout.axis(extent: 1000, tileSize: 128, overlap: 64))
    }

    /// 画像の大きさをいろいろ変えても、性質(隙間なし・重なりなし・source が keep を含む)が崩れないこと。
    func testAxisHoldsForManySizes() throws {
        for extent in stride(from: 128, through: 2000, by: 37) {
            let segments = try XCTUnwrap(TileLayout.axis(extent: extent, tileSize: 128, overlap: 16),
                                        "extent \(extent)")
            assertKeepRangesTileExactly(segments, extent: extent)
            assertSourcesAreValid(segments, extent: extent, tileSize: 128)
        }
    }

    // MARK: tiles(2軸)

    func testTilesCoverA2DGridWithoutGaps() throws {
        let size = CGSize(width: 300, height: 250)
        let tiles = TileLayout.tiles(for: size, tileSize: 128, overlap: 16)
        XCTAssertFalse(tiles.isEmpty)
        for tile in tiles {
            XCTAssertEqual(tile.sourceRect.width, 128)
            XCTAssertEqual(tile.sourceRect.height, 128)
            XCTAssertTrue(tile.sourceRect.contains(tile.keepRect) || tile.keepRect.isEmpty)
        }
        // すべての keepRect の面積の合計は、画像の面積にちょうど一致する(隙間も重なりもない)。
        let totalKeepArea = tiles.reduce(CGFloat(0)) { $0 + $1.keepRect.width * $1.keepRect.height }
        XCTAssertEqual(totalKeepArea, size.width * size.height, accuracy: 0.01)
    }

    func testTilesEmptyWhenImageSmallerThanTileSize() {
        XCTAssertTrue(TileLayout.tiles(for: CGSize(width: 64, height: 64), tileSize: 128, overlap: 16).isEmpty)
    }

    func testTilesSingleTileWhenImageMatchesTileSize() {
        let tiles = TileLayout.tiles(for: CGSize(width: 128, height: 128), tileSize: 128, overlap: 16)
        XCTAssertEqual(tiles, [TileLayout.Tile(sourceRect: CGRect(x: 0, y: 0, width: 128, height: 128),
                                               keepRect: CGRect(x: 0, y: 0, width: 128, height: 128))])
    }
}
