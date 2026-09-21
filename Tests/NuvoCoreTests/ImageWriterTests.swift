import CoreGraphics
import ImageIO
import XCTest
@testable import NuvoCore

final class ImageWriterTests: XCTestCase {
    private func metadata() -> [String: Any] {
        [
            kCGImagePropertyOrientation as String: 6,
            kCGImagePropertyGPSDictionary as String: [
                kCGImagePropertyGPSLatitude as String: 35.68,
                kCGImagePropertyGPSLongitude as String: 139.76,
            ],
            kCGImagePropertyTIFFDictionary as String: [
                kCGImagePropertyTIFFMake as String: "Apple",
                kCGImagePropertyTIFFOrientation as String: 6,
            ],
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifDateTimeOriginal as String: "2026:09:20 12:00:00",
            ],
        ]
    }

    private func image() throws -> CGImage {
        let pixels: [UInt8] = (0..<(8 * 8)).flatMap { _ in [200, 100, 50, 255] }
        return try XCTUnwrap(BitmapIO.cgImage(fromRGBA: pixels, width: 8, height: 8))
    }

    private func properties(of data: Data) throws -> [String: Any] {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
    }

    func testLocationIsRemovedWhenRequested() {
        let result = ImageWriter.sanitized(metadata(), stripLocation: true, width: 8, height: 8)
        XCTAssertNil(result[kCGImagePropertyGPSDictionary as String])
    }

    func testLocationIsKeptWhenAllowed() {
        let result = ImageWriter.sanitized(metadata(), stripLocation: false, width: 8, height: 8)
        XCTAssertNotNil(result[kCGImagePropertyGPSDictionary as String])
    }

    func testOrientationIsResetBecausePixelsAreAlreadyRotated() {
        let result = ImageWriter.sanitized(metadata(), stripLocation: true, width: 8, height: 8)
        XCTAssertEqual(result[kCGImagePropertyOrientation as String] as? Int, 1)
        let tiff = result[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        XCTAssertEqual(tiff?[kCGImagePropertyTIFFOrientation as String] as? Int, 1)
        XCTAssertEqual(tiff?[kCGImagePropertyTIFFMake as String] as? String, "Apple")  // 他の情報は残る
    }

    func testPixelSizeReflectsTheNewImage() {
        let result = ImageWriter.sanitized(metadata(), stripLocation: true, width: 30, height: 40)
        let exif = result[kCGImagePropertyExifDictionary as String] as? [String: Any]
        XCTAssertEqual(exif?[kCGImagePropertyExifPixelXDimension as String] as? Int, 30)
        XCTAssertEqual(exif?[kCGImagePropertyExifPixelYDimension as String] as? Int, 40)
    }

    func testWrittenFileHasNoLocationButKeepsCameraInfo() throws {
        let props = ImageWriter.sanitized(metadata(), stripLocation: true, width: 8, height: 8)
        let data = try XCTUnwrap(ImageWriter.data(from: try image(), properties: props, quality: 0.9))
        let read = try properties(of: data)
        XCTAssertNil(read[kCGImagePropertyGPSDictionary as String])
        let exif = read[kCGImagePropertyExifDictionary as String] as? [String: Any]
        XCTAssertEqual(exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String, "2026:09:20 12:00:00")
    }

    func testWrittenFileKeepsLocationWhenAllowed() throws {
        let props = ImageWriter.sanitized(metadata(), stripLocation: false, width: 8, height: 8)
        let data = try XCTUnwrap(ImageWriter.data(from: try image(), properties: props, quality: 0.9))
        XCTAssertNotNil(try properties(of: data)[kCGImagePropertyGPSDictionary as String])
    }

    func testRendererExportDropsLocationByDefault() throws {
        let renderer = ImageRenderer()
        let source = renderer.makeSource(image: CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
            .cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8)))
        let data = try XCTUnwrap(renderer.jpegData(source, parameters: AdjustmentParameters(), metadata: metadata()))
        XCTAssertNil(try properties(of: data)[kCGImagePropertyGPSDictionary as String])
    }

    func testReadMetadataOfGarbageIsEmpty() {
        XCTAssertTrue(ImageWriter.readMetadata(from: Data([1, 2, 3])).isEmpty)
    }

    // MARK: 形式

    func testPNGHasThePNGSignature() throws {
        let data = try XCTUnwrap(ImageWriter.data(from: try image(), properties: [:], quality: 0.9, format: .png))
        XCTAssertEqual(Array(data.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
    }

    func testJPEGHasTheJPEGSignature() throws {
        let data = try XCTUnwrap(ImageWriter.data(from: try image(), properties: [:], quality: 0.9, format: .jpeg))
        XCTAssertEqual(Array(data.prefix(2)), [0xFF, 0xD8])
    }

    func testHigherQualityMakesALargerJPEG() throws {
        // ノイズのある画像でないと、画質の差がファイルサイズに出ない。
        var seed: UInt32 = 12345
        let noisy: [UInt8] = (0..<(64 * 64 * 4)).map { i in
            seed = seed &* 1664525 &+ 1013904223
            return i % 4 == 3 ? 255 : UInt8(truncatingIfNeeded: seed >> 24)
        }
        let cgImage = try XCTUnwrap(BitmapIO.cgImage(fromRGBA: noisy, width: 64, height: 64))
        let low = try XCTUnwrap(ImageWriter.data(from: cgImage, properties: [:], quality: 0.3, format: .jpeg))
        let high = try XCTUnwrap(ImageWriter.data(from: cgImage, properties: [:], quality: 1.0, format: .jpeg))
        XCTAssertGreaterThan(high.count, low.count)
    }

    func testHEICIsWrittenWhenTheDeviceSupportsIt() throws {
        guard let data = ImageWriter.data(from: try image(), properties: [:], quality: 0.9, format: .heic) else {
            throw XCTSkip("この環境では HEIC を書き出せない")
        }
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(source) as String?, "public.heic")
    }

    func testRendererEncodesInTheRequestedFormat() throws {
        let renderer = ImageRenderer()
        let source = renderer.makeSource(image: CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
            .cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8)))
        let png = try XCTUnwrap(renderer.encodedData(source, parameters: AdjustmentParameters(), format: .png))
        XCTAssertEqual(png.format, .png)
        XCTAssertEqual(Array(png.data.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
    }

    func testFormatMetadata() {
        XCTAssertEqual(ExportFormat.jpeg.fileExtension, "jpg")
        XCTAssertTrue(ExportFormat.heic.isLossy)
        XCTAssertFalse(ExportFormat.png.isLossy)
    }
}

